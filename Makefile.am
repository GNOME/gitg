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

.PHONY: bundle
