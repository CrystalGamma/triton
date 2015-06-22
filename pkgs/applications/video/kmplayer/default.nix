{ stdenv, fetchurl, cmake, pkgconfig, gettext, makeWrapper
, kdelibs, cairo, dbus_glib, mplayer
}:

stdenv.mkDerivation rec {
  name = "kmplayer-0.11.3d";

  src = fetchurl {
    url = "mirror://gentoo/${name}.tar.bz2";
    sha256 = "1yvbkb1hh5y7fqfvixjf2rryzm0fm0fpkx4lmvhi7k7d0v4wpgky";
  };

  buildInputs = [
    cmake gettext pkgconfig makeWrapper
    kdelibs cairo dbus_glib
  ];

  postInstall = ''
    wrapProgram $out/bin/kmplayer --suffix PATH : ${mplayer}/bin
  '';

  meta = {
    description = "MPlayer front-end for KDE";
    license = "GPL";
    homepage = http://kmplayer.kde.org;
    maintainers = [ stdenv.lib.maintainers.sander ];
  };
}
