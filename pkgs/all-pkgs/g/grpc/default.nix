{ stdenv
, autoconf
, automake
, fetchFromGitHub
, libtool
, which

, c-ares
, gperftools
, openssl
, protobuf-cpp
, zlib
}:

let
  version = "1.9.0";
in
stdenv.mkDerivation {
  name = "grpc-${version}";

  src = fetchFromGitHub {
    version = 5;
    owner = "grpc";
    repo = "grpc";
    rev = "v${version}";
    sha256 = "05728b472785835b9921054d17594f5c35637282f757c025fc0e0fe8ba667610";
  };

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    protobuf-cpp
    which
  ];

  buildInputs = [
    c-ares
    gperftools
    openssl
    protobuf-cpp
    zlib
  ];

  postPatch = ''
    rm -r third_party/{cares,protobuf,zlib,googletest,boringssl}
    unpackFile ${protobuf-cpp.src}
    mv -v protobuf* third_party/protobuf

    sed -i 's, -Werror,,g' Makefile
  '';

  NIX_CFLAGS_LINK = [
    "-pthread"
  ];

  preBuild = ''
    sed -i 's,\(grpc++.*\.so\.\)5,\11,g' Makefile
    makeFlagsArray+=("prefix=$out")
  '';

  postInstall = ''
    test -e "$out"/lib/libgrpc++.so.1
  '';

  meta = with stdenv.lib; {
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
