## Process this file with automake to produce Makefile.in

SUBDIRS = gitg data po

DISTCLEANFILES = \
	intltool-extract \
	intltool-merge \
	intltool-update

EXTRA_DIST = \
	autogen.sh \
	MAINTAINERS \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in

MAINTAINERCLEANFILES = 		\
	aclocal.m4		\
	config.guess		\
	config.h.in		\
	config.sub		\
	depcomp			\
	install-sh		\
	ltmain.sh		\
	missing			\
	mkinstalldirs		\
	m4/gnome-doc-utils.m4	\
	m4/gtk-doc.m4		\
	m4/intltool.m4		\
	m4/libtool.m4		\
	m4/ltoptions.m4		\
	m4/ltsugar.m4		\
	m4/ltversion.m4		\
	m4/lt~obsolete.m4	\
	`find "$(srcdir)" -type f -name Makefile.in -print`

bundle:
	rm -rf "$(bundledir)"; mkdir "$(bundledir)"; \
rm -rf gitg-$(PACKAGE_VERSION).zip; \
top_bundledir=`cd "$(bundledir)" && pwd`; \
for i in $(SUBDIRS); do (cd $$i && $(MAKE) top_bundledir="$$top_bundledir" $(AM_MAKEFLAGS) bundle); done; \
zip -r gitg-$(PACKAGE_VERSION).zip $(bundledir) >/dev/null;

dist-hook: generate-changelog

generate-changelog:
	if test -d $(top_srcdir)/.git; then \
	  sep=`nawk 'BEGIN{$$79=OFS="-";print}'`; \
	  git --git-dir=$(top_srcdir)/.git log --date=short --stat --decorate \
	  | sed -e "s/^\(commit [abcdef0-9]\{40\}\) (.*refs\/tags\/\(v\([0-9.]\+\)\).*)/$$sep\nVersion \3\n$$sep\n\n\1/g" -e 's/^\(commit [abcdef0-9]\{40\}\).*/\1/g' | ruby -e 'puts STDIN.read.gsub(/commit\s*(.*)\nAuthor:\s*(.*)\nDate:\s*(.*)\n/, "\\3 \\2\ncommit \\1\n")' > $(distdir)/c-l; \
	  mv $(distdir)/c-l $(distdir)/ChangeLog; \
	fi

.PHONY: bundle generate-changelog

-include $(top_srcdir)/git.mk
