TEST_PROGS = test-libgitg

TESTS = $(TEST_PROGS)
noinst_PROGRAMS = $(TEST_PROGS)

test_libgitg_CPPFLAGS = 			\
	-I$(top_srcdir) 			\
	-I$(top_srcdir)/gitg 			\
	-I$(top_srcdir)/libgitg

test_libgitg_VALAFLAGS =			\
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

test_libgitg_CFLAGS =				\
	$(GITG_DEBUG_FLAGS)			\
	$(GITG_CFLAGS)				\
	$(LIBGITG_CFLAGS)			\
	-g					\
	-w

test_libgitg_LDADD = \
	$(top_builddir)/libgitg/libgitg-1.0.la	\
	$(LIBGITG_LIBS)

test_libgitg_SOURCES =				\
	test.vala				\
	main.vala				\
	repository.vala				\
	test-stage.vala				\
	test-date.vala				\
	test-commit.vala			\
	test-encoding.vala

GITIGNOREFILES =				\
	$(test_libgitg_SOURCES:%.vala=%.c)	\
	test_libgitg_vala.stamp

EXTRA_DIST = gitg-assert.h gitg-assert.vapi

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
