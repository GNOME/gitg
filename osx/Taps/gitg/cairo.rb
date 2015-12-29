class Cairo < Formula
  desc "Vector graphics library with cross-device output support"
  homepage "http://cairographics.org/"
  url "http://cairographics.org/releases/cairo-1.14.4.tar.xz"
  mirror "https://www.mirrorservice.org/sites/ftp.netbsd.org/pub/pkgsrc/distfiles/cairo-1.14.4.tar.xz"
  sha256 "f6ec9c7c844db9ec011f0d66b57ef590c45adf55393d1fc249003512522ee716"
  revision 1
  head "git://anongit.freedesktop.org/cairo"

  keg_only :provided_pre_mountain_lion

  option :universal

  depends_on "pkg-config" => :build
  depends_on :x11 => :optional if MacOS.version > :leopard
  depends_on "freetype"
  depends_on "fontconfig"
  depends_on "libpng"
  depends_on "pixman"
  depends_on "glib"

  patch :DATA

  def install
    ENV.universal_binary if build.universal?

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --enable-gobject=yes
      --enable-svg=yes
      --enable-tee=yes
      --enable-quartz-image
    ]

    if build.with? "x11"
      args << "--enable-xcb=yes" << "--enable-xlib=yes" << "--enable-xlib-xrender=yes"
    else
      args << "--enable-xcb=no" << "--enable-xlib=no" << "--enable-xlib-xrender=no"
    end

    system "./configure", *args
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <cairo.h>

      int main(int argc, char *argv[]) {

        cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 600, 400);
        cairo_t *context = cairo_create(surface);

        return 0;
      }
    EOS
    fontconfig = Formula["fontconfig"]
    freetype = Formula["freetype"]
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    libpng = Formula["libpng"]
    pixman = Formula["pixman"]
    flags = (ENV.cflags || "").split + (ENV.cppflags || "").split + (ENV.ldflags || "").split
    flags += %W[
      -I#{fontconfig.opt_include}
      -I#{freetype.opt_include}/freetype2
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{include}/cairo
      -I#{libpng.opt_include}/libpng16
      -I#{pixman.opt_include}/pixman-1
      -L#{lib}
      -lcairo
    ]
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end
__END__
From 8c8b2b518d1a6067b7f203309bd4158de7cb78b9 Mon Sep 17 00:00:00 2001
From: Brion Vibber <brion@pobox.com>
Date: Sun, 16 Nov 2014 16:53:13 -0800
Subject: [PATCH] Provisional fix for cairo scaling on Quartz backend

CGContexts by default apply a device scaling factor, which ends up
interfering with the device_scale that is set on cairo at higher levels
of the stack (eg in GDK).

Undoing it here makes behavior more consistent with X11, as long as the
caller sets the device scale appropriately in cairo.

See:
* https://www.libreoffice.org/bugzilla/show_bug.cgi?id=69796
* https://bugzilla.gnome.org/show_bug.cgi?id=740199
---
 src/cairo-quartz-surface.c | 4 ++++
 1 file changed, 4 insertions(+)

diff --git a/src/cairo-quartz-surface.c b/src/cairo-quartz-surface.c
index 1116ff9..f763668 100644
--- a/src/cairo-quartz-surface.c
+++ b/src/cairo-quartz-surface.c
@@ -2266,6 +2266,10 @@ _cairo_quartz_surface_create_internal (CGContextRef cgContext,
 	return surface;
     }
 
+    /* Undo the default scaling transform, since we apply our own */
+    CGSize scale = CGContextConvertSizeToDeviceSpace (cgContext, CGSizeMake (1.0, 1.0));
+    CGContextScaleCTM(cgContext, 1.0 / scale.width, 1.0 / scale.height);
+
     /* Save so we can always get back to a known-good CGContext -- this is
      * required for proper behaviour of intersect_clip_path(NULL)
      */
-- 
1.9.3 (Apple Git-50)

