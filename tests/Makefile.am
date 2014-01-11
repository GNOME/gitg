tests_common_cppflags =			\
	-I$(top_srcdir)			\
	-I$(top_srcdir)/gitg		\
	-I$(top_srcdir)/libgitg

tests_common_cflags = 			\
	-g				\
	$(GITG_DEBUG_FLAGS)		\
	$(GITG_CFLAGS)			\
	-w

tests_common_ldflags = 			\
	$(GITG_PLUGIN_LIBS)

tests_common_valaflags = $(GITG_PLUGIN_VALAFLAGS)

noinst_PROGRAMS += $(TESTS_DEMO_PROGS)

TESTS_DEMO_PROGS =			\
	tests/diff-view			\
	tests/repository-list-box	\
	tests/progress-bin

tests_diff_view_SOURCES = tests/diff-view.vala $(GITG_PLUGIN_VAPISOURCES)
tests_diff_view_VALAFLAGS = $(tests_common_valaflags)
tests_diff_view_CFLAGS = $(tests_common_cflags)
tests_diff_view_LDFLAGS = $(tests_common_ldflags)
tests_diff_view_CPPFLAGS = $(tests_common_cppflags)
tests_diff_view_LDADD = libgitg/libgitg-1.0.la

tests_repository_list_box_SOURCES = tests/repository-list-box.vala $(GITG_PLUGIN_VAPISOURCES)
tests_repository_list_box_VALAFLAGS = $(tests_common_valaflags)
tests_repository_list_box_CFLAGS = $(tests_common_cflags)
tests_repository_list_box_LDFLAGS = $(tests_common_ldflags)
tests_repository_list_box_CPPFLAGS = $(tests_common_cppflags)
tests_repository_list_box_LDADD = libgitg/libgitg-1.0.la

tests_progress_bin_SOURCES = tests/progress-bin.vala $(GITG_PLUGIN_VAPISOURCES)
tests_progress_bin_VALAFLAGS = $(tests_common_valaflags)
tests_progress_bin_CFLAGS = $(tests_common_cflags)
tests_progress_bin_LDFLAGS = $(tests_common_ldflags)
tests_progress_bin_CPPFLAGS = $(tests_common_cppflags)
tests_progress_bin_LDADD = libgitg/libgitg-1.0.la

include tests/libgitg/Makefile.am

# vi:ts=8:noet
