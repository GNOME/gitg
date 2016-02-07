noinst_LTLIBRARIES += contrib/ide/libide.la

contrib_ide_libide_la_CPPFLAGS = \
	-I$(top_srcdir)/contrib/xml

contrib_ide_libide_la_SOURCES = \
	contrib/ide/ide-doap.c \
	contrib/ide/ide-doap.h \
	contrib/ide/ide-doap-person.c \
	contrib/ide/ide-doap-person.h \
	contrib/ide/ide.h \
	$(NULL)

contrib_ide_libide_la_CFLAGS = \
	$(XML_CFLAGS) \
	$(NULL)

contrib_ide_libide_la_LIBADD = \
	$(XML_LIBS) \
	contrib/xml/libxml.la \
	$(NULL)

EXTRA_DIST += \
	contrib/ide/ide.vapi
