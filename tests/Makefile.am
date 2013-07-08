AM_CPPFLAGS = -g -I$(top_srcdir) -I$(top_srcdir)/gitg -I$(top_srcdir)/libgitg $(GITG_DEBUG_FLAGS) $(GITG_CFLAGS)

noinst_PROGRAMS = $(TEST_PROGS) $(DEMO_PROGS)

AM_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

DEMO_PROGS = diff-view repository-list-box progress-bin

diff_view_SOURCES = diff-view.vala
diff_view_LDADD = $(GITG_PLUGIN_LIBS)
diff_view_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

repository_list_box_SOURCES = repository-list-box.vala
repository_list_box_LDADD = $(GITG_PLUGIN_LIBS)
repository_list_box_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

progress_bin_SOURCES = progress-bin.vala
progress_bin_LDADD = $(GITG_PLUGIN_LIBS)
progress_bin_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

TESTS = $(TEST_PROGS)

BUILT_SOURCES = 				\
	diff_view_vala.stamp			\
	repository_list_box_vala.stamp			\
	progress_bin_vala.stamp

CLEANFILES =					\
	$(diff_view_SOURCES:.vala=.c)		\
	$(repository_list_box_SOURCES:.vala=.c)		\
	$(progress_bin_SOURCES:.vala=.c)	\
	$(BUILT_SOURCES)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
