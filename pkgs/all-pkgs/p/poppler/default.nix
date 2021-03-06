{ stdenv
, cmake
, fetchTritonPatch
, fetchurl
, lib
, ninja

, curl
, cairo
, freetype
, fontconfig
, glib
, gobject-introspection
, libtiff
, lcms2
, libjpeg
, libpng
, nspr
, nss
, openjpeg
, qt5
, zlib

, utils ? false
, suffix ? "glib"
}:

# FIXME: gobject-introspection and openjpeg support is not working currently

assert (
  suffix == "glib" ||
  suffix == "qt5" ||
  suffix == "utils"
);

let
  inherit (lib)
    boolOn
    boolString;

  version = "0.74.0";
in
stdenv.mkDerivation rec {
  name = "poppler-${suffix}-${version}";

  src = fetchurl {
    url = "https://poppler.freedesktop.org/poppler-${version}.tar.xz";
    multihash = "Qmb3QUwnk7iM4MJLfHxvXjBoTWeLPJredvv8DNxZFahVPZ";
    hashOutput = false;
    sha256 = "92e09fd3302567fd36146b36bb707db43ce436e8841219025a82ea9fb0076b2f";
  };

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    cairo
    curl
    fontconfig
    freetype
    glib
    gobject-introspection
    lcms2
    libjpeg
    libpng
    libtiff
    nspr
    nss
    openjpeg
    qt5
    zlib
  ];

  patches = [
    (fetchTritonPatch {
      rev = "d3fc5e59bd2b4b465c2652aae5e7428b24eb5669";
      file = "poppler/poppler-datadir_env.patch";
      sha256 = "da3dd1d57a7ef0dcda7442dff2fff5375e249ba85caba9828be4fc51bfa300ff";
    })
  ];

  cmakeFlags = [
    "-DBUILD_GTK_TESTS=OFF"
    "-DBUILD_QT5_TESTS=OFF"
    "-DBUILD_CPP_TESTS=OFF"
    "-DENABLE_GLIB=${boolOn (glib != null)}"
    "-DENABLE_UTILS=${boolOn utils}"
    "-DENABLE_GOBJECT_INTROSPECTION=${boolOn (gobject-introspection != null)}"
    "-DENABLE_QT5=${boolOn (qt5 != null)}"
    "-DENABLE_LIBOPENJPEG=${boolString (openjpeg != null) "openjpeg2" "none"}"
    "-DENABLE_CMS=${boolString (lcms2 != null) "lcms2" "none"}"
    "-DENABLE_DCTDECODER=${boolString (libjpeg != null) "libjpeg" "none"}"
    "-DENABLE_LIBCURL=${boolOn (curl != null)}"
    "-DENABLE_ZLIB=${boolOn (zlib != null)}"
    "-DSPLASH_CMYK=ON"
    "-DUSE_FLOAT=ON"
    "-DWITH_JPEG=${boolOn (libjpeg != null)}"
    "-DWITH_PNG=${boolOn (libpng != null)}"
    "-DWITH_TIFF=${boolOn (libtiff != null)}"
    "-DWITH_NSS3=${boolOn (nss != null)}"
    "-DWITH_Cairo=${boolOn (cairo != null)}"
  ];

  passthru = {
    srcVerification = fetchurl {
      failEarly = true;
      inherit (src)
        urls
        outputHash
        outputHashAlgo;
      fullOpts = { };
    };
  };

  meta = with lib; {
    description = "A PDF rendering library";
    homepage = http://poppler.freedesktop.org/;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
