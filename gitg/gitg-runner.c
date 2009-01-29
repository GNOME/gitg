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

	PROP_BUFFER_SIZE,
	PROP_SYNCHRONIZED
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
	gboolean synchronized;
	gchar **buffer;
	gboolean done;
	
	gint input_fd;
	gchar *input;
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
			g_value_set_uint(value, runner->priv->buffer_size);
			break;
		case PROP_SYNCHRONIZED:
			g_value_set_boolean(value, runner->priv->synchronized);
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
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
		case PROP_SYNCHRONIZED:
			runner->priv->synchronized = g_value_get_boolean(value);
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
	
	g_object_class_install_property (object_class, PROP_SYNCHRONIZED,
					 g_param_spec_boolean ("synchronized",
							      "SYNCHRONIZED",
							      "Whether the command is ran synchronized",
							      FALSE,
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
	runner->priv->syncid = 0;
	g_signal_emit(runner, runner_signals[UPDATE], 0, runner->priv->buffer);

	if (!runner->priv->synchronized)
	{
		if (runner->priv->done)
			g_signal_emit(runner, runner_signals[END_LOADING], 0);

		g_cond_signal(runner->priv->cond);
	}

	return FALSE;
}

static void
sync_buffer(GitgRunner *runner, guint num)
{
	// NULL terminate the buffer and add idle callback
	runner->priv->buffer[num] = NULL;

	if (runner->priv->synchronized)
	{
		emit_update_sync(runner);
	}
	else
	{
		runner->priv->syncid = g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, 
											   (GSourceFunc)emit_update_sync, 
											   runner, 
											   NULL);

		g_cond_wait(runner->priv->cond, runner->priv->cond_mutex);
	}
}

gboolean
write_input(GitgRunner *runner)
{
	GIOChannel *channel = g_io_channel_unix_new(runner->priv->input_fd);
	g_io_channel_set_encoding(channel, NULL, NULL);

	gchar const *buffer = runner->priv->input;
	gboolean ret = TRUE;
	gsize written;

	while (buffer && *buffer)
	{
		if (g_io_channel_write_chars(channel, runner->priv->input, -1, &written, NULL) != G_IO_STATUS_NORMAL)
		{
			ret = FALSE;
			break;
		}
		
		buffer += written;
		
		if (runner->priv->done)
		{
			ret = FALSE;
			break;
		}
	}

	g_io_channel_shutdown(channel, TRUE, NULL);
	g_io_channel_unref(channel);

	return ret;
}

static gpointer
output_reader_thread(gpointer userdata)
{
	GitgRunner *runner = GITG_RUNNER(userdata);
	
	guint num = 0;
	gchar *line;
	gsize len;
	GError *error = NULL;
	gsize term;
	
	if (runner->priv->input)
	{
		if (!write_input(runner))
			return NULL;
	}

	GIOChannel *channel = g_io_channel_unix_new(runner->priv->output_fd);
	g_io_channel_set_encoding(channel, NULL, NULL);
	
	while (g_io_channel_read_line(channel, &line, &len, &term, &error) == G_IO_STATUS_NORMAL)
	{
		gboolean cancel;

		// Do not include the newline
		line[term] = '\0';
		
		gchar *utf8 = gitg_utils_convert_utf8(line);
		runner->priv->buffer[num++] = utf8;
		g_free(line);
		
		g_mutex_lock (runner->priv->cond_mutex);
		
		if (!runner->priv->done && num == runner->priv->buffer_size)
		{
			sync_buffer(runner, num);
			num = 0;
		}
		
		cancel = runner->priv->done;
		g_mutex_unlock(runner->priv->cond_mutex);
		
		if (cancel)
			break;
	}

	g_mutex_lock (runner->priv->cond_mutex);	

	if (!runner->priv->done)
	{
		runner->priv->done = TRUE;
		sync_buffer(runner, num);
	}

	g_mutex_unlock (runner->priv->cond_mutex);
	
	g_io_channel_shutdown(channel, TRUE, NULL);
	g_io_channel_unref(channel);

	return NULL;
}

GitgRunner *
gitg_runner_new(guint buffer_size)
{
	g_assert(buffer_size > 0);

	return GITG_RUNNER(g_object_new(GITG_TYPE_RUNNER, 
									"buffer_size", buffer_size, 
									"synchronized", FALSE,
									NULL));
}

GitgRunner *
gitg_runner_new_synchronized(guint buffer_size)
{
	g_assert(buffer_size > 0);

	return GITG_RUNNER(g_object_new(GITG_TYPE_RUNNER, 
									"buffer_size", buffer_size, 
									"synchronized", TRUE,
									NULL));
}

gboolean
gitg_runner_run_with_arguments(GitgRunner *runner, gchar const **argv, gchar const *wd, gchar const *input, GError **error)
{
	g_return_val_if_fail(GITG_IS_RUNNER(runner), FALSE);

	gint stdout;
	gint stdin;

	gboolean ret = g_spawn_async_with_pipes(wd, (gchar **)argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD, NULL, NULL, &(runner->priv->pid), input ? &stdin : NULL, &stdout, NULL, error);

	if (!ret)
	{
		runner->priv->pid = 0;
		return FALSE;
	}
	
	runner->priv->done = FALSE;
	runner->priv->output_fd = stdout;
	runner->priv->input_fd = stdin;
	runner->priv->input = g_strdup(input);

	// Emit begin-loading signal
	g_signal_emit(runner, runner_signals[BEGIN_LOADING], 0);
	
	if (runner->priv->synchronized)
	{
		output_reader_thread(runner);
		runner_io_exit(runner->priv->pid, 0, NULL);
	}
	else
	{
		runner->priv->thread = g_thread_create(output_reader_thread, runner, TRUE, NULL);		
		g_child_watch_add(runner->priv->pid, runner_io_exit, runner);
	}
	
	return TRUE;

}

gboolean
gitg_runner_run_working_directory(GitgRunner *runner, gchar const **argv, gchar const *wd, GError **error)
{
	return gitg_runner_run_with_arguments(runner, argv, wd, NULL, error);
}

gboolean
gitg_runner_run(GitgRunner *runner, gchar const **argv, GError **error)
{
	gitg_runner_run_working_directory(runner, argv, NULL, error);
}

gboolean
gitg_runner_run_with_input(GitgRunner *runner, gchar const **argv, gchar const *input, GError **error)
{
	
}

guint
gitg_runner_get_buffer_size(GitgRunner *runner)
{
	g_return_val_if_fail(GITG_IS_RUNNER(runner), 0);
	return runner->priv->buffer_size;
}

void
gitg_runner_cancel(GitgRunner *runner)
{
	g_return_if_fail(GITG_IS_RUNNER(runner));

	if (!runner->priv->thread)
	{
		runner->priv->done = TRUE;
		
		if (runner->priv->input)
		{
			g_free(runner->priv->input);
			runner->priv->input = NULL;
		}
		return;
	}

	g_mutex_lock(runner->priv->cond_mutex);
	runner->priv->done = TRUE;
	
	if (runner->priv->syncid)
	{
		g_source_remove(runner->priv->syncid);
		runner->priv->syncid = 0;

		g_signal_emit(runner, runner_signals[END_LOADING], 0);
	}

	g_cond_signal(runner->priv->cond);
	g_mutex_unlock(runner->priv->cond_mutex);
	g_thread_join(runner->priv->thread);

	runner->priv->thread = NULL;
	runner->priv->pid = 0;
	
	g_free(runner->priv->input);
	runner->priv->input = NULL;
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
