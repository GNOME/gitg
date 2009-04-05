/*
 * gitg-runner.c
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2009 - Jesse van den Kieboom
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, 
 * Boston, MA 02111-1307, USA.
 */

#include "gitg-runner.h"
#include "gitg-utils.h"
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include "gitg-debug.h"

#include <gio/gio.h>
#include <gio/gunixoutputstream.h>
#include <gio/gunixinputstream.h>

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
	GInputStream *input_stream;
	GOutputStream *output_stream;
	GCancellable *cancellable;
	gboolean synchronized;
	
	guint buffer_size;
	gchar *buffer;
	gchar *read_buffer;
	gchar **lines;
	
	gint exit_status;
};

G_DEFINE_TYPE(GitgRunner, gitg_runner, G_TYPE_OBJECT)

typedef struct
{
	GitgRunner *runner;
	GCancellable *cancellable;
} AsyncData;

AsyncData *
async_data_new(GitgRunner *runner, GCancellable *cancellable)
{
	AsyncData *data = g_slice_new(AsyncData);
	data->runner = runner;
	data->cancellable = g_object_ref(cancellable);
	
	return data;
}

void
async_data_free(AsyncData *data)
{
	g_object_unref(data->cancellable);
	g_slice_free(AsyncData, data);
}

GQuark
gitg_runner_error_quark()
{
	static GQuark quark = 0;

	if (G_UNLIKELY(quark == 0))
		quark = g_quark_from_string ("gitg_runner_error");

	return quark;
}

static void
runner_io_exit(GPid pid, gint status, GitgRunner *runner)
{
	g_spawn_close_pid(pid);	
	runner->priv->pid = 0;
	
	runner->priv->exit_status = status;
}

static void
free_lines(GitgRunner *runner)
{
	gint i = 0;

	while (runner->priv->lines[i])
		g_free(runner->priv->lines[i++]);
	
	runner->priv->lines[0] = NULL;
}

static void
gitg_runner_finalize(GObject *object)
{
	GitgRunner *runner = GITG_RUNNER(object);
	
	/* Cancel possible running */
	gitg_runner_cancel(runner);

	/* Free potential stored lines */
	free_lines(runner);
	
	/* Remove buffer slice */
	g_slice_free1(sizeof(gchar) * (runner->priv->buffer_size + 1), runner->priv->read_buffer);
	g_slice_free1(sizeof(gchar *) * (runner->priv->buffer_size + 1), runner->priv->lines);
	
	/* Remove line buffer */
	g_free(runner->priv->buffer);
	
	g_object_unref(runner->priv->cancellable);

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
	runner->priv->lines = g_slice_alloc(sizeof(gchar *) * (runner->priv->buffer_size + 1));
	runner->priv->lines[0] = NULL;
	
	runner->priv->read_buffer = g_slice_alloc(sizeof(gchar) * (runner->priv->buffer_size + 1));
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
			      g_cclosure_marshal_VOID__BOOLEAN,
			      G_TYPE_NONE,
			      1,
			      G_TYPE_BOOLEAN);

	g_type_class_add_private(object_class, sizeof(GitgRunnerPrivate));
}

