/*
 * gitg-shell.c
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

#include "gitg-convert.h"
#include "gitg-debug.h"
#include "gitg-shell.h"
#include "gitg-smart-charset-converter.h"
#include "gitg-runner.h"

#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include <stdlib.h>

#include <gio/gio.h>
#include <gio/gunixoutputstream.h>
#include <gio/gunixinputstream.h>

#include "gitg-line-parser.h"

#define GITG_SHELL_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_SHELL, GitgShellPrivate))

/* Signals */
enum
{
	UPDATE,
	LAST_SIGNAL
};

static guint shell_signals[LAST_SIGNAL] = { 0 };

/* Properties */
enum
{
	PROP_0,

	PROP_BUFFER_SIZE,
	PROP_SYNCHRONIZED,
	PROP_PRESERVE_LINE_ENDINGS
};

struct _GitgShellPrivate
{
	GSList *runners;

	GCancellable *cancellable;
	GError *error;

	GMainLoop *main_loop;
	GitgRunner *last_runner;

	guint buffer_size;
	GitgLineParser *line_parser;

	guint synchronized : 1;
	guint preserve_line_endings : 1;
	guint cancelled : 1;
	guint read_done : 1;
};

static void shell_done (GitgShell *shell, GError *error);

G_DEFINE_TYPE (GitgShell, gitg_shell, GITG_TYPE_IO)

static void
runner_end (GitgRunner *runner,
            GError     *error,
            GitgShell  *shell)
{
	if (!shell->priv->runners)
	{
		return;
	}

	if ((runner == shell->priv->last_runner && shell->priv->read_done) || error)
	{
		shell_done (shell, error);
	}
}

static void
close_runners (GitgShell *shell)
{
	GSList *item;

	for (item = shell->priv->runners; item; item = g_slist_next (item))
	{
		GitgRunner *runner = item->data;

		g_signal_handlers_disconnect_by_func (runner,
		                                      runner_end,
		                                      shell);

		gitg_io_close (GITG_IO (runner));
		g_object_unref (runner);
	}

	g_slist_free (shell->priv->runners);
	shell->priv->runners = NULL;

	if (shell->priv->line_parser)
	{
		g_object_unref (shell->priv->line_parser);
		shell->priv->line_parser = NULL;
	}

	shell->priv->last_runner = NULL;
}

static void
gitg_shell_finalize (GObject *object)
{
	GitgShell *shell = GITG_SHELL (object);

	/* Cancel possible running */
	gitg_io_cancel (GITG_IO (shell));

	if (shell->priv->cancellable)
	{
		g_object_unref (shell->priv->cancellable);
	}

	G_OBJECT_CLASS (gitg_shell_parent_class)->finalize (object);
}

static void
gitg_shell_dispose (GObject *object)
{
	GitgShell *shell;

	shell = GITG_SHELL (object);

	close_runners (shell);
}

static void
gitg_shell_get_property (GObject    *object,
                          guint       prop_id,
                          GValue     *value,
                          GParamSpec *pspec)
{
	GitgShell *shell = GITG_SHELL (object);

	switch (prop_id)
	{
		case PROP_BUFFER_SIZE:
			g_value_set_uint (value, shell->priv->buffer_size);
			break;
		case PROP_SYNCHRONIZED:
			g_value_set_boolean (value, shell->priv->synchronized);
			break;
		case PROP_PRESERVE_LINE_ENDINGS:
			g_value_set_boolean (value, shell->priv->preserve_line_endings);
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
			break;
	}
}

static void
gitg_shell_set_property (GObject      *object,
                          guint         prop_id,
                          const GValue *value,
                          GParamSpec   *pspec)
{
	GitgShell *shell = GITG_SHELL (object);

	switch (prop_id)
	{
		case PROP_BUFFER_SIZE:
			shell->priv->buffer_size = g_value_get_uint (value);
			break;
		case PROP_SYNCHRONIZED:
			shell->priv->synchronized = g_value_get_boolean (value);
			break;
		case PROP_PRESERVE_LINE_ENDINGS:
			shell->priv->preserve_line_endings = g_value_get_boolean (value);
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
			break;
	}
}

