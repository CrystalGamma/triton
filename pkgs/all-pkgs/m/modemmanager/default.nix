{ stdenv
, fetchurl
, lib

, glib
, systemd_lib
, libgudev
, polkit
, dbus-glib
, ppp
, intltool
, pkgconfig
, libmbim
, libqmi
}:

stdenv.mkDerivation rec {
  name = "ModemManager-1.6.12";

  src = fetchurl {
    url = "https://www.freedesktop.org/software/ModemManager/${name}.tar.xz";
    multihash = "QmbHzykrvSjNAiWdU5GVvEgrWremTYSLcMHAJr8NJMfGjq";
    sha256 = "eefb7615c2c7ebc994abfc2782bfa9e798643a633362b40db96f7f61706a6283";
  };

  nativeBuildInputs = [
    intltool
  ];

  buildInputs = [
    glib
    systemd_lib
    libgudev
    polkit
    dbus-glib
    ppp
    libmbim
    libqmi
  ];

  configureFlags = [
    "--with-polkit"
    "--with-udev-base-dir=$(out)/lib/udev"
    "--with-systemdsystemunitdir=$(out)/etc/systemd/system"
    "--sysconfdir=/etc"
    "--localstatedir=/var"
  ];

  preInstall = ''
    mkdir -pv $out/etc/systemd/system
  '';

  installFlags = [
    "DESTDIR=\${out}"
  ];

  postInstall = ''
    mv -v \
      $out/$out/etc/systemd/system/ModemManager.service \
      $out/etc/systemd/system
    rm -rvf $out/$out/etc
    mv -v $out/$out/* $out
    DIR=$out/$out
    while rmdir $DIR 2>/dev/null ; do
      DIR="$(dirname "$DIR")"
    done

    # systemd in NixOS doesn't use `systemctl enable`, so we need to establish
    # aliases ourselves.
    ln -sv \
      $out/etc/systemd/system/ModemManager.service \
      $out/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service
  '';

  meta = with lib; {
    description = "WWAN modem manager, part of NetworkManager";
    homepage = https://www.freedesktop.org/wiki/Software/ModemManager/;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
