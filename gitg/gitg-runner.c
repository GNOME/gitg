#include "gitg-runner.h"
#include "gitg-utils.h"

#define GITG_RUNNER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_RUNNER, GitgRunnerPrivate))

/* Signals */
enum
{
	BEGIN_LOADING,
	UPDATE,
	END_LOADING,
	LAST_SIGNAL
};

static guint runner_signals[LAST_SIGNAL] = { 0 };

/* Properties */
enum {
	PROP_0,

	PROP_BUFFER_SIZE
};

struct _GitgRunnerPrivate
{
	GPid pid;
	GThread *thread;
	GCond *cond;
	GMutex *cond_mutex;
	GMutex *mutex;
	guint syncid;
	gint output_fd;
	
	guint buffer_size;
	gchar **buffer;
	gboolean done;
};

G_DEFINE_TYPE(GitgRunner, gitg_runner, G_TYPE_OBJECT)

static void
runner_io_exit(GPid pid, int status, gpointer userdata)
{
	g_spawn_close_pid(pid);
}

static void
gitg_runner_finalize(GObject *object)
{
	GitgRunner *runner = GITG_RUNNER(object);
	
	if (runner->priv->pid)
		runner_io_exit(runner->priv->pid, 0, runner);

	// Cancel possible running thread
	gitg_runner_cancel(runner);
	
	// Free mutex and condition
	g_mutex_free(runner->priv->mutex);
	g_cond_free(runner->priv->cond);
	g_mutex_free(runner->priv->cond_mutex);

	// Remove buffer slice
	g_slice_free1(sizeof(gchar *) * (runner->priv->buffer_size + 1), runner->priv->buffer);

	G_OBJECT_CLASS(gitg_runner_parent_class)->finalize(object);
}

static void
gitg_runner_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgRunner *runner = GITG_RUNNER(object);

	switch (prop_id)
	{
		case PROP_BUFFER_SIZE:
			g_value_set_uint (value, runner->priv->buffer_size);
			break;

		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
			break;
	}
}

static void
set_buffer_size(GitgRunner *runner, guint buffer_size)
{
	runner->priv->buffer_size = buffer_size;	
	runner->priv->buffer = g_slice_alloc(sizeof(gchar *) * (runner->priv->buffer_size + 1));
	runner->priv->buffer[0] = NULL;
}

static void
gitg_runner_set_property (GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgRunner *runner = GITG_RUNNER(object);
	
	switch (prop_id)
	{
		case PROP_BUFFER_SIZE:
			set_buffer_size(runner, g_value_get_uint(value));
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
			break;
	}
}

static void
gitg_runner_class_init(GitgRunnerClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_runner_finalize;

	object_class->get_property = gitg_runner_get_property;
	object_class->set_property = gitg_runner_set_property;

	g_object_class_install_property (object_class, PROP_BUFFER_SIZE,
					 g_param_spec_uint ("buffer_size",
							      "BUFFER SIZE",
							      "The runners buffer size",
							      1,
							      G_MAXUINT,
							      1,
							      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));
							      
	runner_signals[BEGIN_LOADING] =
   		g_signal_new ("begin-loading",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgRunnerClass, begin_loading),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__VOID,
			      G_TYPE_NONE,
			      0);
	
	runner_signals[UPDATE] =
   		g_signal_new ("update",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgRunnerClass, update),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__POINTER,
			      G_TYPE_NONE,
			      1,
			      G_TYPE_POINTER);
			      
	runner_signals[END_LOADING] =
   		g_signal_new ("end-loading",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgRunnerClass, end_loading),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__VOID,
			      G_TYPE_NONE,
			      0);

	g_type_class_add_private(object_class, sizeof(GitgRunnerPrivate));
}

static void
gitg_runner_init(GitgRunner *self)
{
	self->priv = GITG_RUNNER_GET_PRIVATE(self);
	
	self->priv->cond = g_cond_new();
	self->priv->mutex = g_mutex_new();
	self->priv->cond_mutex = g_mutex_new();

	self->priv->done = TRUE;
}

static gboolean
emit_update_sync(GitgRunner *runner)
{
	// Emit signal
	g_signal_emit(runner, runner_signals[UPDATE], 0, runner->priv->buffer);

	if (runner->priv->done)
		g_signal_emit(runner, runner_signals[END_LOADING], 0);

	runner->priv->syncid = 0;
	g_cond_signal(runner->priv->cond);
	return FALSE;
}