static void
gitg_runner_init(GitgRunner *self)
{
	self->priv = GITG_RUNNER_GET_PRIVATE(self);
	
	self->priv->cancellable = g_cancellable_new();
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

static gchar *
gitg_strnchr(gchar *ptr, gssize size, gchar find)
{
	while (size-- > 0)
	{
		if (*ptr++ == find)
			return ptr - 1;
	}
	
	return NULL;
}

static void
parse_lines(GitgRunner *runner, gchar *buffer, gssize size)
{
	gchar *ptr = buffer;
	gchar *newline;
	gint i = 0;

	free_lines(runner);
	
	while ((newline = gitg_strnchr(ptr, size, '\n')))
	{
		gssize linesize = newline - ptr;
		size -= linesize + 1;
		*newline = '\0';
		
		if (runner->priv->buffer)
		{
			gchar *buffered = g_strconcat(runner->priv->buffer, ptr, NULL);
			g_free(runner->priv->buffer);
			runner->priv->buffer = NULL;

			runner->priv->lines[i++] = gitg_utils_convert_utf8(buffered, -1);
			g_free(buffered);
		}
		else
		{
			runner->priv->lines[i++] = gitg_utils_convert_utf8(ptr, linesize);
		}
		
		ptr += linesize + 1;
	}
	
	runner->priv->lines[i] = NULL;

	if (size)
	{
		gchar *tmp;

		if (runner->priv->buffer != NULL)
			tmp = g_strconcat(runner->priv->buffer, ptr, NULL);
		else
			tmp = g_strndup(ptr, size);

		g_free(runner->priv->buffer);
		runner->priv->buffer = tmp;
	}

	g_signal_emit(runner, runner_signals[UPDATE], 0, runner->priv->lines);
}

static void
close_streams(GitgRunner *runner)
{
	if (runner->priv->output_stream)
	{
		g_output_stream_close (runner->priv->output_stream, NULL, NULL);
		g_object_unref(runner->priv->output_stream);
		runner->priv->output_stream = NULL;
	}
	
	if (runner->priv->input_stream)
	{
		g_input_stream_close (runner->priv->input_stream, NULL, NULL);
		g_object_unref(runner->priv->input_stream);
		runner->priv->input_stream = NULL;
	}
	
	g_free(runner->priv->buffer);
	runner->priv->buffer = NULL;
}

static gboolean
run_sync(GitgRunner *runner, gchar const *input, GError **error)
{
	if (input)
	{
		if (!g_output_stream_write_all(runner->priv->output_stream, input, strlen(input), NULL, NULL, error))
		{
			runner_io_exit(runner->priv->pid, 1, runner);
			close_streams(runner);

			g_signal_emit(runner, runner_signals[END_LOADING], 0, FALSE);
			return FALSE;
		}
		
		g_output_stream_close(runner->priv->output_stream, NULL, NULL);
	}
	
	gsize read = runner->priv->buffer_size;

	while (read == runner->priv->buffer_size)
	{
		if (!g_input_stream_read_all(runner->priv->input_stream, runner->priv->read_buffer, runner->priv->buffer_size, &read, NULL, error))
		{
			runner_io_exit(runner->priv->pid, 1, runner);
			close_streams(runner);

			g_signal_emit(runner, runner_signals[END_LOADING], 0, TRUE);
			return FALSE;
		}
		
		runner->priv->read_buffer[read] = '\0';
		parse_lines(runner, runner->priv->read_buffer, read);
	}

	gint status;
	waitpid(runner->priv->pid, &status, 0);

	runner_io_exit(runner->priv->pid, status, runner);
	close_streams(runner);
	
	g_signal_emit(runner, runner_signals[END_LOADING], 0, FALSE);
	
	if (status != 0 && error)
		g_set_error(error, GITG_RUNNER_ERROR, GITG_RUNNER_ERROR_EXIT, "Did not exit without error code");
	
	return status == 0;
}

static void
async_failed(AsyncData *data)
{
	runner_io_exit(data->runner->priv->pid, 1, data->runner);
	close_streams(data->runner);

	g_signal_emit(data->runner, runner_signals[END_LOADING], 0, TRUE);

	async_data_free(data);
}

static void start_reading(GitgRunner *runner, AsyncData *data);

static void
read_output_ready(GInputStream *stream, GAsyncResult *result, AsyncData *data)
{
	GError *error = NULL;
	
	gssize read = g_input_stream_read_finish(stream, result, &error);

	if (g_cancellable_is_cancelled(data->cancellable))
	{
		g_input_stream_close (stream, NULL, NULL);
		async_data_free(data);
		
		if (error)
			g_error_free(error);
		return;
	}

	if (read == -1)
	{
		g_input_stream_close (stream, NULL, NULL);
		async_failed(data);
		
		if (error)
			g_error_free(error);
		return;
	}
	
	if (read == 0)
	{
		/* End */
		gchar *b[] = {data->runner->priv->buffer, NULL};
		g_signal_emit(data->runner, runner_signals[UPDATE], 0, b);		

		gint status;
		waitpid(data->runner->priv->pid, &status, 0);
		runner_io_exit(data->runner->priv->pid, status, data->runner);
		close_streams(data->runner);

		g_signal_emit(data->runner, runner_signals[END_LOADING], 0, FALSE);
		
		async_data_free(data);
	}
	else
	{
		data->runner->priv->read_buffer[read] = '\0';
		parse_lines(data->runner, data->runner->priv->read_buffer, read);
		
		if (g_cancellable_is_cancelled(data->cancellable))
		{
			g_input_stream_close (stream, NULL, NULL);
			async_data_free(data);
			return;
		}

		start_reading(data->runner, data);
	}
}

static void
start_reading(GitgRunner *runner, AsyncData *data)
{
	g_input_stream_read_async(runner->priv->input_stream, runner->priv->read_buffer, runner->priv->buffer_size, G_PRIORITY_DEFAULT, runner->priv->cancellable, (GAsyncReadyCallback)read_output_ready, data);
}

static void
write_input_ready(GOutputStream *stream, GAsyncResult *result, AsyncData *data)
{
	GError *error = NULL;
	g_output_stream_write_finish(stream, result, &error);
	
	if (g_cancellable_is_cancelled(data->cancellable))
	{
		if (error)
			g_error_free(error);
		
		async_data_free(data);
	}
	
	if (error)
	{
		async_failed(data);
		g_error_free(error);
	}
	else
	{
		start_reading(data->runner, data);
	}
}

gboolean
gitg_runner_run_streams(GitgRunner *runner, GInputStream *input_stream, GOutputStream *output_stream, gchar const *input, GError **error)
{
	gitg_runner_cancel(runner);
	
	if (output_stream)
		runner->priv->output_stream = g_object_ref(output_stream);
	
	if (input_stream)
		runner->priv->input_stream = g_object_ref(input_stream);
	
	/* Emit begin-loading signal */
	g_signal_emit(runner, runner_signals[BEGIN_LOADING], 0);
	
	if (runner->priv->synchronized)
	{
		return run_sync(runner, input, error);
	}
	else
	{
		AsyncData *data = async_data_new(runner, runner->priv->cancellable);
		
		if (input)
		{
			g_output_stream_write_async(runner->priv->output_stream, input, -1, G_PRIORITY_DEFAULT, runner->priv->cancellable, (GAsyncReadyCallback)write_input_ready, data);
		}
		else
		{
			start_reading(runner, data);
		}
	}
	return TRUE;
}

gboolean
gitg_runner_run_with_arguments(GitgRunner *runner, gchar const **argv, gchar const *wd, gchar const *input, GError **error)
{
	g_return_val_if_fail(GITG_IS_RUNNER(runner), FALSE);

	gint stdout;
	gint stdin;

	gitg_runner_cancel(runner);

	gboolean ret = g_spawn_async_with_pipes(wd, (gchar **)argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD | (gitg_debug_enabled(GITG_DEBUG_RUNNER) ? 0 : G_SPAWN_STDERR_TO_DEV_NULL), NULL, NULL, &(runner->priv->pid), input ? &stdin : NULL, &stdout, NULL, error);

	if (!ret)
	{
		runner->priv->pid = 0;
		return FALSE;
	}
	
	GInputStream *input_stream = NULL;
	GOutputStream *output_stream = NULL;

	if (input)
		output_stream = G_OUTPUT_STREAM(g_unix_output_stream_new(stdin, TRUE));
		
	input_stream = G_INPUT_STREAM(g_unix_input_stream_new(stdout, TRUE));	
	ret = gitg_runner_run_streams(runner, input_stream, output_stream, input, error);
	
	if (output_stream)
		g_object_unref(output_stream);
	
	if (input_stream)
		g_object_unref(input_stream);
	
	return ret;
}

gboolean
gitg_runner_run_working_directory(GitgRunner *runner, gchar const **argv, gchar const *wd, GError **error)
{
	return gitg_runner_run_with_arguments(runner, argv, wd, NULL, error);
}

gboolean
gitg_runner_run(GitgRunner *runner, gchar const **argv, GError **error)
{
	return gitg_runner_run_working_directory(runner, argv, NULL, error);
}

gboolean
gitg_runner_run_stream(GitgRunner *runner, GInputStream *stream, GError **error)
{
	return gitg_runner_run_streams(runner, stream, NULL, NULL, error);
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

	if (runner->priv->input_stream)
	{
		g_cancellable_cancel(runner->priv->cancellable);
		g_object_unref(runner->priv->cancellable);
		
		runner->priv->cancellable = g_cancellable_new();
		runner_io_exit(runner->priv->pid, 1, runner);
		close_streams(runner);

		g_signal_emit(runner, runner_signals[END_LOADING], 0, TRUE);
	}
}

gboolean
gitg_runner_running(GitgRunner *runner)
{
	g_return_val_if_fail(GITG_IS_RUNNER(runner), FALSE);	
	return runner->priv->input_stream != NULL;
}

gint
gitg_runner_get_exit_status(GitgRunner *runner)
{
	g_return_val_if_fail(GITG_IS_RUNNER(runner), 1);
	
	return runner->priv->exit_status;
}
