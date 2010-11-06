/*
 * gitg-runner.c
 * This file is part of gitg
 *
 * Copyright (C) 2010 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA  02110-1301  USA
 */

#include "gitg-runner.h"
#include "gitg-debug.h"

#include "gitg-smart-charset-converter.h"

#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include <stdlib.h>

#include <gio/gunixoutputstream.h>
#include <gio/gunixinputstream.h>

#define GITG_RUNNER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_RUNNER, GitgRunnerPrivate))

struct _GitgRunnerPrivate
{
	GitgCommand *command;

	GInputStream *stdout;
	GOutputStream *stdin;

	GCancellable *cancellable;
	gboolean cancelled;

	GPid pid;
	guint watch_id;
};

G_DEFINE_TYPE (GitgRunner, gitg_runner, GITG_TYPE_IO)

enum
{
	PROP_0,
	PROP_COMMAND
};

typedef struct
{
	GitgRunner *runner;
	GCancellable *cancellable;
} AsyncData;

static AsyncData *
async_data_new (GitgRunner *runner)
{
	AsyncData *data;

	data = g_slice_new (AsyncData);

	data->runner = runner;
	data->cancellable = g_object_ref (runner->priv->cancellable);

	return data;
}

static void
async_data_free (AsyncData *data)
{
	g_object_unref (data->cancellable);
	g_slice_free (AsyncData, data);
}

static void
gitg_runner_finalize (GObject *object)
{
	G_OBJECT_CLASS (gitg_runner_parent_class)->finalize (object);
}

static void
close_streams (GitgRunner *runner)
{
	if (runner->priv->cancellable)
	{
		g_cancellable_cancel (runner->priv->cancellable);
	}

	if (runner->priv->stdin != NULL)
	{
		g_output_stream_close (runner->priv->stdin, NULL, NULL);
		g_object_unref (runner->priv->stdin);

		runner->priv->stdin = NULL;
	}

	if (runner->priv->stdout != NULL)
	{
		g_input_stream_close (runner->priv->stdout, NULL, NULL);
		g_object_unref (runner->priv->stdout);

		runner->priv->stdout = NULL;
	}

	gitg_io_close (GITG_IO (runner));
}

static void
gitg_runner_dispose (GObject *object)
{
	GitgRunner *runner;

	runner = GITG_RUNNER (object);

	if (runner->priv->command != NULL)
	{
		g_object_unref (runner->priv->command);
		runner->priv->command = NULL;
	}

	gitg_io_cancel (GITG_IO (runner));

	close_streams (runner);

	G_OBJECT_CLASS (gitg_runner_parent_class)->dispose (object);
}

