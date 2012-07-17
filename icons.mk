baseicondir = $(datadir)/gitg/icons/hicolor
svgicondir = $(baseicondir)/scalable/actions
svgicon_DATA = $(ICONS)

gtk_update_icon_cache = $(GTK_UPDATE_ICON_CACHE) -f -t $(baseicondir)

install-data-hook: update-icon-cache
uninstall-hook: update-icon-cache

update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		$(gtk_update_icon_cache); \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		echo "***   $(gtk_update_icon_cache)"; \
	fi

EXTRA_DIST = \
	$(svgicon_DATA)
