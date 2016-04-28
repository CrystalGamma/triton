{ stdenv, fetchFromGitHub, fetchTritonPatch, autoreconfHook, libibverbs, librdmacm, libevent

# Linux only deps
, numactl, kernel ? null
}:

stdenv.mkDerivation rec {
  name = "accelio-${version}${stdenv.lib.optionalString (kernel != null) "-kernel"}";
  version = "1.5";

  src = fetchFromGitHub {
    owner = "accelio";
    repo = "accelio";
    rev = "v1.5";
    sha256 = "481ce26da3fb86143f456f0d6ebbf582c21586fda6760edcd4f564512449bc49";
  };

  patches = [
    (fetchTritonPatch {
      rev = "46327f20920c01ffb395dbd946cd7cffb67567b6";
      file = "accelio/fix-printfs.patch";
      sha256 = "2ab68c485eb00857a1977ba5c08d7656205ab3f2475031d1507816bb29120bc2";
    })
  ];

  postPatch = ''
    grep -q '\-g -ggdb -Wall -Werror' configure.ac
    sed -i 's,-g -ggdb -Wall -Werror,-O2,g' configure.ac

    # Don't build broken examples
    sed -i '/AC_CONFIG_SUBDIRS(\[\(examples\|tests\).*/d' configure.ac

    # Allow the installation of xio kernel headers
    sed -i 's,/opt/xio,''${out},g' src/kernel/xio/Makefile.in

    # Don't install ldconfig entries
    sed -i '\,/etc/ld.so.conf.d/libxio.conf,d' src/usr/Makefile.am
    sed -i '\,/sbin/ldconfig,d' src/usr/Makefile.am
  '';

  nativeBuildInputs = [ autoreconfHook ];
  buildInputs = [ libevent libibverbs librdmacm numactl ];

  configureFlags = [
    "--enable-rdma"
    "--disable-raio-build"
  ] ++ stdenv.lib.optionals (kernel != null) [
    "--enable-kernel-module"
    "--with-kernel=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source"
    "--with-kernel-build=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  INSTALL_MOD_PATH = "\${out}";

  meta = with stdenv.lib; {
    homepage = http://www.accelio.org/;
    description = "High-performance messaging and RPC library";
    longDescription = ''
      A high-performance asynchronous reliable messaging and RPC library
      optimized for hardware acceleration.
    '';
    license = licenses.bsd3;
    platforms = with platforms; linux ++ freebsd;
    maintainers = with maintainers; [ wkennington ];
  };
}
