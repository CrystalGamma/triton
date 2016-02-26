{ stdenv
, fetchurl

, attr
, acl
, zlib
, e2fsprogs
, lzo
, asciidoc
, xmlto
, docbook_xml_dtd_45
, docbook_xsl
, libxslt
, util-linux_lib
}:

stdenv.mkDerivation rec {
  name = "btrfs-progs-${version}";
  version = "4.4";

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v${version}.tar.xz";
    sha256 = "0jssv1ys4nw2jf7mkp58c19yspaa8ybf48fxsrhhp0683mzpr73p";
  };

  buildInputs = [
    attr
    acl
    zlib
    e2fsprogs
    lzo
    asciidoc
    xmlto
    docbook_xml_dtd_45
    docbook_xsl
    libxslt
    util-linux_lib
  ];

  meta = with stdenv.lib; {
    description = "Utilities for the btrfs filesystem";
    homepage = https://btrfs.wiki.kernel.org/;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms =  with platforms;
      i686-linux
      ++ x86_64-linux;
  };
}
