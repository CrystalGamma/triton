{ stdenv
, fetchurl
, intltool
, makeWrapper

, adwaita-icon-theme
, avahi
, dbus-glib
, dconf
, file
, glib
, gnutls
, gtk3
, libgcrypt
, libjpeg
, libnotify
, libsecret
, libsoup
, telepathy_glib
, xorg
, zlib
}:

let
  inherit (stdenv.lib)
    optionals
    wtFlag;
in

assert xorg != null ->
  xorg.libSM != null
  && xorg.libX11 != null;

stdenv.mkDerivation rec {
  name = "vino-${version}";
  versionMajor = "3.20";
  versionMinor = "1";
  version = "${versionMajor}.${versionMinor}";

  src = fetchurl {
    url = "mirror://gnome/sources/vino/${versionMajor}/${name}.tar.xz";
    sha256Url = "mirror://gnome/sources/vino/${versionMajor}/${name}.sha256sum";
    sha256 = "d7f4a6d58ae864904487ce6b8f298a6f51268e9148be377e64134aa542b15fc7";
  };

  nativeBuildInputs = [
    intltool
    makeWrapper
  ];

  buildInputs = [
    adwaita-icon-theme
    avahi
    dbus-glib
    dconf
    file
    glib
    gnutls
    gtk3
    libgcrypt
    libjpeg
    libnotify
    libsecret
    libsoup
    telepathy_glib
    zlib
  ] ++ optionals (xorg != null) [
    xorg.libSM
    xorg.libX11
  ];

  configureFlags = [
    "--disable-maintainer-mode"
    "--enable-compile-warnings"
    "--disable-iso-c"
    "--disable-debug"
    "--enable-nls"
    "--enable-ipv6"
    "--enable-schemas-compile"
    (wtFlag "telepathy" (telepathy_glib != null) null)
    (wtFlag "secret" (libsecret != null) null)
    (wtFlag "x" (xorg != null) null)
    (wtFlag "gnutls" (gnutls != null) null)
    (wtFlag "gcrypt" (libgcrypt != null) null)
    (wtFlag "avahi" (avahi != null) null)
    (wtFlag "zlib" (zlib != null) null)
    (wtFlag "jpeg" (libjpeg != null) null)
  ];

  preFixup = ''
    wrapProgram $out/libexec/vino-server \
      --set 'GSETTINGS_BACKEND' 'dconf' \
      --prefix 'GIO_EXTRA_MODULES' : "$GIO_EXTRA_MODULES" \
      --prefix 'XDG_DATA_DIRS' : "$GSETTINGS_SCHEMAS_PATH" \
      --prefix 'XDG_DATA_DIRS' : "$out/share" \
      --prefix 'XDG_DATA_DIRS' : "$XDG_ICON_DIRS"
  '';

  doCheck = true;

  meta = with stdenv.lib; {
    description = "GNOME desktop sharing server";
    homepage = https://wiki.gnome.org/action/show/Projects/Vino;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
