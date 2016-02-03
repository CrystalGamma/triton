{ stdenv
, fetchurl
, gettext
, intltool
, itstool

, adwaita-icon-theme
, bash
, bzip2
, c-ares
, evolution
, evolution-data-server
, exempi
, file
, ffmpeg
, flac
, gdk-pixbuf
, giflib
, glib
, gnome-themes-standard
, gobject-introspection
, gsettings-desktop-schemas
, gst-libav
, gst-plugins-base
, gstreamer
, gtk3
, icu
, libcue
, libexif
, libgee
, libgsf
, libgxps
, libjpeg
, libmediaart
, libnotify
, libosinfo
, libpng
, librsvg
, libtiff
, libuuid
, libvorbis
, libxml2
, libxslt
, networkmanager
, poppler
, sqlite
, taglib
, totem-pl-parser
, upower
, vala
, zlib
}:

with {
  inherit (stdenv.lib)
    enFlag;
};

stdenv.mkDerivation rec {
  name = "tracker-${version}";
  versionMajor = "1.6";
  versionMinor = "1";
  version = "${versionMajor}.${versionMinor}";

  src = fetchurl {
    url = "mirror://gnome/sources/tracker/${versionMajor}/${name}.tar.xz";
    sha256 = "1vf1y2jn17yz70gfm5xsprydga67848izv3bymnq6js59wzxfgk5";
  };

  propagatedUserEnvPkgs = [
    gnome-themes-standard
  ];

  nativeBuildInputs = [
    gettext
    intltool
    itstool
    libxslt
  ];

  buildInputs = [
    adwaita-icon-theme
    bzip2
    c-ares
    #cairo
    #enca
    evolution
    evolution-data-server
    exempi
    file
    #firefox
    ffmpeg
    flac
    gdk-pixbuf
    giflib
    glib
    gobject-introspection
    gsettings-desktop-schemas
    libgee
    totem-pl-parser
    gst-libav
    gst-plugins-base
    gstreamer
    #gtk2
    gtk3
    #gupnp-dlna
    icu
    #libcue
    libexif
    #libgrss
    libgsf
    libgxps
    #libiptcdata
    libjpeg
    libmediaart
    libnotify
    libosinfo
    libpng
    librsvg
    libtiff
    libuuid
    libvorbis
    libxml2
    networkmanager
    #pango
    poppler
    sqlite
    taglib
    #thunderbird
    upower
    #utillinux
    vala
    zlib
  ];

  preConfigure = ''
    substituteInPlace src/libtracker-sparql/Makefile.in \
      --replace \
        "--shared-library=libtracker-sparql" \
        "--shared-library=$out/lib/libtracker-sparql"
  '';

  configureFlags = [
    "--enable-schemas-compile"
    "--disable-installed-tests"
    "--disable-always-build-tests"
    (enFlag "introspection" (gobject-introspection != null) null)
    "--enable-nls"
    "--disable-gcov"
    "--disable-minimal"
    "--disable-functional-tests"
    "--disable-gtk-doc"
    "--disable-gtk-doc-html"
    "--disable-gtk-doc-pdf"
    "--enable-maemo"
    "--enable-journal"
    "--enable-libstreamer"
    "--enable-tracker-fts"
    "--disable-unit-tests"
    (enFlag "upower" (upower != null) null)
    "--disable-hal"
    (enFlag "network-manager" (networkmanager != null) null)
    (enFlag "libmediaart" (libmediaart != null) null)
    (enFlag "libexif" (libexif != null) null)
    # TODO: libiptcdata support
    "--disable-libiptcdata"
    (enFlag "exempi" (exempi != null) null)
    "--enable-meegotouch"
    "--disable-miner-fs"
    "--enable-extract"
    "--enable-tracker-writeback"
    "--enable-miner-apps"
    "--enable-user-guides"
    # TODO: miner-rss support
    "--disable-miner-rss"
    # TODO: evolution plugin support
    "--disable-miner-evolution"
    # TODO: thunderbird support
    "--disable-miner-thunderbird"
    # TODO: firefox support
    "--disable-miner-firefox"
    # TODO: nautilus support
    "--disable-nautilus-extension"
    (enFlag "taglib" (taglib != null) null)
    "--enable-tracker-needle"
    "--enable-tracker-preferences"
    "--disable-enca"
    "--enable-icu-charset-detection"
    (enFlag "libxml2" (libxml2 != null) null)
    "--enable-cfg-man-pages"
    "--enable-unzip-ps-gz-files"
    (enFlag "poppler" (poppler != null) null)
    (enFlag "libgxps" (libgxps != null) null)
    (enFlag "libgsf" (libgsf != null) null)
    (enFlag "libosinfo" (libosinfo != null) null)
    (enFlag "libgif" (giflib != null) null)
    (enFlag "libjpeg" (libjpeg != null) null)
    (enFlag "libtiff" (libtiff != null) null)
    (enFlag "libpng" (libpng != null) null)
    (enFlag "libvorbis" (libvorbis != null) null)
    (enFlag "libflac" (flac != null) null)
    # TODO: libcue support
    "--disable-libcue"
    "--enable-abiword"
    "--enable-dvi"
    "--enable-mp3"
    "--enable-ps"
    "--enable-text"
    "--enable-icon"
    "--enable-playlist"
    "--enable-guarantee-metadata"
    "--enable-artwork"
    "--with-compile-warnings"
    #"--with-bash-completion-dir="
    #"--with-session-bus-services-dir"
    #"--with-unicode-support"
    #"--with-evolution-plugin-dir"
    #"--with-thunderbird-plugin-dir"
    #"--with-firefox-plugin-dir"
    #"--with-nautilus-extensions-dir"
    # TODO: gstreamer support
    "--with-gstreamer-backend=discoverer"
    #"--with-gstreamer-backend=gupnp-dlna"
  ];

  NIX_CFLAGS_COMPILE = [
    "-I${glib}/include/gio-unix-2.0"
    "-I${poppler}/include/poppler"
  ];

  meta = with stdenv.lib; {
    description = "User information store, search tool and indexer";
    homepage = https://wiki.gnome.org/Projects/Tracker;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = [
      "i686-linux"
      "x86_64-linux"
    ];
  };
}
