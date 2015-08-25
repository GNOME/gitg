TESTS_LIBGITG_PROGS = tests/libgitg/test-libgitg

TESTS += $(TESTS_LIBGITG_PROGS)
noinst_PROGRAMS += $(TESTS_LIBGITG_PROGS)

tests_libgitg_test_libgitg_CPPFLAGS = 		\
	-I$(top_srcdir) 			\
	-I$(top_srcdir)/gitg 			\
	-I$(top_srcdir)/libgitg			\
	-I$(top_srcdir)/tests/support

tests_libgitg_test_libgitg_VALAFLAGS =		\
	--pkg posix				\
	--pkg gitg-assert			\
	--pkg Ggit-1.0				\
	--pkg gio-2.0				\
	--pkg gtk+-3.0				\
	--pkg gee-0.8				\
	--pkg libsoup-2.4			\
	--pkg config				\
	$(GITG_VALAFLAGS)			\
	--vapidir $(top_srcdir)/tests/support	\
	--vapidir $(top_srcdir)/vapi		\
	--disable-warnings

tests_libgitg_test_libgitg_CFLAGS =		\
	$(GITG_DEBUG_FLAGS)			\
	$(GITG_CFLAGS)				\
	$(LIBGITG_CFLAGS)			\
	-g					\
	-w

tests_libgitg_test_libgitg_LDADD =		\
	libgitg/libgitg-1.0.la			\
	$(LIBGITG_LIBS)

tests/libgitg/support-%.vala: tests/support/%.vala
	cp "$<" "$@"

TESTS_GITG_TEST_LIBGITG_COPIED_SOURCES = 		\
	tests/libgitg/support-test.vala			\
	tests/libgitg/support-main.vala			\
	tests/libgitg/support-repository.vala

tests_libgitg_test_libgitg_SOURCES =			\
	tests/libgitg/main.vala				\
	tests/libgitg/test-stage.vala			\
	tests/libgitg/test-date.vala			\
	tests/libgitg/test-commit.vala			\
	tests/libgitg/test-encoding.vala		\
	$(TESTS_GITG_TEST_LIBGITG_COPIED_SOURCES)	\
	$(GITG_PLUGIN_VAPISOURCES)

CLEANFILES += 							\
	$(TESTS_GITG_TEST_LIBGITG_COPIED_SOURCES)		\
	$(TESTS_GITG_TEST_LIBGITG_COPIED_SOURCES:%.vala=%.c)

# vi:ts=8:noet
