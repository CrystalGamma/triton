{ stdenv
, buildRustPackage
, cargo_bootstrap
, fetchCargo
, rustc
}:

let
  version = "0.17.0";
in
buildRustPackage {
  name = "cargo-${version}";

  src = fetchCargo {
    version = 2;
    package = "cargo";
    packageVersion = version;
    sha256 = "18k55xb89v8liar7aqa8f7074ic9h4bklfbx16qhhcbl9bjs8p2s";
  };

  nativeBuildInputs = [
    rustc
  ];

  passthru = {
    bootstrap = cargo_bootstrap;
  };

  meta = with stdenv.lib; {
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}