#ifndef __GITG_CHANGED_FILE_H__
#define __GITG_CHANGED_FILE_H__

#include <glib-object.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define GITG_TYPE_CHANGED_FILE				(gitg_changed_file_get_type ())
#define GITG_CHANGED_FILE(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CHANGED_FILE, GitgChangedFile))
#define GITG_CHANGED_FILE_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CHANGED_FILE, GitgChangedFile const))
#define GITG_CHANGED_FILE_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_CHANGED_FILE, GitgChangedFileClass))
#define GITG_IS_CHANGED_FILE(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_CHANGED_FILE))
#define GITG_IS_CHANGED_FILE_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_CHANGED_FILE))
#define GITG_CHANGED_FILE_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_CHANGED_FILE, GitgChangedFileClass))

typedef struct _GitgChangedFile			GitgChangedFile;
typedef struct _GitgChangedFileClass	GitgChangedFileClass;
typedef struct _GitgChangedFilePrivate	GitgChangedFilePrivate;

typedef enum 
{
	GITG_CHANGED_FILE_STATUS_NONE = 0,
	GITG_CHANGED_FILE_STATUS_NEW,
	GITG_CHANGED_FILE_STATUS_MODIFIED,
	GITG_CHANGED_FILE_STATUS_DELETED	
} GitgChangedFileStatus;

typedef enum
{
	GITG_CHANGED_FILE_CHANGES_NONE = 0,
	GITG_CHANGED_FILE_CHANGES_CACHED,
	GITG_CHANGED_FILE_CHANGES_UNSTAGED
} GitgChangedFileChanges;

struct _GitgChangedFile {
	GObject parent;
	
	GitgChangedFilePrivate *priv;
};

struct _GitgChangedFileClass {
	GObjectClass parent_class;
};

GType gitg_changed_file_get_type (void) G_GNUC_CONST;
GitgChangedFile *gitg_changed_file_new(GFile *file);

GFile *gitg_changed_file_get_file(GitgChangedFile *file);
gboolean gitg_changed_file_equal(GitgChangedFile *file, GFile *other);

gchar const *gitg_changed_file_get_sha(GitgChangedFile *file);
gchar const *gitg_changed_file_get_mode(GitgChangedFile *file);

void gitg_changed_file_set_sha(GitgChangedFile *file, gchar const *sha);
void gitg_changed_file_set_mode(GitgChangedFile *file, gchar const *mode);

GitgChangedFileStatus gitg_changed_file_get_status(GitgChangedFile *file);
GitgChangedFileChanges gitg_changed_file_get_changes(GitgChangedFile *file);

void gitg_changed_file_set_status(GitgChangedFile *file, GitgChangedFileStatus status);
void gitg_changed_file_set_changes(GitgChangedFile *file, GitgChangedFileChanges changes);

G_END_DECLS

#endif /* __GITG_CHANGED_FILE_H__ */
