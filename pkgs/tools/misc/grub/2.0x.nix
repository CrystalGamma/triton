{ stdenv, fetchurl, fetchFromSavannah, autogen, flex, bison, python, autoconf, automake
, gettext, ncurses, libusb_1, freetype, lvm2, zfs
, efiSupport ? false
}:

with stdenv.lib;
let
  pcSystems = {
    "i686-linux".target = "i386";
    "x86_64-linux".target = "i386";
  };

  efiSystems = {
    "i686-linux".target = "i386";
    "x86_64-linux".target = "x86_64";
  };

  canEfi = any (system: stdenv.system == system) (mapAttrsToList (name: _: name) efiSystems);
  inPCSystems = any (system: stdenv.system == system) (mapAttrsToList (name: _: name) pcSystems);

  version = "2.x-2015-01-22";

  unifont_bdf = fetchurl {
    url = "http://unifoundry.com/unifont-5.1.20080820.bdf.gz";
    sha256 = "0s0qfff6n6282q28nwwblp5x295zd6n71kl43xj40vgvdqxv0fxx";
  };

  po_src = fetchurl {
    name = "grub-2.02-beta2.tar.gz";
    url = "http://alpha.gnu.org/gnu/grub/grub-2.02~beta2.tar.gz";
    sha256 = "1lr9h3xcx0wwrnkxdnkfjwy08j7g7mdlmmbdip2db4zfgi69h0rm";
  };

in (

assert efiSupport -> canEfi;

stdenv.mkDerivation rec {
  name = "grub-${version}";

  src = fetchFromSavannah {
    repo = "grub";
    rev = "ff84a9b868ea36da23248da780b8e85bdc4c183d";
    sha256 = "1pbnyqha8my5h0bx3vfn4aqjdja8z32m4jp10dv9a1hx7mfnansk";
  };

  nativeBuildInputs = [ autogen flex bison python autoconf automake ];
  buildInputs = [ ncurses libusb_1 freetype gettext lvm2 zfs ];

  prePatch = ''
    tar zxf ${po_src} grub-2.02~beta2/po
    rm -rf po
    mv grub-2.02~beta2/po po
    sh autogen.sh
    gunzip < "${unifont_bdf}" > "unifont.bdf"
    sed -i "configure" \
      -e "s|/usr/src/unifont.bdf|$PWD/unifont.bdf|g"
  '';

  patches = [
    ./fix-bash-completion.patch
  ];

  configureFlags = [
    "--enable-libzfs"
  ] ++ optionals efiSupport [
    "--with-platform=efi"
    "--target=${efiSystems.${stdenv.targetSystem}.target}"
    "--program-prefix="
  ];

  # save target that grub is compiled for
  grubTarget =
    if efiSupport then
      "${efiSystems.${stdenv.targetSystem}.target}-efi"
    else if inPCSystems then
      "${pcSystems.${stdenv.targetSystem}.target}-pc"
    else 
      throw "Unsupported Target";

  # We don't need any security / optimization features for a bootloader
  optFlags = false;
  pie = false;
  fpic = false;
  noStrictOverflow = false;
  fortifySource = false;
  stackProtector = false;
  optimize = false;

  meta = with stdenv.lib; {
    description = "GNU GRUB, the Grand Unified Boot Loader (2.x beta)";
    homepage = http://www.gnu.org/software/grub/;
    license = licenses.gpl3Plus;
    platforms = with platforms;
      x86_64-linux;
  };
})
