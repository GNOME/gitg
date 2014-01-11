TESTS_LIBGITG_PROGS = tests/libgitg/test-libgitg

TESTS += $(TESTS_LIBGITG_PROGS)
noinst_PROGRAMS += $(TESTS_LIBGITG_PROGS)

tests_libgitg_test_libgitg_CPPFLAGS = 		\
	-I$(top_srcdir) 			\
	-I$(top_srcdir)/gitg 			\
	-I$(top_srcdir)/libgitg			\
	-I$(top_srcdir)/tests/libgitg

tests_libgitg_test_libgitg_VALAFLAGS =		\
	--pkg posix				\
	--pkg gitg-assert			\
	--pkg Ggit-1.0				\
	--pkg gio-2.0				\
	--pkg gtk+-3.0				\
	--pkg gee-0.8				\
	--pkg libsoup-2.4			\
	--pkg webkit2gtk-3.0			\
	--pkg config				\
	$(GITG_VALAFLAGS)			\
	--vapidir $(top_srcdir)/tests/libgitg	\
	--vapidir $(top_srcdir)/vapi		\
	--disable-warnings

tests_libgitg_test_libgitg_CFLAGS =		\
	$(GITG_DEBUG_FLAGS)			\
	$(GITG_CFLAGS)				\
	$(LIBGITG_CFLAGS)			\
	-g					\
	-w

tests_libgitg_test_libgitg_LDFLAGS =		\
	$(LIBGITG_LIBS)

tests_libgitg_test_libgitg_LDADD =		\
	libgitg/libgitg-1.0.la

tests_libgitg_test_libgitg_SOURCES =		\
	tests/libgitg/test.vala			\
	tests/libgitg/main.vala			\
	tests/libgitg/repository.vala		\
	tests/libgitg/test-stage.vala		\
	tests/libgitg/test-date.vala		\
	tests/libgitg/test-commit.vala		\
	tests/libgitg/test-encoding.vala	\
	$(GITG_PLUGIN_VAPISOURCES)

EXTRA_DIST +=					\
	tests/libgitg/gitg-assert.h		\
	tests/libgitg/gitg-assert.vapi

# vi:ts=8:noet
