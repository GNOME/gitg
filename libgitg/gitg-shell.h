/*
 * gitg-shell.h
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

#ifndef __GITG_SHELL_H__
#define __GITG_SHELL_H__

#include <glib-object.h>
#include <libgitg/gitg-io.h>
#include <libgitg/gitg-command.h>
#include <libgitg/gitg-repository.h>

G_BEGIN_DECLS

#define GITG_TYPE_SHELL			(gitg_shell_get_type ())
#define GITG_SHELL(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_SHELL, GitgShell))
#define GITG_SHELL_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_SHELL, GitgShell const))
#define GITG_SHELL_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_SHELL, GitgShellClass))
#define GITG_IS_SHELL(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_SHELL))
#define GITG_IS_SHELL_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_SHELL))
#define GITG_SHELL_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_SHELL, GitgShellClass))

#define GITG_SHELL_ERROR		(gitg_shell_error_quark())

typedef struct _GitgShell		GitgShell;
typedef struct _GitgShellClass		GitgShellClass;
typedef struct _GitgShellPrivate	GitgShellPrivate;

struct _GitgShell
{
	GitgIO parent;

	GitgShellPrivate *priv;
};

struct _GitgShellClass
{
	GitgIOClass parent_class;

	/* signals */
	void (* update)        (GitgShell           *shell,
	                        gchar const * const *buffer);
};

GType gitg_shell_get_type                       (void) G_GNUC_CONST;

GitgShell *gitg_shell_new                       (guint        buffer_size);
GitgShell *gitg_shell_new_synchronized          (guint        buffer_size);

void       gitg_shell_set_preserve_line_endings (GitgShell    *shell,
                                                 gboolean      preserve_line_endings);
gboolean   gitg_shell_get_preserve_line_endings (GitgShell    *shell);

guint      gitg_shell_get_buffer_size           (GitgShell    *shell);

GitgCommand **gitg_shell_parse_commands         (GitgRepository  *repository,
                                                 const gchar     *cmdstr,
                                                 GError         **error);

gboolean   gitg_shell_run_parse                 (GitgShell       *shell,
                                                 GitgRepository  *repository,
                                                 const gchar     *cmd,
                                                 GError         **error);

gboolean   gitg_shell_runva                     (GitgShell    *shell,
                                                 va_list       ap,
                                                 GError      **error);

gboolean   gitg_shell_run_stream                (GitgShell     *shell,
                                                 GInputStream  *stream,
                                                 GError       **error);

gboolean   gitg_shell_run                       (GitgShell     *shell,
                                                 GitgCommand   *command,
                                                 GError       **error);

gboolean   gitg_shell_run_list                  (GitgShell     *shell,
                                                 GitgCommand  **commands,
                                                 GError       **error);

gboolean   gitg_shell_runv                      (GitgShell     *shell,
                                                 GError       **error,
                                                ...) G_GNUC_NULL_TERMINATED;

gchar    **gitg_shell_run_sync_with_output      (GitgCommand  *command,
                                                 gboolean      preserve_line_endings,
                                                 GError      **error);

gchar    **gitg_shell_run_sync_with_output_list (GitgCommand **commands,
                                                 gboolean      preserve_line_endings,
                                                 GError      **error);

gchar    **gitg_shell_run_sync_with_outputv     (gboolean      preserve_line_endings,
                                                 GError      **error,
                                                 ...) G_GNUC_NULL_TERMINATED;

gboolean   gitg_shell_run_sync                  (GitgCommand  *command,
                                                 GError      **error);

gboolean   gitg_shell_run_sync_list             (GitgCommand **commands,
                                                 GError      **error);

gboolean   gitg_shell_run_syncv                 (GError      **error,
                                                 ...) G_GNUC_NULL_TERMINATED;

gboolean   gitg_shell_run_sync_with_input       (GitgCommand  *command,
                                                 const gchar  *input,
                                                 GError      **error);

gboolean   gitg_shell_run_sync_with_input_list  (GitgCommand **commands,
                                                 const gchar  *input,
                                                 GError      **error);

gboolean   gitg_shell_run_sync_with_inputv      (const gchar  *input,
                                                 GError      **error,
                                                 ...) G_GNUC_NULL_TERMINATED;

gchar    **gitg_shell_run_sync_with_input_and_output (GitgCommand  *command,
                                                      gboolean      preserve_line_endings,
                                                      const gchar  *input,
                                                      GError      **error);

gchar    **gitg_shell_run_sync_with_input_and_output_list (GitgCommand **commands,
                                                           gboolean      preserve_line_endings,
                                                           const gchar  *input,
                                                           GError      **error);

gchar    **gitg_shell_run_sync_with_input_and_outputv (gboolean      preserve_line_endings,
                                                       const gchar  *input,
                                                       GError      **error,
                                                       ...) G_GNUC_NULL_TERMINATED;

G_END_DECLS

#endif /* __GITG_SHELL_H__ */