static void
gitg_runner_set_property (GObject      *object,
                          guint         prop_id,
                          const GValue *value,
                          GParamSpec   *pspec)
{
	GitgRunner *self = GITG_RUNNER (object);

	switch (prop_id)
	{
		case PROP_COMMAND:
			gitg_runner_set_command (self, g_value_get_object (value));
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_runner_get_property (GObject    *object,
                          guint       prop_id,
                          GValue     *value,
                          GParamSpec *pspec)
{
	GitgRunner *self = GITG_RUNNER (object);

	switch (prop_id)
	{
		case PROP_COMMAND:
			g_value_set_object (value, self->priv->command);
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
dummy_cb (GPid     pid,
          gint     status,
          gpointer data)
{
}

static void
kill_process (GitgRunner *runner)
{
	if (runner->priv->pid == 0)
	{
		return;
	}

	/* We remove our handler for the process here and install a dummy
	   handler later so it will still be properly reaped */
	g_source_remove (runner->priv->watch_id);
	kill (runner->priv->pid, SIGTERM);

	g_child_watch_add (runner->priv->pid, dummy_cb, NULL);

	runner->priv->pid = 0;

	gitg_io_set_exit_status (GITG_IO (runner), EXIT_FAILURE);
}

static void
runner_done (GitgRunner *runner,
             GError     *error)
{
	close_streams (runner);
	kill_process (runner);

	if (!error && gitg_io_get_exit_status (GITG_IO (runner)) != 0)
	{
		GError *err;

		err = g_error_new (G_IO_ERROR,
		                   G_IO_ERROR_FAILED,
		                   "Process exited with non-zero exit code: %d",
		                   gitg_io_get_exit_status (GITG_IO (runner)));

		gitg_io_end (GITG_IO (runner), err);
		g_error_free (err);
	}
	else
	{
		gitg_io_end (GITG_IO (runner), error);
	}
}

static void
gitg_runner_cancel (GitgIO *io)
{
	gboolean was_running;
	GitgRunner *runner;

	runner = GITG_RUNNER (io);

	if (runner->priv->cancellable)
	{
		g_cancellable_cancel (runner->priv->cancellable);

		g_object_unref (runner->priv->cancellable);
		runner->priv->cancellable = NULL;
	}

	was_running = gitg_io_get_running (GITG_IO (runner));

	GITG_IO_CLASS (gitg_runner_parent_class)->cancel (GITG_IO (runner));

	if (was_running)
	{
		runner_done (runner, NULL);
	}
}

static void
gitg_runner_class_init (GitgRunnerClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	GitgIOClass *io_class = GITG_IO_CLASS (klass);

	object_class->finalize = gitg_runner_finalize;
	object_class->dispose = gitg_runner_dispose;

	object_class->get_property = gitg_runner_get_property;
	object_class->set_property = gitg_runner_set_property;

	io_class->cancel = gitg_runner_cancel;

	g_type_class_add_private (object_class, sizeof(GitgRunnerPrivate));

	g_object_class_install_property (object_class,
	                                 PROP_COMMAND,
	                                 g_param_spec_object ("command",
	                                                      "Command",
	                                                      "Command",
	                                                      GITG_TYPE_COMMAND,
	                                                      G_PARAM_READWRITE | G_PARAM_CONSTRUCT));
}

static void
gitg_runner_init (GitgRunner *self)
{
	self->priv = GITG_RUNNER_GET_PRIVATE (self);
}

GitgRunner *
gitg_runner_new (GitgCommand *command)
{
	return g_object_new (GITG_TYPE_RUNNER,
	                     "command", command,
	                     NULL);
}

static void
splice_input_ready_cb (GOutputStream *source,
                       GAsyncResult  *result,
                       AsyncData     *data)
{
	GError *error = NULL;
	gboolean ret;

	ret = g_output_stream_splice_finish (source, result, &error);

	if (g_cancellable_is_cancelled (data->cancellable))
	{
		if (error)
		{
			g_error_free (error);
		}

		async_data_free (data);
		return;
	}

	if (!ret)
	{
		runner_done (data->runner, error);
	}

	if (error)
	{
		g_error_free (error);
	}

	async_data_free (data);
}

static void
splice_output_ready_cb (GOutputStream *source,
                        GAsyncResult  *result,
                        AsyncData     *data)
{
	GError *error = NULL;
	gboolean ret;

	ret = g_output_stream_splice_finish (source, result, &error);

	if (g_cancellable_is_cancelled (data->cancellable))
	{
		if (error)
		{
			g_error_free (error);
		}

		async_data_free (data);
		return;
	}

	if (!ret)
	{
		runner_done (data->runner, error);
	}
	else if (data->runner->priv->pid == 0)
	{
		runner_done (data->runner, NULL);
	}

	if (error)
	{
		g_error_free (error);
	}

	async_data_free (data);
}

void
gitg_runner_stream_close (GitgRunner *runner,
                          GError     *error)
{
	g_return_if_fail (GITG_IS_RUNNER (runner));

	if (runner->priv->pid == 0 || error)
	{
		runner_done (runner, error);
	}
	else
	{
		g_input_stream_close (runner->priv->stdout, NULL, NULL);
	}
}

static void
process_watch_cb (GPid        pid,
                  gint        status,
                  GitgRunner *runner)
{
	runner->priv->pid = 0;

	if (WIFEXITED (status))
	{
		gitg_io_set_exit_status (GITG_IO (runner), WEXITSTATUS (status));
	}
	else
	{
		gitg_io_set_exit_status (GITG_IO (runner), 0);
	}

	/* Note that we don't emit 'done' here because the streams might not
	   yet be ready with all their writing/reading */
	if (runner->priv->cancellable)
	{
		g_object_unref (runner->priv->cancellable);
		runner->priv->cancellable = NULL;
	}

	runner->priv->watch_id = 0;

	if (runner->priv->stdout == NULL || g_input_stream_is_closed (runner->priv->stdout))
	{
		runner_done (runner, NULL);
	}
}

void
gitg_runner_run (GitgRunner *runner)
{
	gboolean ret;
	gint stdinf;
	gint stdoutf;
	GFile *working_directory;
	gchar *wd_path = NULL;
	GInputStream *start_input;
	GOutputStream *end_output;
	GInputStream *output;
	GitgSmartCharsetConverter *smart;
	GError *error = NULL;

	g_return_if_fail (GITG_IS_RUNNER (runner));

	gitg_io_cancel (GITG_IO (runner));

	runner->priv->cancelled = FALSE;

	working_directory = gitg_command_get_working_directory (runner->priv->command);

	if (working_directory)
	{
		wd_path = g_file_get_path (working_directory);
		g_object_unref (working_directory);
	}

	start_input = gitg_io_get_input (GITG_IO (runner));

	ret = g_spawn_async_with_pipes (wd_path,
	                                (gchar **)gitg_command_get_arguments (runner->priv->command),
	                                (gchar **)gitg_command_get_environment (runner->priv->command),
	                                G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD |
	                                (gitg_debug_enabled (GITG_DEBUG_RUNNER) ? 0 : G_SPAWN_STDERR_TO_DEV_NULL),
	                                NULL,
	                                NULL,
	                                &(runner->priv->pid),
	                                start_input ? &stdinf : NULL,
	                                &stdoutf,
	                                NULL,
	                                &error);

	g_free (wd_path);

	gitg_io_begin (GITG_IO (runner));

	if (!ret)
	{
		runner_done (runner, error);
		g_error_free (error);
		return;
	}

	runner->priv->watch_id = g_child_watch_add (runner->priv->pid,
	                                            (GChildWatchFunc)process_watch_cb,
	                                            runner);

	if (start_input)
	{
		AsyncData *data;

		runner->priv->cancellable = g_cancellable_new ();

		runner->priv->stdin = G_OUTPUT_STREAM (g_unix_output_stream_new (stdinf,
		                                              TRUE));

		data = async_data_new (runner);

		/* Splice the supplied input to stdin of the process */
		g_output_stream_splice_async (runner->priv->stdin,
		                              start_input,
		                              G_OUTPUT_STREAM_SPLICE_CLOSE_SOURCE |
		                              G_OUTPUT_STREAM_SPLICE_CLOSE_TARGET,
		                              G_PRIORITY_DEFAULT,
		                              runner->priv->cancellable,
		                              (GAsyncReadyCallback)splice_input_ready_cb,
		                              data);
	}

	output = G_INPUT_STREAM (g_unix_input_stream_new (stdoutf,
	                                                  TRUE));

	smart = gitg_smart_charset_converter_new (gitg_encoding_get_candidates ());

	runner->priv->stdout = g_converter_input_stream_new (output,
	                                                     G_CONVERTER (smart));

	g_object_unref (smart);
	g_object_unref (output);

	end_output = gitg_io_get_output (GITG_IO (runner));

	if (end_output)
	{
		AsyncData *data;

		if (runner->priv->cancellable == NULL)
		{
			runner->priv->cancellable = g_cancellable_new ();
		}

		data = async_data_new (runner);

		/* Splice output of the process into the provided stream */
		g_output_stream_splice_async (end_output,
		                              runner->priv->stdout,
		                              G_OUTPUT_STREAM_SPLICE_CLOSE_SOURCE |
		                              G_OUTPUT_STREAM_SPLICE_CLOSE_TARGET,
		                              G_PRIORITY_DEFAULT,
		                              runner->priv->cancellable,
		                              (GAsyncReadyCallback)splice_output_ready_cb,
		                              data);
	}
}

GInputStream *
gitg_runner_get_stream (GitgRunner *runner)
{
	g_return_val_if_fail (GITG_IS_RUNNER (runner), NULL);

	return runner->priv->stdout;
}

void
gitg_runner_set_command (GitgRunner *runner, GitgCommand *command)
{
	g_return_if_fail (GITG_IS_RUNNER (runner));
	g_return_if_fail (GITG_IS_COMMAND (command));

	if (runner->priv->command)
	{
		g_object_unref (runner->priv->command);
	}

	runner->priv->command = g_object_ref_sink (command);
	g_object_notify (G_OBJECT (runner), "command");
}

GitgCommand *
gitg_runner_get_command (GitgRunner *runner)
{
	g_return_val_if_fail (GITG_IS_RUNNER (runner), NULL);

	return runner->priv->command;
}
