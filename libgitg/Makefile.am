lib_LTLIBRARIES = libgitg-1.0.la

INCLUDES =								\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	$(LIBGITG_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

libgitg_1_0_la_LDFLAGS = 		\
	-export-dynamic -no-undefined -export-symbols-regex "^[^_].*"

libgitg_1_0_la_LIBADD = $(LIBGITG_LIBS)

INST_H_FILES =				\
	libgitg.h

AM_VALAFLAGS = 				\
	--pkg Ggit-1.0 			\
	--pkg gio-2.0			\
	$(GITG_VALAFLAGS)		\
	--header libgitg.h		\
	--includedir libgitg		\
	--basedir $(top_srcdir)		\
	--gir Gitg-1.0.gir		\
	--library libgitg-1.0

Gitg-1.0.gir: libgitg-1.0.la
libgitg.h: libgitg-1.0.la

VALA_FILES =				\
	gitg-assembly-info.vala		\
	gitg-branch.vala		\
	gitg-branch-base.vala		\
	gitg-repository.vala		\
	gitg-ref.vala			\
	gitg-ref-base.vala		\
	gitg-lane.vala			\
	gitg-lanes.vala			\
	gitg-color.vala			\
	gitg-init.vala			\
	gitg-commit.vala

# Ignore all warnings for vala code...
libgitg_1_0_la_CFLAGS =		\
	-w

libgitg_1_0_la_SOURCES = 		\
	$(VALA_FILES)

headerdir = $(prefix)/include/libgitg-1.0/libgitg
header_DATA = $(INST_H_FILES)

vapidir = $(prefix)/share/vala/vapi
vapi_DATA = libgitg-1.0.vapi

girdir = $(INTROSPECTION_GIRDIR)
gir_DATA = Gitg-1.0.gir

typelibdir = $(INTROSPECTION_TYPELIBDIR)
typelib_DATA = Gitg-1.0.typelib

%.typelib: %.gir
	$(INTROSPECTION_COMPILER) $(INTROSPECTION_COMPILER_ARGS) --includedir=. -o $@ $<

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libgitg-1.0.pc

BUILT_SOURCES =				\
	$(gir_DATA)			\
	$(vapi_DATA)			\
	$(typelib_DATA)			\
	libgitg_1_0_la_vala.stamp	\
	libgitg.h

EXTRA_DIST = $(pkgconfig_DATA)
CLEANFILES = $(VALA_FILES:.vala=.c)

dist-hook:
	cd $(distdir); rm -f $(BUILT_SOURCES)

-include $(top_srcdir)/git.mk
