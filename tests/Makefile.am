INCLUDES = -g -I$(top_srcdir) -I$(top_srcdir)/gitg -I$(top_srcdir)/libgitg $(GITG_DEBUG_FLAGS) $(GITG_CFLAGS)

noinst_PROGRAMS = $(TEST_PROGS) $(DEMO_PROGS)

VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

DEMO_PROGS = diff-view dash-view

diff_view_SOURCES = diff-view.vala
diff_view_LDADD = $(GITG_PLUGIN_LIBS)
diff_view_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

dash_view_SOURCES = dash-view.vala
dash_view_LDADD = $(GITG_PLUGIN_LIBS)
dash_view_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

TESTS = $(TEST_PROGS)

BUILT_SOURCES = 				\
	diff_view_vala.stamp			\
	$(diff_view_SOURCES:.vala=.c)

-include $(top_srcdir)/git.mk
