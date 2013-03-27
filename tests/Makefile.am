INCLUDES = -g -I$(top_srcdir) -I$(top_srcdir)/gitg -I$(top_srcdir)/libgitg $(GITG_DEBUG_FLAGS) $(GITG_CFLAGS)

noinst_PROGRAMS = $(TEST_PROGS) $(DEMO_PROGS)

AM_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

DEMO_PROGS = diff-view dash-view progress-bin

diff_view_SOURCES = diff-view.vala
diff_view_LDADD = $(GITG_PLUGIN_LIBS)
diff_view_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

dash_view_SOURCES = dash-view.vala
dash_view_LDADD = $(GITG_PLUGIN_LIBS)
dash_view_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

progress_bin_SOURCES = progress-bin.vala
progress_bin_LDADD = $(GITG_PLUGIN_LIBS)
progress_bin_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

TESTS = $(TEST_PROGS)

BUILT_SOURCES = 				\
	diff_view_vala.stamp			\
	dash_view_vala.stamp

CLEANFILES =					\
	$(diff_view_SOURCES:.vala=.c)		\
	$(dash_view_SOURCES:.vala=.c)		\
	$(BUILT_SOURCES)

-include $(top_srcdir)/git.mk
