{ stdenv, fetchurl, automake, autoconf, libtool, libzen, zlib, curl, libmms }:

stdenv.mkDerivation rec {
  version = "0.7.87";
  name = "libmediainfo-${version}";

  src = fetchurl {
    url = "https://mediaarea.net/download/source/libmediainfo/${version}/libmediainfo_${version}.tar.xz";
    sha256 = "4923dc108cf0e9fd6df36fc97e52a0955b69188491099331bb30d70410db72bf";
  };

  nativeBuildInputs = [ automake autoconf libtool ];
  buildInputs = [ libzen zlib curl libmms ];

  sourceRoot = "./MediaInfoLib/Project/GNU/Library/";

  preConfigure = ''
    sh autogen.sh
    cat configure.ac
  '';

  configureFlags = [
    "--enable-shared"
    "--with-libcurl"
    "--with-libmms"
  ];

  postInstall = ''
    install -vD -m 644 libmediainfo.pc "$out/lib/pkgconfig/libmediainfo.pc"
  '';

  meta = {
    description = "Shared library for mediainfo";
    homepage = http://mediaarea.net/;
    license = stdenv.lib.licenses.bsd2;
    platforms = stdenv.lib.platforms.all;
    maintainers = [ stdenv.lib.maintainers.devhell ];
  };
}
