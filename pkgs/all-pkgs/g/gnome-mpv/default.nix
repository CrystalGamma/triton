{ stdenv
, autoconf
, autoconf-archive
, automake
, fetchFromGitHub
, gettext
, intltool
, lib
, libtool
, makeWrapper
, pkgconfig

, adwaita-icon-theme
, appstream-glib
, dconf
, gdk-pixbuf
, glib
, gtk3
, libepoxy
, librsvg
, mpv
, python2Packages
, shared_mime_info
, wayland
, xorg
}:

let
  inherit (lib)
    boolEn;

  version = "2017-05-25";
in
stdenv.mkDerivation rec {
  name = "gnome-mpv-${version}";

  src = fetchFromGitHub {
    version = 2;
    owner = "gnome-mpv";
    repo = "gnome-mpv";
    rev = "a8e2ae2c9d4df01e6d93c24c8d5441fdf4e8b37f";
    sha256 = "b1166d1bbaf2a767b9013fca4206a0bf4d6543e50b27335b1bb236bd835b0a1e";
  };

  nativeBuildInputs = [
    autoconf
    autoconf-archive
    automake
    gettext
    intltool
    libtool
    makeWrapper
    pkgconfig
  ];

  buildInputs = [
    adwaita-icon-theme
    appstream-glib
    dconf
    gdk-pixbuf
    glib
    gtk3
    libepoxy
    librsvg
    mpv
    python2Packages.youtube-dl
    shared_mime_info
    wayland
    xorg.libX11
  ];

  preConfigure = /* Ignore autogen.sh and run the commands manually */ ''
    aclocal --install -I m4
    intltoolize --copy --automake
    autoreconf --install -Wno-portability
  '';

  configureFlags = [
    "--disable-maintainer-mode"
    "--enable-nls"
    "--enable-schemas-compile"
    "--disable-debug"
    "--enable-opencl-cb"
    "--${boolEn (appstream-glib != null)}-appstream-util"
  ];

  preFixup = ''
    wrapProgram $out/bin/gnome-mpv  \
      --set 'GDK_PIXBUF_MODULE_FILE' "$GDK_PIXBUF_MODULE_FILE" \
      --prefix 'GIO_EXTRA_MODULES' : "$GIO_EXTRA_MODULES" \
      --prefix 'XDG_DATA_DIRS' : "$GSETTINGS_SCHEMAS_PATH" \
      --prefix 'XDG_DATA_DIRS' : "$out/share" \
      --prefix 'XDG_DATA_DIRS' : "${shared_mime_info}/share" \
      --prefix 'XDG_DATA_DIRS' : "$XDG_ICON_DIRS"
  '';

  meta = with lib; {
    description = "A simple GTK+ frontend for mpv";
    homepage = https://github.com/gnome-mpv/gnome-mpv;
    license = licenses.gpl3;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
