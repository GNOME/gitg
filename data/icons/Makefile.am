public_icons_themes = \
	hicolor	\
	HighContrastLargePrint \
	HighContrastLargePrintInverse \
	LowContrastLargePrint

public_icons = \
	hicolor_apps_16x16_gitg.png \
	hicolor_apps_22x22_gitg.png \
	hicolor_apps_24x24_gitg.png \
	hicolor_apps_32x32_gitg.png \
	hicolor_apps_48x48_gitg.png \
	hicolor_apps_scalable_gitg.svg

private_icons = \
	gitg16x16.png	\
	gitg22x22.png	\
	gitg24x24.png	\
	gitg32x32.png	\
	gitg48x48.png	\
	gitg64x64.png	\
	gitg128x128.png \
	gitg.svg

gtk_update_icon_cache = gtk-update-icon-cache -f -t

update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		for theme in $(public_icons_themes); do \
			$(gtk_update_icon_cache) $(datadir)/icons/$$theme; \
		done; \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		for theme in $(public_icons_themes); do \
			echo "***   $(gtk_update_icon_cache) $(datadir)/icons/$$theme"; \
		done; \
	fi

install-icons:
	for icon in $(public_icons); do \
		THEME=`echo $$icon | cut -d_ -f1`; \
		CONTEXT=`echo $$icon | cut -d_ -f2`; \
		SIZE=`echo $$icon | cut -d_ -f3`; \
		ICONFILE=`echo $$icon | cut -d_ -f4`; \
		mkdir -p $(DESTDIR)$(datadir)/icons/$$THEME/$$SIZE/$$CONTEXT; \
		$(INSTALL_DATA) $(srcdir)/$$icon $(DESTDIR)$(datadir)/icons/$$THEME/$$SIZE/$$CONTEXT/$$ICONFILE; \
	done;

uninstall-icons:
	-for icon in $(public_icons); do \
		THEME=`echo $$icon | cut -d_ -f1`; \
		CONTEXT=`echo $$icon | cut -d_ -f2`; \
		SIZE=`echo $$icon | cut -d_ -f3`; \
		ICONFILE=`echo $$icon | cut -d_ -f4`; \
		rm -f $(DESTDIR)$(datadir)/icons/$$THEME/$$SIZE/$$CONTEXT/$$ICONFILE; \
	done;

install-data-local: install-icons update-icon-cache

uninstall-local: uninstall-icons update-icon-cache

EXTRA_DIST = 				\
	$(public_icons) \
	$(private_icons)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