static void
gitg_shell_cancel (GitgIO *io)
{
	gboolean was_running;
	GitgShell *shell;

	shell = GITG_SHELL (io);

	if (shell->priv->line_parser)
	{
		g_object_unref (shell->priv->line_parser);
		shell->priv->line_parser = NULL;
	}

	was_running = gitg_io_get_running (io);

	GITG_IO_CLASS (gitg_shell_parent_class)->cancel (io);

	if (was_running)
	{
		shell_done (GITG_SHELL (io), NULL);
	}
}

static void
gitg_shell_class_init (GitgShellClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	GitgIOClass *io_class = GITG_IO_CLASS (klass);

	object_class->finalize = gitg_shell_finalize;
	object_class->dispose = gitg_shell_dispose;

	object_class->get_property = gitg_shell_get_property;
	object_class->set_property = gitg_shell_set_property;

	io_class->cancel = gitg_shell_cancel;

	g_object_class_install_property (object_class, PROP_BUFFER_SIZE,
	                                 g_param_spec_uint ("buffer_size",
	                                                    "BUFFER SIZE",
	                                                    "The shells buffer size",
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

	g_object_class_install_property (object_class,
	                                 PROP_PRESERVE_LINE_ENDINGS,
	                                 g_param_spec_boolean ("preserve-line-endings",
	                                                       "Preserve Line Endings",
	                                                       "preserve line endings",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	shell_signals[UPDATE] =
		g_signal_new ("update",
		              G_OBJECT_CLASS_TYPE (object_class),
		              G_SIGNAL_RUN_LAST,
		              G_STRUCT_OFFSET (GitgShellClass, update),
		              NULL,
		              NULL,
		              g_cclosure_marshal_VOID__POINTER,
		              G_TYPE_NONE,
		              1,
		              G_TYPE_POINTER);

	g_type_class_add_private (object_class, sizeof (GitgShellPrivate));
}

static void
gitg_shell_init (GitgShell *self)
{
	self->priv = GITG_SHELL_GET_PRIVATE (self);

	self->priv->cancellable = g_cancellable_new ();
}

GitgShell *
gitg_shell_new (guint buffer_size)
{
	g_assert (buffer_size > 0);

	return GITG_SHELL (g_object_new (GITG_TYPE_SHELL,
	                                  "buffer_size",
	                                  buffer_size,
	                                  "synchronized",
	                                  FALSE,
	                                  NULL));
}

GitgShell *
gitg_shell_new_synchronized (guint buffer_size)
{
	g_assert (buffer_size > 0);

	return GITG_SHELL (g_object_new (GITG_TYPE_SHELL,
	                                  "buffer_size",
	                                  buffer_size,
	                                  "synchronized",
	                                  TRUE,
	                                  NULL));
}

void
gitg_shell_set_preserve_line_endings (GitgShell *shell,
                                       gboolean    preserve_line_endings)
{
	g_return_if_fail (GITG_IS_SHELL (shell));

	shell->priv->preserve_line_endings = preserve_line_endings;
	g_object_notify (G_OBJECT (shell), "preserve-line-endings");
}

gboolean
gitg_shell_get_preserve_line_endings (GitgShell *shell)
{
	g_return_val_if_fail (GITG_IS_SHELL (shell), FALSE);

	return shell->priv->preserve_line_endings;
}

static void
shell_done (GitgShell *shell,
            GError    *error)
{
	if (shell->priv->error)
	{
		g_error_free (shell->priv->error);
		shell->priv->error = NULL;
	}

	if (error)
	{
		shell->priv->error = g_error_copy (error);
		gitg_io_set_exit_status (GITG_IO (shell), EXIT_FAILURE);
	}

	if (shell->priv->main_loop)
	{
		g_main_loop_quit (shell->priv->main_loop);
		g_main_loop_unref (shell->priv->main_loop);

		shell->priv->main_loop = NULL;
	}

	if (shell->priv->runners == NULL)
	{
		return;
	}

	if (shell->priv->cancellable)
	{
		g_cancellable_cancel (shell->priv->cancellable);
		g_object_unref (shell->priv->cancellable);

		shell->priv->cancellable = NULL;
	}

	/* Take over the exit code of the last runner */
	if (!error)
	{
		gitg_io_set_exit_status (GITG_IO (shell),
		                         gitg_io_get_exit_status (GITG_IO (shell->priv->last_runner)));
	}

	close_runners (shell);
	gitg_io_close (GITG_IO (shell));

	gitg_io_end (GITG_IO (shell), error);
}

static gboolean
run_sync (GitgShell  *shell,
          GError    **error)
{
	g_main_loop_run (shell->priv->main_loop);

	if (shell->priv->error)
	{
		g_propagate_error (error, shell->priv->error);
		shell->priv->error = NULL;

		return FALSE;
	}

	return gitg_io_get_exit_status (GITG_IO (shell)) == 0;
}

static void
on_lines_done_cb (GitgLineParser *parser,
                  GError         *error,
                  GitgShell      *shell)
{
	if (!shell->priv->read_done)
	{
		shell->priv->read_done = TRUE;

		if (shell->priv->last_runner == NULL)
		{
			shell_done (shell, error);
		}
		else
		{
			gitg_runner_stream_close (shell->priv->last_runner, NULL);
		}
	}
}

static void
on_lines_cb (GitgLineParser  *parser,
             gchar          **lines,
             GitgShell       *shell)
{
	g_signal_emit (shell, shell_signals[UPDATE], 0, lines);
}

static void
run_stream (GitgShell    *shell,
            GInputStream *stream)
{
	shell->priv->cancellable = g_cancellable_new ();

	shell->priv->read_done = FALSE;

	shell->priv->line_parser = gitg_line_parser_new (shell->priv->buffer_size,
	                                                 shell->priv->preserve_line_endings);

	g_signal_connect (shell->priv->line_parser,
	                  "lines",
	                  G_CALLBACK (on_lines_cb),
	                  shell);

	g_signal_connect (shell->priv->line_parser,
	                  "done",
	                  G_CALLBACK (on_lines_done_cb),
	                  shell);

	gitg_line_parser_parse (shell->priv->line_parser,
	                        stream,
	                        shell->priv->cancellable);
}

static gboolean
run_commands (GitgShell    *shell,
              GitgCommand **commands,
              GError      **error)
{
	GitgIO *io;
	GitgRunner *prev = NULL;
	GOutputStream *output;
	gboolean ret = TRUE;
	GitgCommand **ptr;

	io = GITG_IO (shell);
	output = gitg_io_get_output (io);

	shell->priv->read_done = TRUE;

	gitg_io_cancel (GITG_IO (shell));

	gitg_io_begin (GITG_IO (shell));

	/* Ref sink all commands */
	for (ptr = commands; *ptr; ++ptr)
	{
		g_object_ref_sink (*ptr);
	}

	if (shell->priv->synchronized)
	{
		shell->priv->main_loop = g_main_loop_new (NULL, FALSE);
	}

	/* Setup runners */
	for (ptr = commands; *ptr; ++ptr)
	{
		GitgRunner *runner;

		runner = gitg_runner_new (*ptr);

		g_signal_connect (runner,
		                  "end",
		                  G_CALLBACK (runner_end),
		                  shell);

		if (ptr == commands)
		{
			/* Copy input set on the shell to the first runner */
			GInputStream *input;

			input = gitg_io_get_input (io);

			if (input != NULL)
			{
				gitg_io_set_input (GITG_IO (runner), input);
			}
		}
		else
		{
			/* Set output of the previous runner to the input of
			   this runner */
			gitg_io_set_input (GITG_IO (runner),
			                   gitg_runner_get_stream (prev));
		}

		if (!*(ptr + 1))
		{
			shell->priv->last_runner = runner;

			/* Copy output set on the shell to the last runner */
			if (output != NULL)
			{
				gitg_io_set_output (GITG_IO (runner), output);
			}
		}

		shell->priv->runners = g_slist_append (shell->priv->runners,
		                                       runner);

		/* Start the runner */
		gitg_runner_run (runner);

		if (shell->priv->runners == NULL)
		{
			/* This means it there was an error */
			if (error && shell->priv->error)
			{
				*error = g_error_copy (shell->priv->error);
			}

			if (shell->priv->error)
			{
				g_error_free (shell->priv->error);
				shell->priv->error = NULL;
			}

			ret = FALSE;
			goto cleanup;
		}

		prev = runner;
	}

	/* Setup line reader if necessary in async mode */
	if (output == NULL)
	{
		run_stream (shell, gitg_runner_get_stream (shell->priv->last_runner));
	}

	if (shell->priv->synchronized)
	{
		return run_sync (shell, error);
	}

cleanup:
	for (ptr = commands; *ptr; ++ptr)
	{
		g_object_unref (*ptr);
	}

	if (shell->priv->main_loop)
	{
		g_main_loop_unref (shell->priv->main_loop);
		shell->priv->main_loop = NULL;
	}

	return ret;
}

gboolean
gitg_shell_run (GitgShell    *shell,
                GitgCommand  *command,
                GError      **error)
{
	g_return_val_if_fail (GITG_IS_SHELL (shell), FALSE);
	g_return_val_if_fail (GITG_IS_COMMAND (command), FALSE);

	return gitg_shell_runv (shell, error, command, NULL);
}

gboolean
gitg_shell_run_list (GitgShell    *shell,
                     GitgCommand **commands,
                     GError      **error)
{
	g_return_val_if_fail (GITG_IS_SHELL (shell), FALSE);

	return run_commands (shell, commands, error);
}

gboolean
gitg_shell_runva (GitgShell  *shell,
                  va_list     ap,
                  GError    **error)
{
	GPtrArray *ptr;
	GitgCommand **commands;
	GitgCommand *command;
	gboolean ret;
	guint num = 0;

	g_return_val_if_fail (GITG_IS_SHELL (shell), FALSE);

	ptr = g_ptr_array_new ();

	while ((command = va_arg (ap, GitgCommand *)) != NULL)
	{
		g_ptr_array_add (ptr, command);
		++num;
	}

	if (num == 0)
	{
		g_ptr_array_free (ptr, TRUE);
		return FALSE;
	}

	g_ptr_array_add (ptr, NULL);

	commands = (GitgCommand **)g_ptr_array_free (ptr, FALSE);

	ret = gitg_shell_run_list (shell, commands, error);

	g_free (commands);

	return ret;
}

gboolean
gitg_shell_runv (GitgShell  *shell,
                 GError    **error,
                 ...)
{
	va_list ap;
	gboolean ret;

	g_return_val_if_fail (GITG_IS_SHELL (shell), FALSE);

	va_start (ap, error);
	ret = gitg_shell_runva (shell, ap, error);
	va_end (ap);

	return ret;
}

guint
gitg_shell_get_buffer_size (GitgShell *shell)
{
	g_return_val_if_fail (GITG_IS_SHELL (shell), 0);
	return shell->priv->buffer_size;
}

gchar **
gitg_shell_run_sync_with_output (GitgCommand  *command,
                                 gboolean      preserve_line_endings,
                                 GError      **error)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), NULL);

	return gitg_shell_run_sync_with_outputv (preserve_line_endings,
	                                         error,
	                                         command,
	                                         NULL);
}

static void
collect_update (GitgShell           *shell,
                gchar const * const *lines,
                GPtrArray           *ret)
{
	while (lines && *lines)
	{
		g_ptr_array_add (ret, g_strdup (*lines++));
	}
}

gchar **
gitg_shell_run_sync_with_input_and_output_list (GitgCommand **commands,
                                                gboolean      preserve_line_endings,
                                                const gchar  *input,
                                                GError      **error)
{
	GitgShell *shell;
	GPtrArray *ret;
	gboolean res;
	gchar **val;

	shell = gitg_shell_new_synchronized (1000);

	gitg_shell_set_preserve_line_endings (shell, preserve_line_endings);

	ret = g_ptr_array_sized_new (100);

	g_signal_connect (shell,
	                  "update",
	                  G_CALLBACK (collect_update),
	                  ret);

	if (input)
	{
		GInputStream *stream;

		stream = g_memory_input_stream_new_from_data (g_strdup (input),
		                                              -1,
		                                              (GDestroyNotify)g_free);

		gitg_io_set_input (GITG_IO (shell), stream);
		g_object_unref (stream);
	}

	res = gitg_shell_run_list (shell, commands, error);

	g_ptr_array_add (ret, NULL);

	if (!res || gitg_io_get_exit_status (GITG_IO (shell)) != 0)
	{
		g_strfreev ((gchar **)g_ptr_array_free (ret, FALSE));
		g_object_unref (shell);

		return NULL;
	}

	val = (gchar **)g_ptr_array_free (ret, FALSE);
	g_object_unref (shell);

	return val;

}

static gchar **
gitg_shell_run_sync_with_input_and_outputva (gboolean      preserve_line_endings,
                                             const gchar  *input,
                                             va_list       ap,
                                             GError      **error)
{
	GPtrArray *commands;
	GitgCommand *cmd;
	GitgCommand **cmds;
	gchar **ret;

	commands = g_ptr_array_new ();

	while ((cmd = va_arg (ap, GitgCommand *)))
	{
		g_ptr_array_add (commands, cmd);
	}

	g_ptr_array_add (commands, NULL);
	cmds = (GitgCommand **)g_ptr_array_free (commands, FALSE);

	ret = gitg_shell_run_sync_with_input_and_output_list (cmds,
	                                                      preserve_line_endings,
	                                                      input,
	                                                      error);

	g_free (cmds);
	return ret;
}

static gchar **
gitg_shell_run_sync_with_outputva (gboolean   preserve_line_endings,
                                   va_list    ap,
                                   GError   **error)
{
	return gitg_shell_run_sync_with_input_and_outputva (preserve_line_endings,
	                                                    NULL,
	                                                    ap,
	                                                    error);
}

gchar **
gitg_shell_run_sync_with_output_list (GitgCommand **commands,
                                      gboolean      preserve_line_endings,
                                      GError      **error)
{
	return gitg_shell_run_sync_with_input_and_output_list (commands,
	                                                       preserve_line_endings,
	                                                       NULL,
	                                                       error);
}

gchar **
gitg_shell_run_sync_with_outputv (gboolean   preserve_line_endings,
                                  GError   **error,
                                  ...)
{
	va_list ap;
	gchar **ret;

	va_start (ap, error);
	ret = gitg_shell_run_sync_with_outputva (preserve_line_endings,
	                                         ap,
	                                         error);
	va_end (ap);

	return ret;
}

gboolean
gitg_shell_run_sync (GitgCommand  *command,
                     GError      **error)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), FALSE);

	return gitg_shell_run_syncv (error, command, NULL);
}

