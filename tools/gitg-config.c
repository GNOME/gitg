#include <glib.h>
#include <stdlib.h>
#include <libgitg/gitg-config.h>
#include <libgitg/gitg-debug.h>

static gchar *repository_path = NULL;
static gboolean global = FALSE;
static gboolean regex = FALSE;

static GOptionEntry entries[] =
{
	{ "repository", 'r', 0, G_OPTION_ARG_FILENAME, &repository_path, "Repository path" },
	{ "global", 'g', 0, G_OPTION_ARG_NONE, &global, "Use the global configuration" },
	{ "regex", 'r', 0, G_OPTION_ARG_NONE, &regex, "Config name is a regular expression" },
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

	context = g_option_context_new ("- git config tool");

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

int
main (int argc, char *argv[])
{
	GitgRepository *repository = NULL;
	GMainLoop *loop;
	GError *error = NULL;
	GitgConfig *config;
	gint i;

	g_type_init ();

	parse_options (&argc, &argv);

	gitg_debug_init ();

	if (argc == 1)
	{
		g_print ("Please specify a config name...\n");
		return 1;
	}

	if (!global)
	{
		GFile *work_tree;
		GFile *git_dir;

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
	}

	config = gitg_config_new (repository);

	/* Create commands */
	for (i = 1; i < argc; ++i)
	{
		gchar *ret;

		if (regex)
		{
			ret = gitg_config_get_value_regex (config, argv[i], NULL);
		}
		else
		{
			ret = gitg_config_get_value (config, argv[i]);
		}

		g_print ("%s = %s\n", argv[i], ret);
	}

	if (repository)
	{
		g_object_unref (repository);
	}

	g_object_unref (config);

	return 0;
}
