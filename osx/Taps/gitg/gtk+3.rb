class Gtkx3 < Formula
  desc "Toolkit for creating graphical user interfaces"
  homepage "http://gtk.org/"
  url "https://download.gnome.org/sources/gtk+/3.18/gtk+-3.18.2.tar.xz"
  sha256 "5dbec561c4a00070073bf9cf4cfdd61fab4a14c8ff5b15d700bd378f8185e152"

  option :universal
  option "with-quartz-relocation", "Build with quartz relocation support"

  depends_on "pkg-config" => :build
  depends_on "gnome/gitg/gdk-pixbuf"
  depends_on "jasper" => :optional
  depends_on "gnome/gitg/atk"
  depends_on "gnome/gitg/gobject-introspection"
  depends_on "libepoxy"
  depends_on "gnome/gitg/gsettings-desktop-schemas" => :recommended
  depends_on "gnome/gitg/pango"
  depends_on "glib"
  depends_on "hicolor-icon-theme"

  patch :DATA

  def install
    ENV.universal_binary if build.universal?

    args = %W[
      --enable-debug
      --disable-dependency-tracking
      --prefix=#{prefix}
      --disable-glibtest
      --enable-introspection=yes
      --disable-schemas-compile
      --enable-quartz-backend
      --disable-x11-backend
    ]

    args << "--enable-quartz-relocation" if build.with?("quartz-relocation")

    system "./configure", *args
    # necessary to avoid gtk-update-icon-cache not being found during make install
    bin.mkpath
    ENV.prepend_path "PATH", "#{bin}"

    system "make", "install"
    # Prevent a conflict between this and Gtk+2
    mv bin/"gtk-update-icon-cache", bin/"gtk3-update-icon-cache"
  end

  def post_install
    system "#{Formula["glib"].opt_bin}/glib-compile-schemas", "#{HOMEBREW_PREFIX}/share/glib-2.0/schemas"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <gtk/gtk.h>

      int main(int argc, char *argv[]) {
        gtk_disable_setlocale();
        return 0;
      }
    EOS
    atk = Formula["atk"]
    cairo = Formula["cairo"]
    fontconfig = Formula["fontconfig"]
    freetype = Formula["freetype"]
    gdk_pixbuf = Formula["gdk-pixbuf"]
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    libepoxy = Formula["libepoxy"]
    libpng = Formula["libpng"]
    pango = Formula["pango"]
    pixman = Formula["pixman"]
    flags = (ENV.cflags || "").split + (ENV.cppflags || "").split + (ENV.ldflags || "").split
    flags += %W[
      -I#{atk.opt_include}/atk-1.0
      -I#{cairo.opt_include}/cairo
      -I#{fontconfig.opt_include}
      -I#{freetype.opt_include}/freetype2
      -I#{gdk_pixbuf.opt_include}/gdk-pixbuf-2.0
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/gio-unix-2.0/
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{include}
      -I#{include}/gtk-3.0
      -I#{libepoxy.opt_include}
      -I#{libpng.opt_include}/libpng16
      -I#{pango.opt_include}/pango-1.0
      -I#{pixman.opt_include}/pixman-1
      -D_REENTRANT
      -L#{atk.opt_lib}
      -L#{cairo.opt_lib}
      -L#{gdk_pixbuf.opt_lib}
      -L#{gettext.opt_lib}
      -L#{glib.opt_lib}
      -L#{lib}
      -L#{pango.opt_lib}
      -latk-1.0
      -lcairo
      -lcairo-gobject
      -lgdk-3
      -lgdk_pixbuf-2.0
      -lgio-2.0
      -lglib-2.0
      -lgobject-2.0
      -lgtk-3
      -lintl
      -lpango-1.0
      -lpangocairo-1.0
    ]
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end
__END__
From 2544b9256318b5f921e6eebb5925bdc8b3419125 Mon Sep 17 00:00:00 2001
From: Brion Vibber <brion@pobox.com>
Date: Sun, 16 Nov 2014 15:10:30 -0800
Subject: [PATCH 3/3] Work in progress fix for low-res GL views on Quartz
 HiDPI/Retina

gdk_quartz_ref_cairo_surface () wasn't respecting the window's scale
when creating a surface, whereas the equivalent on other backends was.

This patch fixes GL views, but breaks non-GL ones on Retina display
by making them double-sized. Not sure where the doubling on that code
path is yet...
---
 gdk/quartz/gdkwindow-quartz.c | 9 +++++++--
 1 file changed, 7 insertions(+), 2 deletions(-)

