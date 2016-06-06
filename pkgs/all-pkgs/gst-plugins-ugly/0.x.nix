{ stdenv
, fetchurl
, gettext

, a52dec
, amrnb
, amrwb
, glib
, gst-plugins-base_0
, gstreamer_0
, lame
#, libcdio
, libdvdread
, libmad
, libmpeg2
, orc
, x264
}:

let
  inherit (stdenv.lib)
    enFlag;
in

stdenv.mkDerivation rec {
  name = "gst-plugins-ugly-0.10.19";

  src = fetchurl {
    url = "https://gstreamer.freedesktop.org/src/gst-plugins-ugly/${name}.tar.xz";
    sha256 = "0wx8dr3sqfkar106yw6h57jdv2cifwsydkziz9z7wqwjz1gzcd29";
  };

  nativeBuildInputs = [
    gettext
  ];

  buildInputs = [
    a52dec
    amrnb
    amrwb
    glib
    gst-plugins-base_0
    gstreamer_0
    lame
    #libcdio
    libdvdread
    libmad
    libmpeg2
    orc
    x264
  ];

  configureFlags = [
    "--disable-maintainer-mode"
    "--enable-nls"
    "--enable-rpath"
    "--disable-debug"
    "--disable-profiling"
    "--disable-valgrind"
    "--disable-gcov"
    "--disable-examples"
    "--enable-external"
    "--enable-experimental"
    "--disable-gtk-doc"
    "--enable-gobject-cast-checks"
    "--enable-glib-asserts"
    (enFlag "orc" (orc != null) null)
    # Internal plugins
    "--enable-asfdemux"
    "--enable-dvdlpcmdec"
    "--enable-dvdsub"
    "--enable-iec958"
    "--enable-mpegaudioparse"
    "--enable-mpegstream"
    "--enable-realmedia"
    "--enable-synaesthesia"
    # External plugins
    (enFlag "a52dec" (a52dec != null) null)
    (enFlag "amrnb" (amrnb != null) null)
    (enFlag "amrwb" (amrwb != null) null)
    #(enFlag "cdio" (libcdio != null) null)
    (enFlag "dvdread" (libdvdread != null) null)
    (enFlag "lame" (lame != null) null)
    (enFlag "mad" (libmad != null) null)
    (enFlag "mpeg2dec" (libmpeg2 != null) null)
    #(enFlag "sidplay" (sidplay != null) null)
    #(enFlag "twolame" (twolame != null) null)
    (enFlag "x264" (x264 != null) null)
  ];

  meta = with stdenv.lib; {
    description = "Basepack of plugins for gstreamer";
    homepage = http://gstreamer.freedesktop.org;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
