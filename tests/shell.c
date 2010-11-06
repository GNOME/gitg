#include <libgitg/gitg-shell.h>
#include <string.h>

#define test_add_repo(name, callback) g_test_add (name, RepositoryInfo, NULL, repository_setup, callback, repository_cleanup)

typedef struct
{
	GitgRepository *repository;
} RepositoryInfo;

static gboolean
remove_all (gchar const *path,
            GError      **error)
{
	gchar const *argv[] = {
		"rm",
		"-rf",
		path,
		NULL
	};

	g_spawn_sync ("/",
	              (gchar **)argv,
	              NULL,
	              G_SPAWN_SEARCH_PATH |
	              G_SPAWN_STDOUT_TO_DEV_NULL |
	              G_SPAWN_STDERR_TO_DEV_NULL,
	              NULL,
	              NULL,
	              NULL,
	              NULL,
	              NULL,
	              error);
}

static void
repository_setup (RepositoryInfo *info,
                  gconstpointer   data)
{
	/* Create repository */
	gchar const *tmp = g_get_tmp_dir ();
	gchar *repo_path;
	GError *error = NULL;

	repo_path = g_build_filename (tmp, "gitg-test-repo", NULL);

	if (g_file_test (repo_path, G_FILE_TEST_EXISTS))
	{
		remove_all (repo_path, &error);

		g_assert_no_error (error);
	}

	g_assert (g_mkdir (repo_path, 0700) == 0);

	gchar const *argv[] = {
		"git",
		"init",
		NULL,
		NULL,
		NULL
	};

	g_spawn_sync (repo_path,
	              (gchar **)argv,
	              NULL,
	              G_SPAWN_SEARCH_PATH |
	              G_SPAWN_STDOUT_TO_DEV_NULL |
	              G_SPAWN_STDERR_TO_DEV_NULL,
	              NULL,
	              NULL,
	              NULL,
	              NULL,
	              NULL,
	              &error);

	g_assert_no_error (error);

	argv[0] = "/bin/bash";
	argv[1] = "-c";
	argv[2] = "echo haha > test.txt && git add test.txt && git commit -m 'Initial import'";

	g_spawn_sync (repo_path,
	              (gchar **)argv,
	              NULL,
	              G_SPAWN_STDOUT_TO_DEV_NULL |
	              G_SPAWN_STDERR_TO_DEV_NULL,
	              NULL,
	              NULL,
	              NULL,
	              NULL,
	              NULL,
	              &error);

	g_assert_no_error (error);

	GFile *work_tree = g_file_new_for_path (repo_path);
	gchar *git_dir_path = g_build_filename (repo_path, ".git", NULL);
	GFile *git_dir = g_file_new_for_path (git_dir_path);
	g_free (git_dir_path);

	info->repository = gitg_repository_new (git_dir, work_tree);

	g_object_unref (work_tree);
	g_object_unref (git_dir);
}

static void
repository_cleanup (RepositoryInfo *info,
                    gconstpointer   data)
{
	GFile *work_tree;
	GError *error = NULL;

	work_tree = gitg_repository_get_work_tree (info->repository);
	gchar *path = g_file_get_path (work_tree);
	g_object_unref (work_tree);

	remove_all (path, &error);
	g_free (path);

	g_assert_no_error (error);

	g_object_unref (info->repository);
}

static void
test_success (RepositoryInfo *info,
              gconstpointer   data)
{
	gboolean ret;
	GError *error = NULL;

	ret = gitg_shell_run_sync (gitg_command_new (info->repository,
	                                              "rev-parse",
	                                              "HEAD",
	                                              NULL),
	                           &error);

	g_assert_no_error (error);
	g_assert (ret);
}

static void
test_fail (RepositoryInfo *info,
           gconstpointer   data)
{
	gboolean ret;
	GError *error = NULL;

	ret = gitg_shell_run_sync (gitg_command_new (info->repository,
	                                              "bogus",
	                                              NULL),
	                           &error);

	g_assert (!ret);
	g_assert (error != NULL);

	g_error_free (error);
}

static void
test_output (RepositoryInfo *info,
             gconstpointer   data)
{
	gchar **ret;
	GError *error = NULL;

	ret = gitg_shell_run_sync_with_output (gitg_command_new (info->repository,
	                                                          "rev-parse",
	                                                          "HEAD",
	                                                          NULL),
	                                       FALSE,
	                                       &error);

	g_assert_no_error (error);

	g_assert (ret);
	g_assert (g_strv_length (ret) == 1);

	g_assert (strlen (ret[0]) == 40);
}

static void
test_input (void)
{
	gchar **ret;
	gchar const *input = "Hello world";
	GError *error = NULL;

	ret = gitg_shell_run_sync_with_input_and_output (gitg_command_new (NULL,
	                                                                    "cat",
	                                                                    "-",
	                                                                    NULL),
	                                                 FALSE,
	                                                 input,
	                                                 &error);

	g_assert_no_error (error);
	g_assert (ret);

	g_assert (g_strv_length (ret) == 1);
	g_assert_cmpstr (ret[0], ==, input);
}

static void
test_pipe (void)
{
	gchar **ret;
	GError *error = NULL;
	gchar const *input = "Hello world";

	ret = gitg_shell_run_sync_with_outputv (FALSE,
	                                        &error,
	                                        gitg_command_new (NULL, "echo", input, NULL),
	                                        gitg_command_new (NULL, "cat", "-", NULL),
	                                        NULL);

	g_assert_no_error (error);
	g_assert (ret);

	g_assert (g_strv_length (ret) == 1);
	g_assert_cmpstr (ret[0], ==, input);
}

static void
test_pipestr (void)
{
	gchar **ret;
	GError *error = NULL;
	gchar const *input = "Hello world";
	gchar *cmdstr;
	GitgCommand **commands;

	cmdstr = g_strconcat ("echo '", input, "' | cat -", NULL);

	commands = gitg_shell_parse_commands (NULL, cmdstr, &error);

	g_assert_no_error (error);
	g_assert (commands);

	ret = gitg_shell_run_sync_with_output_list (commands,
	                                            FALSE,
	                                            &error);

	g_assert_no_error (error);
	g_assert (ret);

	g_assert (g_strv_length (ret) == 1);
	g_assert_cmpstr (ret[0], ==, input);
}

int
main (int   argc,
      char *argv[])
{
	g_type_init ();
	g_test_init (&argc, &argv, NULL);

	gitg_debug_init ();

	test_add_repo ("/shell/success", test_success);
	test_add_repo ("/shell/fail", test_fail);

	test_add_repo ("/shell/output", test_output);

	g_test_add_func ("/shell/input", test_input);
	g_test_add_func ("/shell/pipe", test_pipe);
	g_test_add_func ("/shell/pipestr", test_pipestr);

	return g_test_run ();
}
/* ex:ts=8:noet: */
