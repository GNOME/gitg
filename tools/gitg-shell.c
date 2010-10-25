#include <glib.h>
#include <stdlib.h>
#include <libgitg/gitg-shell.h>
#include <gio/gunixinputstream.h>
#include <gio/gunixoutputstream.h>
#include <libgitg/gitg-debug.h>

static gchar *repository_path = NULL;

static GOptionEntry entries[] =
{
	{ "repository", 'r', 0, G_OPTION_ARG_FILENAME, &repository_path, "Repository path" },
	{ NULL }
};

static GFile *
find_git_dir (GFile *work_tree)
{
	GFile *ret;

	work_tree = g_file_dup (work_tree);

	while (work_tree)
	{
		ret = g_file_get_child (work_tree, ".git");

		if (g_file_query_exists (ret, NULL))
		{
			g_object_unref (work_tree);
			return ret;
		}
		else
		{
			GFile *tmp;

			tmp = g_file_get_parent (work_tree);
			g_object_unref (work_tree);

			work_tree = tmp;
		}
	}

	return NULL;
}

static void
parse_options (int *argc,
               char ***argv)
{
	GError *error = NULL;
	GOptionContext *context;

	context = g_option_context_new ("- git shell tool");

	g_option_context_set_ignore_unknown_options (context, TRUE);
	g_option_context_add_main_entries (context, entries, "gitg");

	if (!g_option_context_parse (context, argc, argv, &error))
	{
		g_print ("option parsing failed: %s\n", error->message);
		g_error_free (error);

		exit (1);
	}

	g_option_context_free (context);
}

static void
on_shell_end (GitgShell *shell,
              GError    *error,
              GMainLoop *loop)
{
	g_main_loop_quit (loop);
}

int
main (int argc, char *argv[])
{
	GitgRepository *repository;
	GFile *work_tree;
	GFile *git_dir;
	gint i;
	GString *cmdstr;
	gchar *cs;
	GitgCommand **commands;
	GitgShell *shell;
	GMainLoop *loop;
	GError *error = NULL;
	GInputStream *input;
	GOutputStream *output;

	g_type_init ();

	parse_options (&argc, &argv);

	gitg_debug_init ();

	if (i == 1)
	{
		g_print ("Please specify a command...\n");
		return 1;
	}

	if (!repository_path)
	{
		gchar *path;
		GFile *file;

		path = g_get_current_dir ();
		file = g_file_new_for_path (path);

		git_dir = find_git_dir (file);
		g_free (path);
		g_object_unref (file);

		if (git_dir)
		{
			work_tree = g_file_get_parent (git_dir);
		}
	}
	else
	{
		work_tree = g_file_new_for_commandline_arg (repository_path);
		git_dir = find_git_dir (work_tree);
	}

	if (!git_dir)
	{
		g_print ("Could not find git dir...\n");
		return 1;
	}

	repository = gitg_repository_new (git_dir, work_tree);

	g_object_unref (work_tree);
	g_object_unref (git_dir);

	cmdstr = g_string_new ("");

	/* Create commands */
	for (i = 1; i < argc; ++i)
	{
		gchar *quoted;

		if (strcmp (argv[i], "!") == 0)
		{
			quoted = g_strdup ("|");
		}
		else
		{
			quoted = g_shell_quote (argv[i]);
		}

		if (i != 1)
		{
			g_string_append_c (cmdstr, ' ');
		}

		g_string_append (cmdstr, quoted);
	}

	cs = g_string_free (cmdstr, FALSE);
	g_print ("Running: %s\n\n", cs);

	commands = gitg_shell_parse_commands (repository, cs, &error);

	g_free (cs);
	g_object_unref (repository);

	if (error)
	{
		g_print ("Could not parse arguments: %s\n", error->message);
		g_error_free (error);

		return 1;
	}

	loop = g_main_loop_new (NULL, FALSE);
	shell = gitg_shell_new (1000);

	input = g_unix_input_stream_new (STDIN_FILENO, TRUE);
	output = g_unix_output_stream_new (STDOUT_FILENO, TRUE);

	gitg_io_set_input (GITG_IO (shell), input);
	gitg_io_set_output (GITG_IO (shell), output);

	g_signal_connect (shell,
	                  "end",
	                  G_CALLBACK (on_shell_end),
	                  loop);

	if (!gitg_shell_run_list (shell, commands, &error))
	{
		g_print ("Error launching shell: %s\n", error->message);
		return 1;
	}

	g_free (commands);

	g_main_loop_run (loop);
	g_main_loop_unref (loop);
	g_object_unref (shell);

	return 0;
}
