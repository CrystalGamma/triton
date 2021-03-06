{ stdenv
, buildPythonPackage
, fetchPyPi
, lib

, nose
}:

let
  inherit (lib)
    optionals;

  version = "0.4";
in

buildPythonPackage rec {
  name = "safe-${version}";

  src = fetchPyPi {
    package = "Safe";
    inherit version;
    sha256 = "a2fdac9fe8a9dcf02b438201d6ce0b7be78f85dc6492d03edfb89be2adf489de";
  };

  buildInputs = optionals doCheck [
    nose
  ];

  doCheck = true;

  meta = with lib; {
    description = "Safe checks password strength";
    homepage = https://github.com/lepture/safe;
    license = licenses.bsd3;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
