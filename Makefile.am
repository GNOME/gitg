## Process this file with automake to produce Makefile.in

SUBDIRS = gitg data po

DISTCLEANFILES = \
	intltool-extract \
	intltool-merge \
	intltool-update

EXTRA_DIST = \
	autogen.sh \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in

bundle:
	rm -rf "$(bundledir)"; mkdir "$(bundledir)"; \
rm -rf gitg-$(PACKAGE_VERSION).zip; \
top_bundledir=`cd "$(bundledir)" && pwd`; \
for i in $(SUBDIRS); do (cd $$i && $(MAKE) top_bundledir="$$top_bundledir" $(AM_MAKEFLAGS) bundle); done; \
zip -r gitg-$(PACKAGE_VERSION).zip $(bundledir) >/dev/null;

dist-hook: generate-changelog

generate-changelog:
	if test -d $(top_srcdir)/.git; then \
	  git --git-dir=$(top_srcdir)/.git log --date=short \
	  --stat --pretty=format:'%x01%ad  %an <%ae>%n%x01%H%n%n%s%n%n%b' \
	  | sed -e 's/^/\t/g' -e 's/^\t\x01//g' > $(distdir)/c-l; \
	  mv $(distdir)/c-l $(distdir)/ChangeLog; \
	fi

.PHONY: bundle generate-changelog