static void
sync_buffer(GitgRunner *runner, guint num)
{
	// NULL terminate the buffer and add idle callback
	runner->priv->buffer[num] = NULL;

	runner->priv->syncid = g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, (GSourceFunc)emit_update_sync, runner, NULL);
	g_cond_wait(runner->priv->cond, runner->priv->cond_mutex);
}

static gpointer
output_reader_thread(gpointer userdata)
{
	GitgRunner *runner = GITG_RUNNER(userdata);
	GIOChannel *channel = g_io_channel_unix_new(runner->priv->output_fd);
	g_io_channel_set_encoding(channel, NULL, NULL);
	
	guint num = 0;
	gchar *line;
	gsize len;
	GError *error = NULL;
	gboolean cancel = FALSE;
	gsize term;

	while (g_io_channel_read_line(channel, &line, &len, &term, &error) == G_IO_STATUS_NORMAL)
	{
		// Do not include the newline
		line[term] = '\0';
		
		gchar *utf8 = gitg_utils_convert_utf8(line);
		runner->priv->buffer[num++] = utf8;
		g_free(line);
		
		g_mutex_lock(runner->priv->mutex);
		gboolean cancel = runner->priv->done;
		g_mutex_unlock(runner->priv->mutex);
		
		if (cancel)
			break;

		if (num == runner->priv->buffer_size)
		{
			sync_buffer(runner, num);
			
			num = 0;
		}
	}

	g_mutex_lock(runner->priv->mutex);
	cancel = runner->priv->done;
	runner->priv->done = TRUE;
	g_mutex_unlock(runner->priv->mutex);
	
	if (!cancel)
		sync_buffer(runner, num);
	
	g_io_channel_shutdown(channel, TRUE, NULL);
	g_io_channel_unref(channel);

	return NULL;
}


GitgRunner*
gitg_runner_new(guint buffer_size)
{
	g_assert(buffer_size > 0);

	return GITG_RUNNER(g_object_new(GITG_TYPE_RUNNER, "buffer_size", buffer_size, NULL));
}

gboolean
gitg_runner_run(GitgRunner *runner, gchar const **argv, GError **error)
{
	g_return_if_fail(GITG_IS_RUNNER(runner));

	gint stdout;
	gboolean ret = g_spawn_async_with_pipes(NULL, argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD, NULL, NULL, &(runner->priv->pid), NULL, &stdout, NULL, error);

	if (!ret)
	{
		runner->priv->pid = 0;
		return FALSE;
	}

	runner->priv->done = FALSE;
	runner->priv->output_fd = stdout;

	runner->priv->thread = g_thread_create(output_reader_thread, runner, TRUE, NULL);
	g_child_watch_add(runner->priv->pid, runner_io_exit, runner);

	// Emit begin-loading signal
	g_signal_emit(runner, runner_signals[BEGIN_LOADING], 0);	
}

guint
gitg_runner_get_buffer_size(GitgRunner *runner)
{
	g_return_if_fail(GITG_IS_RUNNER(runner));
	return runner->priv->buffer_size;
}

void
gitg_runner_cancel(GitgRunner *runner)
{
	g_return_if_fail(GITG_IS_RUNNER(runner));

	g_mutex_lock(runner->priv->mutex);
	gboolean done = runner->priv->done;
	runner->priv->done = TRUE;
	g_mutex_unlock(runner->priv->mutex);
	
	if (runner->priv->thread)
	{
		g_cond_signal(runner->priv->cond);
		g_thread_join(runner->priv->thread);
		
		if (runner->priv->syncid)
		{
			g_source_remove(runner->priv->syncid);
			runner->priv->syncid = 0;
		}
	}
	
	runner->priv->thread = NULL;
	runner->priv->pid = 0;
}

gboolean
gitg_runner_running(GitgRunner *runner)
{
	g_return_val_if_fail(GITG_IS_RUNNER(runner), FALSE);
	gboolean running;
	
	g_mutex_lock(runner->priv->mutex);
	running = !runner->priv->done;
	g_mutex_unlock(runner->priv->mutex);
	
	return running;
}