gboolean
gitg_shell_run_sync_list (GitgCommand **commands,
                          GError      **error)
{
	gchar **res;

	res = gitg_shell_run_sync_with_output_list (commands, FALSE, error);

	if (res)
	{
		g_strfreev (res);
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}

gboolean
gitg_shell_run_syncv (GError **error,
                      ...)
{
	va_list ap;
	gchar **res;

	va_start (ap, error);
	res = gitg_shell_run_sync_with_outputva (FALSE, ap, error);
	va_end (ap);

	if (res)
	{
		g_strfreev (res);
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}

gboolean
gitg_shell_run_sync_with_input (GitgCommand  *command,
                                const gchar  *input,
                                GError      **error)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), FALSE);

	return gitg_shell_run_sync_with_inputv (input, error, command, NULL);
}

gboolean
gitg_shell_run_sync_with_input_list (GitgCommand  **commands,
                                     const gchar  *input,
                                     GError      **error)
{
	gchar **ret;

	ret = gitg_shell_run_sync_with_input_and_output_list (commands,
	                                                      FALSE,
	                                                      input,
	                                                      error);

	if (ret)
	{
		g_strfreev (ret);
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}

gboolean
gitg_shell_run_sync_with_inputv (const gchar  *input,
                                 GError      **error,
                                 ...)
{
	va_list ap;
	gchar **ret;

	va_start (ap, error);
	ret = gitg_shell_run_sync_with_input_and_outputva (FALSE,
	                                                   input,
	                                                   ap,
	                                                   error);
	va_end (ap);

	if (ret)
	{
		g_strfreev (ret);
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}

gchar **
gitg_shell_run_sync_with_input_and_output (GitgCommand  *command,
                                           gboolean      preserve_line_endings,
                                           const gchar  *input,
                                           GError      **error)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), NULL);

	return gitg_shell_run_sync_with_input_and_outputv (preserve_line_endings,
	                                                   input,
	                                                   error,
	                                                   command,
	                                                   NULL);
}

