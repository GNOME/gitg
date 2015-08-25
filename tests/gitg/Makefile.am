TESTS_GITG_PROGS = tests/gitg/test-gitg

TESTS += $(TESTS_GITG_PROGS)
noinst_PROGRAMS += $(TESTS_GITG_PROGS)

tests_gitg_test_gitg_CPPFLAGS = 		\
	-I$(top_srcdir) 			\
	-I$(top_srcdir)/gitg 			\
	-I$(top_srcdir)/libgitg			\
	-I$(top_srcdir)/tests/support

tests_gitg_test_gitg_VALAFLAGS =		\
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

tests_gitg_test_gitg_CFLAGS =			\
	$(GITG_DEBUG_FLAGS)			\
	$(GITG_CFLAGS)				\
	$(LIBGITG_CFLAGS)			\
	$(LIBGITG_EXT_CFLAGS)			\
	-g					\
	-w

tests_gitg_test_gitg_LDADD =			\
	libgitg/libgitg-1.0.la			\
	libgitg-ext/libgitg-ext-1.0.la		\
	$(LIBGITG_LIBS)

tests/gitg/support-%.vala: tests/support/%.vala
	cp "$<" "$@"

tests/gitg/gitg-%.vala: gitg/gitg-%.vala
	cp "$<" "$@"

TESTS_GITG_TEST_GITG_COPIED_SOURCES = 			\
	tests/gitg/support-test.vala			\
	tests/gitg/support-main.vala			\
	tests/gitg/support-repository.vala		\
	tests/gitg/gitg-ref-action-checkout.vala	\
	tests/gitg/gitg-ref-action-merge.vala		\
	tests/gitg/gitg-commit-action-cherry-pick.vala	\
	tests/gitg/gitg-action-support.vala

tests_gitg_test_gitg_SOURCES =				\
	tests/gitg/main.vala				\
	tests/gitg/test-checkout-ref.vala		\
	tests/gitg/test-merge-ref.vala			\
	tests/gitg/test-cherry-pick-commit.vala		\
	tests/gitg/simple-notification-mock.vala	\
	tests/gitg/application-mock.vala		\
	tests/gitg/notifications-mock.vala		\
	tests/gitg/ref-action-interface-mock.vala	\
	$(TESTS_GITG_TEST_GITG_COPIED_SOURCES)		\
	$(GITG_PLUGIN_VAPISOURCES)

CLEANFILES += $(TESTS_GITG_TEST_GITG_COPIED_SOURCES)

# vi:ts=8:noet
