class GobjectIntrospection < Formula
  desc "Generate interface introspection data for GObject libraries"
  homepage "https://live.gnome.org/GObjectIntrospection"
  url "https://download.gnome.org/sources/gobject-introspection/1.46/gobject-introspection-1.46.0.tar.xz"
  sha256 "6658bd3c2b8813eb3e2511ee153238d09ace9d309e4574af27443d87423e4233"

  option :universal

  depends_on "pkg-config" => :run
  depends_on "glib"
  depends_on "libffi"

  resource "tutorial" do
    url "https://gist.github.com/7a0023656ccfe309337a.git",
        :revision => "499ac89f8a9ad17d250e907f74912159ea216416"
  end

  def install
    ENV["GI_SCANNER_DISABLE_CACHE"] = "true"
    ENV.universal_binary if build.universal?

    inreplace "giscanner/transformer.py", "/usr/share", "#{HOMEBREW_PREFIX}/share"

    inreplace "configure" do |s|
      s.change_make_var! "GOBJECT_INTROSPECTION_LIBDIR", "#{HOMEBREW_PREFIX}/lib"
    end

    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"

    inreplace "config.h",
      "#define GIR_DIR \"#{share}/gir-1.0\"",
      "#define GIR_DIR \"#{HOMEBREW_PREFIX}/share/gir-1.0\""

    system "make"
    system "make", "install"
  end

  test do
    ENV.prepend_path "PKG_CONFIG_PATH", Formula["libffi"].opt_lib/"pkgconfig"
    resource("tutorial").stage testpath
    system "make"
    assert (testpath/"Tut-0.1.typelib").exist?
  end
end
