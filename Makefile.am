## Process this file with automake to produce Makefile.in

SUBDIRS = libgitg gitg data po tests tools

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libgitg-1.0.pc

DISTCLEANFILES = \
	intltool-extract \
	intltool-merge \
	intltool-update

EXTRA_DIST = \
	autogen.sh \
	MAINTAINERS \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in \
	libgitg-1.0.pc.in

MAINTAINERCLEANFILES = 		\
	aclocal.m4		\
	config.guess		\
	config.h.in		\
	config.sub		\
	depcomp			\
	ABOUT-NLS		\
	config.rpath		\
	install-sh		\
	ltmain.sh		\
	omf.make		\
	xmldocs.make		\
	missing			\
	mkinstalldirs		\
	m4/codeset.m4 		\
	m4/gettext.m4 		\
	m4/glibc21.m4 		\
	m4/glibc2.m4 		\
	m4/iconv.m4 		\
	m4/intdiv0.m4 		\
	m4/intldir.m4 		\
	m4/intl.m4 		\
	m4/intlmacosx.m4 	\
	m4/intltool.m4 		\
	m4/intmax.m4 		\
	m4/inttypes_h.m4 	\
	m4/inttypes-pri.m4 	\
	m4/lcmessage.m4 	\
	m4/lib-ld.m4 		\
	m4/lib-link.m4 		\
	m4/lib-prefix.m4 	\
	m4/libtool.m4 		\
	m4/lock.m4 		\
	m4/longlong.m4 		\
	m4/lt~obsolete.m4 	\
	m4/ltoptions.m4 	\
	m4/ltsugar.m4 		\
	m4/ltversion.m4 	\
	m4/nls.m4 		\
	m4/po.m4 		\
	m4/printf-posix.m4 	\
	m4/progtest.m4 		\
	m4/size_max.m4 		\
	m4/stdint_h.m4 		\
	m4/uintmax_t.m4 	\
	m4/visibility.m4 	\
	m4/wchar_t.m4 		\
	m4/wint_t.m4 		\
	m4/xsize.m4 		\
	po/missing		\
	`find "$(srcdir)" -type f -name Makefile.in -print`

dist-hook: generate-changelog

generate-changelog:
	if test -d $(top_srcdir)/.git; then \
	  sep=`nawk 'BEGIN{$$79=OFS="-";print}'`; \
	  git --git-dir=$(top_srcdir)/.git log --date=short --stat --decorate \
	  | sed -e "s/^\(commit [abcdef0-9]\{40\}\) (.*refs\/tags\/\(v\([0-9.]\+\)\).*)/$$sep\nVersion \3\n$$sep\n\n\1/g" -e 's/^\(commit [abcdef0-9]\{40\}\).*/\1/g' | ruby -e 'puts STDIN.read.gsub(/commit\s*(.*)\nAuthor:\s*(.*)\nDate:\s*(.*)\n/, "\\3 \\2\ncommit \\1\n")' > $(distdir)/c-l; \
	  mv $(distdir)/c-l $(distdir)/ChangeLog; \
	fi

.PHONY: generate-changelog

-include $(top_srcdir)/git.mk
