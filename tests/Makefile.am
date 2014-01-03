SUBDIRS = libgitg

tests_common_cppflags =			\
	-I$(top_srcdir)			\
	-I$(top_srcdir)/gitg		\
	-I$(top_srcdir)/libgitg

tests_common_cflags = 			\
	-g				\
	$(GITG_DEBUG_FLAGS)		\
	$(GITG_CFLAGS)			\
	-w

tests_common_valaflags = $(GITG_PLUGIN_VALAFLAGS)

noinst_PROGRAMS = $(DEMO_PROGS)

DEMO_PROGS = diff-view repository-list-box progress-bin

diff_view_SOURCES = diff-view.vala
diff_view_VALAFLAGS = $(tests_common_valaflags)
diff_view_LDADD = $(GITG_PLUGIN_LIBS)
diff_view_CFLAGS = $(tests_common_cflags)
diff_view_CPPFLAGS = $(tests_common_cppflags)

repository_list_box_SOURCES = repository-list-box.vala
repository_list_box_VALAFLAGS = $(tests_common_valaflags)
repository_list_box_LDADD = $(GITG_PLUGIN_LIBS)
repository_list_box_CFLAGS = $(tests_common_cflags)
repository_list_box_CPPFLAGS = $(tests_common_cppflags)

progress_bin_SOURCES = progress-bin.vala
progress_bin_VALAFLAGS = $(tests_common_valaflags)
progress_bin_LDADD = $(GITG_PLUGIN_LIBS)
progress_bin_CFLAGS = $(tests_common_cflags)
progress_bin_CPPFLAGS = $(tests_common_cppflags)

GITIGNOREFILES =					\
	$(diff_view_SOURCES:%.vala=%.c)			\
	diff_view_vala.stamp				\
	$(repository_list_box_SOURCES:%.vala=%.c)	\
	repository_list_box_vala.stamp			\
	$(progress_bin_SOURCES:%.vala=%.c)		\
	progress_bin_vala.stamp

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
