# Gitg

<a href="https://flathub.org/apps/details/org.gnome.gitg"><img height="51" alt="Download on Flathub" src="https://flathub.org/assets/badges/flathub-badge-en.svg"/> </a>

gitg is a graphical user interface for git. It aims at being a small, fast and convenient tool to visualize the history of git repositories.  Besides visualization, gitg also provides several utilities to manage your repository and commit your work.

The latest version of gitg is 3.32.1.

- Website:      https://wiki.gnome.org/Apps/Gitg
- Issues:       https://gitlab.gnome.org/GNOME/gitg/issues
- Download:     http://download.gnome.org/sources/gitg/
- Mailing list: http://mail.gnome.org/mailman/listinfo/gitg-list

## Installing gitg

To install the latest version of gitg, make sure to download gitg-3.32.1.tar.xz from the download site. After downloading the following procedure installs gitg:

```
$ tar Jxf gitg-3.32.1.tar.xz
$ cd gitg-3.32.1
$ meson --prefix=/usr build
$ ninja -C build
$ sudo ninja -C build install
```

## Building gitg from git

The gitg repository is hosted on git.gnome.org. To build from git:

```
$ git clone http://gitlab.gnome.org/GNOME/gitg.git
$ cd gitg
$ meson --prefix=/usr build
$ ninja -C build
$ sudo ninja -C install
```

Alternatively you can build using Flatpak with the org.gnome.gitgDevel.json manifest.

## Using gitg

When gitg is installed, you can run gitg from the GNOME menu, or from a terminal by issueing: 'gitg'. Type 'gitg --help' to show the options you can specify on the command line.