gchar **
gitg_shell_run_sync_with_input_and_outputv (gboolean      preserve_line_endings,
                                            const gchar  *input,
                                            GError      **error,
                                            ...)
{
	va_list ap;
	gchar **ret;

	va_start (ap, error);
	ret = gitg_shell_run_sync_with_input_and_outputva (preserve_line_endings,
	                                                   input,
	                                                   ap,
	                                                   error);
	va_end (ap);

	return ret;
}

GitgCommand **
gitg_shell_parse_commands (GitgRepository  *repository,
                           const gchar     *cmdstr,
                           GError         **error)
{
	gint argc;
	gchar **argv;
	GitgCommand *cmd = NULL;
	gint i;
	GPtrArray *commands;
	gboolean canenv = TRUE;
	guint num = 0;

	g_return_val_if_fail (repository == NULL || GITG_IS_REPOSITORY (repository), NULL);
	g_return_val_if_fail (cmdstr != NULL, NULL);

	if (!g_shell_parse_argv (cmdstr, &argc, &argv, error))
	{
		return FALSE;
	}

	commands = g_ptr_array_new ();

	for (i = 0; i < argc; ++i)
	{
		gchar *pos;

		if (cmd == NULL)
		{
			cmd = gitg_command_new (repository, NULL);
			g_ptr_array_add (commands, cmd);

			canenv = TRUE;
			++num;
		}

		if (strcmp (argv[i], "|") == 0)
		{
			cmd = NULL;
		}
		else if (canenv && (pos = g_utf8_strchr (argv[i], -1, '=')))
		{
			*pos = '\0';
			gitg_command_add_environment (cmd, argv[i], pos + 1, NULL);
		}
		else
		{
			canenv = FALSE;
			gitg_command_add_arguments (cmd, argv[i], NULL);
		}
	}

	g_strfreev (argv);
	g_ptr_array_add (commands, NULL);

	return (GitgCommand **)g_ptr_array_free (commands, FALSE);
}

gboolean
gitg_shell_run_parse (GitgShell       *shell,
                      GitgRepository  *repository,
                      const gchar     *cmdstr,
                      GError         **error)

{
	gboolean ret;
	GitgCommand **commands;

	g_return_val_if_fail (GITG_IS_SHELL (shell), FALSE);
	g_return_val_if_fail (cmdstr != NULL, FALSE);
	g_return_val_if_fail (repository == NULL || GITG_IS_REPOSITORY (repository), FALSE);

	commands = gitg_shell_parse_commands (repository, cmdstr, error);

	if (!commands)
	{
		return FALSE;
	}

	ret = run_commands (shell, commands, error);
	g_free (commands);

	return ret;
}

gboolean
gitg_shell_run_stream (GitgShell     *shell,
                       GInputStream  *stream,
                       GError       **error)
{
	g_return_val_if_fail (GITG_IS_SHELL (shell), FALSE);
	g_return_val_if_fail (G_IS_INPUT_STREAM (stream), FALSE);

	gitg_io_cancel (GITG_IO (shell));

	run_stream (shell, stream);
	return TRUE;
}