diff --git a/gdk/quartz/gdkwindow-quartz.c b/gdk/quartz/gdkwindow-quartz.c
index 1d39e8f..04539d3 100644
--- a/gdk/quartz/gdkwindow-quartz.c
+++ b/gdk/quartz/gdkwindow-quartz.c
@@ -320,10 +320,15 @@ gdk_quartz_ref_cairo_surface (GdkWindow *window)
 
   if (!impl->cairo_surface)
     {
+      int scale = gdk_window_get_scale_factor (impl->wrapper);
+      if (scale == 0)
+        scale = 1;
+
       impl->cairo_surface = 
           gdk_quartz_create_cairo_surface (impl,
-                                           gdk_window_get_width (impl->wrapper),
-                                           gdk_window_get_height (impl->wrapper));
+                                           gdk_window_get_width (impl->wrapper) * scale,
+                                           gdk_window_get_height (impl->wrapper) * scale);
+      cairo_surface_set_device_scale (impl->cairo_surface, scale, scale);
     }
   else
     cairo_surface_reference (impl->cairo_surface);
-- 
1.9.3 (Apple Git-50)
From 571704824f78de9d8b262793397a4e4ea6cedf7d Mon Sep 17 00:00:00 2001
From: John Ralls <jralls@ceridwen.us>
Date: Fri, 18 Sep 2015 15:12:24 -0700
Subject: [PATCH] Bug 753992 - im-quartz discard_preedit segmentation fault

Replace checking if the NSView is really a GdkWindow, which will crash
in the likely event it's not a GObject, with ensuring that the parent
GdkWindow is really a GdkWindowQuartz.
---
 modules/input/imquartz.c | 19 +++++++------------
 1 file changed, 7 insertions(+), 12 deletions(-)

diff --git a/modules/input/imquartz.c b/modules/input/imquartz.c
index 5db6481..508ecf8 100644
--- a/modules/input/imquartz.c
+++ b/modules/input/imquartz.c
@@ -186,15 +186,11 @@ quartz_filter_keypress (GtkIMContext *context,
 
   GTK_NOTE (MISC, g_print ("quartz_filter_keypress\n"));
 
-  if (!qc->client_window)
+  if (!GDK_IS_QUARTZ_WINDOW (qc->client_window))
     return FALSE;
 
   nsview = gdk_quartz_window_get_nsview (qc->client_window);
-  if (GDK_IS_WINDOW (nsview))
-       /* it gets GDK_WINDOW in some cases */
-    return gtk_im_context_filter_keypress (qc->slave, event);
-  else
-    win = (GdkWindow *)[ (GdkQuartzView *)nsview gdkWindow];
+  win = (GdkWindow *)[ (GdkQuartzView *)nsview gdkWindow];
   GTK_NOTE (MISC, g_print ("client_window: %p, win: %p, nsview: %p\n",
 			   qc->client_window, win, nsview));
 
@@ -242,11 +238,11 @@ discard_preedit (GtkIMContext *context)
   if (!qc->client_window)
     return;
 
-  NSView *nsview = gdk_quartz_window_get_nsview (qc->client_window);
-  if (!nsview)
+  if (!GDK_IS_QUARTZ_WINDOW (qc->client_window))
     return;
 
-  if (GDK_IS_WINDOW (nsview))
+  NSView *nsview = gdk_quartz_window_get_nsview (qc->client_window);
+  if (!nsview)
     return;
 
   /* reset any partial input for this NSView */
@@ -328,11 +324,10 @@ quartz_set_cursor_location (GtkIMContext *context, GdkRectangle *area)
   qc->cursor_rect->x = area->x + x;
   qc->cursor_rect->y = area->y + y;
 
-  nsview = gdk_quartz_window_get_nsview (qc->client_window);
-  if (GDK_IS_WINDOW (nsview))
-    /* it returns GDK_WINDOW in some cases */
+  if (!GDK_IS_QUARTZ_WINDOW (qc->client_window))
     return;
 
+  nsview = gdk_quartz_window_get_nsview (qc->client_window);
   win = (GdkWindow *)[ (GdkQuartzView*)nsview gdkWindow];
   g_object_set_data (G_OBJECT (win), GIC_CURSOR_RECT, qc->cursor_rect);
 }
-- 
2.4.9 (Apple Git-60)

