{ stdenv
, fetchurl
, lib
, libtool
, dhcp
, docbook-xsl-ns

, db
, fstrm
, json-c
, kerberos
, libcap
, libxml2
, lmdb
, mariadb-connector-c
, ncurses
, openldap
, openssl
, postgresql
, protobuf-c
, python3Packages
, readline
, zlib

, suffix ? ""
}:

let
  toolsOnly = suffix == "tools";

  inherit (lib)
    optionals
    optionalString;

  version = "9.13.7";
in
stdenv.mkDerivation rec {
  name = "bind${optionalString (suffix != "") "-${suffix}"}-${version}";

  src = fetchurl {
    url = "https://ftp.isc.org/isc/bind9/${version}/bind-${version}.tar.gz";
    multihash = "QmWneoN5rVM8bVtnEjKeD54wnsaw3bJMhBAustcvGuwQhS";
    hashOutput = false;
    sha256 = "e7f2065c790419d642dc0a32c5652a53b68a7f17c188fe25a20c5984ddfb74e6";
  };

  nativeBuildInputs = [
    docbook-xsl-ns
    libtool
  ] ++ optionals (!toolsOnly) [
    protobuf-c
  ];

  buildInputs = [
    kerberos
    ncurses
    openssl
    readline
  ] ++ optionals (!toolsOnly) [
    db
    fstrm
    json-c
    libcap
    libxml2
    lmdb
    mariadb-connector-c
    openldap
    postgresql
    protobuf-c
    python3Packages.python
    python3Packages.ply
    zlib
  ];

  configureFlags = [
    "--localstatedir=/var"
    "--sysconfdir=/etc"
    "--enable-largefile"
    "--disable-backtrace"
    "--disable-symtable"
    "--enable-full-report"
    "--with-openssl=${openssl}"
    "--with-gssapi=${kerberos}/bin/krb5-config"
  ] ++ optionals (toolsOnly) [
    "--disable-linux-caps"
    "--without-python"
  ] ++ optionals (!toolsOnly) [
    "--enable-dnstap"
    "--enable-dnsrps-dl"
    "--enable-dnsrps"
    "--with-lmdb=${lmdb}"
    "--with-libjson=${json-c}"
    "--with-zlib=${zlib}"
    "--with-dlz-postgres=${postgresql}"
    "--with-dlz-mysql=${mariadb-connector-c}"
    "--with-dlz-bdb=${db}"
    "--with-dlz-filesystem"
    "--with-dlz-ldap=${openldap}"
  ];

  installFlags = [
    "sysconfdir=\${out}/etc"
    "localstatedir=\${TMPDIR}"
  ] ++ optionals toolsOnly [
    "DESTDIR=\${TMPDIR}"
  ];

  postInstall = optionalString toolsOnly ''
    mkdir -p $out/{bin,etc,share/man/man1}
    install -m 0755 $TMPDIR/$out/bin/{dig,host,nslookup,nsupdate} $out/bin
    install -m 0644 $TMPDIR/$out/etc/bind.keys $out/etc
    install -m 0644 $TMPDIR/$out/share/man/man1/{dig,host,nslookup,nsupdate}.1 $out/share/man/man1
  '';

  installParallel = false;

  passthru = {
    srcVerification = fetchurl {
      failEarly = true;
      inherit (src)
        urls
        outputHashAlgo
        outputHash;
      fullOpts = {
        pgpsigUrls = map (n: "${n}.sha512.asc") src.urls;
        pgpKeyFile = dhcp.srcVerification.pgpKeyFile;
        pgpKeyFingerprints = [
          "BE0E 9748 B718 253A 28BB  89FF F1B1 1BF0 5CF0 2E57"
        ];
      };
    };
  };

  meta = with lib; {
    homepage = "http://www.isc.org/software/bind";
    description = "Domain name server";
    license = licenses.isc;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      i686-linux
      ++ x86_64-linux;
  };
}
