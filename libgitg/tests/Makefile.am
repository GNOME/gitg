AM_CPPFLAGS = -g -I$(top_srcdir) -I$(top_srcdir)/gitg -I$(top_srcdir)/libgitg $(GITG_DEBUG_FLAGS) $(GITG_CFLAGS)

noinst_PROGRAMS = $(TEST_PROGS)

AM_VALAFLAGS = \
	--pkg posix --pkg gitg-assert		\
	--pkg Ggit-1.0				\
	--pkg libgitg-1.0			\
	--pkg gio-2.0				\
	--pkg gtk+-3.0				\
	--pkg gee-0.8				\
	--pkg libsoup-2.4			\
	--pkg webkit2gtk-3.0			\
	--pkg config				\
	$(GITG_VALAFLAGS)			\
	--vapidir $(srcdir)			\
	--vapidir $(top_srcdir)/vapi		\
	--vapidir $(top_builddir)/libgitg	\
	--disable-warnings

TEST_PROGS = test-libgitg

test_libgitg_SOURCES =				\
	test.vala				\
	main.vala				\
	repository.vala				\
	test-stage.vala				\
	test-date.vala				\
	test-commit.vala			\
	test-encoding.vala

test_libgitg_CFLAGS = $(LIBGITG_CFLAGS) -w

test_libgitg_LDADD = \
	$(top_builddir)/libgitg/libgitg-1.0.la	\
	$(LIBGITG_LIBS)

TESTS = $(TEST_PROGS)

BUILT_SOURCES =					\
	test_libgitg_vala.stamp

CLEANFILES =					\
	$(test_libgitg_SOURCES:.vala=.c)	\
	$(BUILT_SOURCES)

EXTRA_DIST = gitg-assert.h gitg-assert.vapi

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
