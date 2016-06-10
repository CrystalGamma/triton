/* This file defines the composition for Go packages. */

{ stdenv
, buildGoPackage
, fetchbzr
, fetchFromBitbucket
, fetchFromGitHub
, fetchgit
, fetchhg
, fetchTritonPatch
, fetchurl
, fetchzip
, git
, go
, overrides
, pkgs
}:

let
  self = _self // overrides; _self = with self; {

  inherit go buildGoPackage;

  fetchGxPackage = { src, sha256 }: stdenv.mkDerivation {
    name = "gx-src-${src.name}";

    impureEnvVars = [ "IPFS_API" ];
    buildCommand = ''
      if ! [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        echo "Missing /etc/ssl/certs/ca-certificates.crt" >&2
        echo "Please update to a version of nix which supports ssl." >&2
        exit 1
      fi

      unpackDir="$TMPDIR/src"
      mkdir "$unpackDir"
      cd "$unpackDir"
      unpackFile "${src}"
      cd *

      mtime=$(find . -type f -print0 | xargs -0 -r stat -c '%Y' | sort -n | tail -n 1)
      if [ "$(( $(date -u '+%s') - 600 ))" -lt "$mtime" ]; then
        str="The newest file is too close to the current date (10 minutes):\n"
        str+="  File: $(date -u -d "@$mtime")\n"
        str+="  Current: $(date -u)\n"
        echo -e "$str" >&2
        exit 1
      fi
      echo -n "Clamping to date: " >&2
      date -d "@$mtime" --utc >&2

      gx --verbose install --global

      echo "Building GX Archive" >&2
      cd "$unpackDir"
      tar --sort=name --owner=0 --group=0 --numeric-owner \
        --no-acls --no-selinux --no-xattrs \
        --mode=go=rX,u+rw,a-s \
        --clamp-mtime --mtime=@$mtime \
        -c . | brotli --quality 6 --output "$out"
    '';

    buildInputs = [ gx.bin ];
    outputHashAlgo = "sha256";
    outputHashMode = "flat";
    outputHash = sha256;
    preferLocalBuild = true;
  };

  buildFromGitHub =
    { rev
    , date ? null
    , owner
    , repo
    , sha256
    , gxSha256 ? null
    , goPackagePath ? "github.com/${owner}/${repo}"
    , name ? baseNameOf goPackagePath
    , ...
    } @ args:
    buildGoPackage (args // (let
        name' = "${name}-${if date != null then date else if builtins.stringLength rev != 40 then rev else stdenv.lib.strings.substring 0 7 rev}";
      in {
        inherit rev goPackagePath;
        name = name';
        src = let
          src' = fetchFromGitHub {
            name = name';
            inherit rev owner repo sha256;
          };
        in if gxSha256 == null then
          src'
        else
          fetchGxPackage { src = src'; sha256 = gxSha256; };
      })
  );

  buildFromGoogle = { rev, date ? null, repo, sha256, name ? repo, goPackagePath ? "google.golang.org/${repo}", ... }@args: buildGoPackage (args // (let
      name' = "${name}-${if date != null then date else if builtins.stringLength rev != 40 then rev else stdenv.lib.strings.substring 0 7 rev}";
    in {
      inherit rev goPackagePath;
      name = name';
      src  = fetchzip {
        name = name';
        url = "https://code.googlesource.com/go${repo}/+archive/${rev}.tar.gz";
        inherit sha256;
        stripRoot = false;
        purgeTimestamps = true;
      };
    })
  );

  ## OFFICIAL GO PACKAGES

  appengine = buildFromGitHub {
    rev = "7f59a8c76b8594d06044bfe0bcbe475cb2020482";
    date = "2016-05-16";
    owner = "golang";
    repo = "appengine";
    sha256 = "0w2y6g9ncaipmpgmpcbpjxyrfa925wzbknf9pd6srzdia1fk8l2q";
    goPackagePath = "google.golang.org/appengine";
    propagatedBuildInputs = [ protobuf net ];
  };

  crypt = buildFromGitHub {
    owner = "xordataexchange";
    repo = "crypt";
    rev = "749e360c8f236773f28fc6d3ddfce4a470795227";
    date = "2015-05-23";
    sha256 = "a5dfaca2c8a2e8e731ce3e912a5a610dc9e43838c55867fe0df66cbc6f05807d";
    propagatedBuildInputs = [
      consul
      crypto
    ];
    patches = [
      (fetchTritonPatch {
        rev = "77ff70bae635d2ac5bae8c647120d336070a579e";
        file = "crypt/crypt-2015-05-remove-etcd-support.patch";
        sha256 = "e942558fc230884e4ddbbafd97f7a3ea56bacdfea90a24f8790d37c399265904";
      })
    ];
    postPatch = ''
      sed -i backend/consul/consul.go \
        -e 's,"github.com/armon/consul-api",consulapi "github.com/hashicorp/consul/api",'
    '';
  };

  crypto = buildFromGitHub {
    rev = "77f4136a99ffb5ecdbdd0226bd5cb146cf56bc0e";
    date = "2016-06-07";
    owner    = "golang";
    repo     = "crypto";
    sha256 = "0gzglgv7h96002fi8s6f4qc84ak42xa6nhzni25pxz8544fbsyhv";
    goPackagePath = "golang.org/x/crypto";
    goPackageAliases = [
      "code.google.com/p/go.crypto"
      "github.com/golang/crypto"
    ];
    buildInputs = [
      net_crypto_lib
    ];
  };

  glog = buildFromGitHub {
    rev = "23def4e6c14b4da8ac2ed8007337bc5eb5007998";
    date = "2016-01-25";
    owner  = "golang";
    repo   = "glog";
    sha256 = "0wj30z2r6w1zdbsi8d14cx103x13jszlqkvdhhanpglqr22mxpy0";
  };

  codesearch = buildFromGitHub {
    rev = "0.0.0";
    date   = "2015-06-17";
    owner  = "google";
    repo   = "codesearch";
    sha256 = "12bv3yz0l3bmsxbasfgv7scm9j719ch6pmlspv4bd4ix7wjpyhny";
  };

  image = buildFromGitHub {
    rev = "0.0.0";
    date = "2016-01-02";
    owner = "golang";
    repo = "image";
    sha256 = "05c5qrph5r5ikzxw1mlgihx8396hawv38q2syjvwbxdiib9gfg9k";
    goPackagePath = "golang.org/x/image";
    goPackageAliases = [ "github.com/golang/image" ];
  };

  net = buildFromGitHub {
    rev = "3f122ce3dbbe488b7e6a8bdb26f41edec852a40b";
    date = "2016-06-09";
    owner  = "golang";
    repo   = "net";
    sha256 = "1pdysc7bvc459svfgam45iab2izvf9jkbxyfpp32q1nkacjhg2mi";
    goPackagePath = "golang.org/x/net";
    goPackageAliases = [
      "code.google.com/p/go.net"
      "github.com/hashicorp/go.net"
      "github.com/golang/net"
    ];
    propagatedBuildInputs = [ text crypto ];
  };

  net_crypto_lib = buildFromGitHub {
    inherit (net) rev date owner repo sha256 goPackagePath;
    subPackages = [
      "context"
    ];
  };

  oauth2 = buildFromGitHub {
    rev = "65a8d08c6292395d47053be10b3c5e91960def76";
    date = "2016-06-07";
    owner = "golang";
    repo = "oauth2";
    sha256 = "1xph0wj1b0n1dqc7myjqrbnjzk9qcllx4mf95k3qhi62bdhcgj1m";
    goPackagePath = "golang.org/x/oauth2";
    goPackageAliases = [ "github.com/golang/oauth2" ];
    propagatedBuildInputs = [ net gcloud-golang-compute-metadata ];
  };


  protobuf = buildFromGitHub {
    rev = "8616e8ee5e20a1704615e6c8d7afcdac06087a67";
    date = "2016-06-08";
    owner = "golang";
    repo = "protobuf";
    sha256 = "0mk5f2hq0dwblnqgxw5r9qgl1a7fam5y15xnpp43blghn89g7giq";
    goPackagePath = "github.com/golang/protobuf";
    goPackageAliases = [ "code.google.com/p/goprotobuf" ];
  };

  snappy = buildFromGitHub {
    rev = "d9eb7a3d35ec988b8585d4a0068e462c27d28380";
    date = "2016-05-29";
    owner  = "golang";
    repo   = "snappy";
    sha256 = "1z7xwm1w0nh2p6gdp0cg6hvzizs4zjn43c7vrm1fmf3sdvp6pxnw";
    goPackageAliases = [ "code.google.com/p/snappy-go/snappy" ];
  };

  sys = buildFromGitHub {
    rev = "b44883b474ffefa37335017174e397412b633a4f";
    date = "2016-06-09";
    owner  = "golang";
    repo   = "sys";
    sha256 = "0j7nhx32n1qywy2ripgkw4zscvjcxv9lm16rmfv05m29ss5c77k1";
    goPackagePath = "golang.org/x/sys";
    goPackageAliases = [
      "github.com/golang/sys"
    ];
  };

  text = buildFromGitHub {
    rev = "e4775119bd79944a15a741ac4be61e43509a70d9";
    date = "2016-06-07";
    owner = "golang";
    repo = "text";
    sha256 = "0d96j9hnxxwjsac6v9j5m589f8596pf4c16iclnwmczbcdnrqwg6";
    goPackagePath = "golang.org/x/text";
    goPackageAliases = [ "github.com/golang/text" ];
  };

  tools = buildFromGitHub {
    rev = "95963e031d86b0e7dafe40fde044d7f610404855";
    date = "2016-06-07";
    owner = "golang";
    repo = "tools";
    sha256 = "0wki6dwvrhwcsi0gh6766hq9xc89656gbpxrdkc42p8m2c3anpv2";
    goPackagePath = "golang.org/x/tools";
    goPackageAliases = [ "code.google.com/p/go.tools" ];

    preConfigure = ''
      # Make the builtin tools available here
      mkdir -p $bin/bin
      eval $(go env | grep GOTOOLDIR)
      find $GOTOOLDIR -type f | while read x; do
        ln -sv "$x" "$bin/bin"
      done
      export GOTOOLDIR=$bin/bin
    '';

    excludedPackages = "\\("
      + stdenv.lib.concatStringsSep "\\|" ([ "testdata" ] ++ stdenv.lib.optionals (stdenv.lib.versionAtLeast go.meta.branch "1.5") [ "vet" "cover" ])
      + "\\)";

    buildInputs = [ appengine net ];

    # Do not copy this without a good reason for enabling
    # In this case tools is heavily coupled with go itself and embeds paths.
    allowGoReference = true;

    # Set GOTOOLDIR for derivations adding this to buildInputs
    postInstall = ''
      mkdir -p $bin/nix-support
      echo "export GOTOOLDIR=$bin/bin" >> $bin/nix-support/setup-hook
    '';
  };


  ## THIRD PARTY

  ace = buildFromGitHub {
    owner = "yosssi";
    repo = "ace";
    rev = "71afeb714739f9d5f7e1849bcd4a0a5938e1a70d";
    date = "2016-01-02";
    sha256 = "9fb20b243e6000cbc42ad57e22e88911f71a573fbe8a57e8ed6b1cc5c1bc8eaa";
    buildInputs = [
      gohtml
    ];
  };

  afero = buildFromGitHub {
    owner = "spf13";
    repo = "afero";
    rev = "1a8ecf8b9da1fb5306e149e83128fc447957d2a8";
    date = "2016-06-05";
    sha256 = "afcc21bb0886b2823dc77a1761b95e81c41201cc911524c9756b4f7f1037aedb";
    propagatedBuildInputs = [
      sftp
      text
    ];
  };

  amber = buildFromGitHub {
    owner = "eknkc";
    repo = "amber";
    rev = "91774f050c1453128146169b626489e60108ec03";
    date = "2016-04-20";
    sha256 = "c4b5a877a149a7f7e8c8b318d996b72f7738a49549b60072c5922f9fbfdd48c5";
  };

  ansicolor = buildFromGitHub {
    date = "2015-11-20";
    rev = "a422bbe96644373c5753384a59d678f7d261ff10";
    owner  = "shiena";
    repo   = "ansicolor";
    sha256 = "1qfq4ax68d7a3ixl60fb8kgyk0qx0mf7rrk562cnkpgzrhkdcm0w";
  };

  asn1-ber = buildFromGitHub {
    rev = "v1.1";
    owner  = "go-asn1-ber";
    repo   = "asn1-ber";
    sha256 = "1mi96bl0jn3nrp4v5aqxgqf5zdndif1qdhdjgjayigjkl67770s3";
    goPackageAliases = [
      "github.com/nmcclain/asn1-ber"
      "github.com/vanackere/asn1-ber"
      "gopkg.in/asn1-ber.v1"
    ];
  };

  assertions = buildGoPackage rec {
    version = "1.5.0";
    name = "assertions-${version}";
    goPackagePath = "github.com/smartystreets/assertions";
    src = fetchurl {
      name = "${name}.tar.gz";
      url = "https://github.com/smartystreets/assertions/archive/${version}.tar.gz";
      sha256 = "1s4b0v49yv7jmy4izn7grfqykjrg7zg79dg5hsqr3x40d5n7mk02";
    };
    buildInputs = [ oglematchers ];
    propagatedBuildInputs = [ goconvey ];
    doCheck = false;
  };

  aws-sdk-go = buildFromGitHub {
    rev = "v1.1.34";
    owner  = "aws";
    repo   = "aws-sdk-go";
    sha256 = "0q8dn0i29513542knwdlk082bzq172kal4cfsjkfxk7w53x714w8";
    buildInputs = [ testify gucumber tools ];
    propagatedBuildInputs = [ ini go-jmespath ];

    preBuild = ''
      pushd go/src/$goPackagePath
      make generate
      popd
    '';
  };

  b = buildFromGitHub {
    date = "2016-02-10";
    rev = "47184dd8c1d2c7e7f87dae8448ee2007cdf0c6c4";
    owner  = "cznic";
    repo   = "b";
    sha256 = "1sw8yyb906v3kv8km8wnyrgkvyjbv74iinrdvjh1qb87p2vr4b17";
  };

  bigfft = buildFromGitHub {
    date = "2013-09-13";
    rev = "a8e77ddfb93284b9d58881f597c820a2875af336";
    owner = "remyoudompheng";
    repo = "bigfft";
    sha256 = "1cj9zyv3shk8n687fb67clwgzlhv47y327180mvga7z741m48hap";
  };

  blackfriday = buildFromGitHub {
    owner = "russross";
    repo = "blackfriday";
    rev = "v1.4";
    sha256 = "855a704b11b55ec6ca69cc5c84dc1900bfc4c2a7071b1cc4cc6e7353ea36bb8b";
    propagatedBuildInputs = [
      sanitized-anchor-name
    ];
  };

  bolt = buildFromGitHub {
    rev = "v1.2.1";
    owner  = "boltdb";
    repo   = "bolt";
    sha256 = "1fm23v09n43f61pzkd0znl9nwlss8kj076pqycsj7vq1bjf1lw0v";
  };

  btree = buildFromGitHub {
    rev = "7d79101e329e5a3adf994758c578dab82b90c017";
    owner  = "google";
    repo   = "btree";
    sha256 = "0ky9a9r1i3awnjisk8bkw4d9v5jkcm9w6sphd889vxdhvizvkskl";
    date = "2016-05-24";
  };

  bufs = buildFromGitHub {
    date = "2014-08-18";
    rev = "3dcccbd7064a1689f9c093a988ea11ac00e21f51";
    owner  = "cznic";
    repo   = "bufs";
    sha256 = "0551h2slsb7lg3r6yif65xvf6k8f0izqwyiigpipm3jhlln37c6p";
  };

  candiedyaml = buildFromGitHub {
    date = "2016-04-29";
    rev = "99c3df83b51532e3615f851d8c2dbb638f5313bf";
    owner  = "cloudfoundry-incubator";
    repo   = "candiedyaml";
    sha256 = "104giv2wjiispfsm82q3lk5qjvfjgrqhhnxm2yma9i21klmvir0y";
  };

  cascadia = buildGoPackage rec {
    rev = "0.0.1"; #master
    name = "cascadia-${stdenv.lib.strings.substring 0 7 rev}";
    goPackagePath = "github.com/andybalholm/cascadia";
    goPackageAliases = [ "code.google.com/p/cascadia" ];
    propagatedBuildInputs = [ net ];
    buildInputs = propagatedBuildInputs;
    doCheck = true;

    src = fetchFromGitHub {
      inherit rev;
      owner = "andybalholm";
      repo = "cascadia";
      sha256 = "1z21w6p5bp7mi2pvicvcqc871k9s8a6262pkwyjm2qfc859c203m";
    };
  };

  cast = buildFromGitHub {
    owner = "spf13";
    repo = "cast";
    rev = "27b586b42e29bec072fe7379259cc719e1289da6";
    date = "2016-03-03";
    sha256 = "eebddee154709079698faada7bb175d8cf6ec48d56fab4d013cf4064b0ac5cac";
    buildInputs = [
      jwalterweatherman
    ];
  };

  check-v1 = buildFromGitHub {
    rev = "4f90aeace3a26ad7021961c297b22c42160c7b25";
    owner = "go-check";
    repo = "check";
    goPackagePath = "gopkg.in/check.v1";
    sha256 = "1vmf8shg0kqakmh60k5m985vxj9h2lb18lw69qx9scl5i66n746h";
    date = "2016-01-05";
  };

  circbuf = buildFromGitHub {
    date = "2015-08-26";
    rev = "bbbad097214e2918d8543d5201d12bfd7bca254d";
    owner  = "armon";
    repo   = "circbuf";
    sha256 = "0wgpmzh0ga2kh51r214jjhaqhpqr9l2k6p0xhy5a006qypk5fh2m";
  };

  mitchellh-cli = buildFromGitHub {
    date = "2016-03-23";
    rev = "168daae10d6ff81b8b1201b0a4c9607d7e9b82e3";
    owner = "mitchellh";
    repo = "cli";
    sha256 = "1ihlx94djy3npy88kv1ahsgk4vh4jchsgmyj2pkrawf8chf1i4v3";
    propagatedBuildInputs = [ crypto go-radix speakeasy go-isatty ];
  };

  codegangsta-cli = buildFromGitHub {
    rev = "v1.17.0";
    owner = "codegangsta";
    repo = "cli";
    sha256 = "0171xw72kvsk4zcygvrmslcir9qp7q4v1lh6rpllayf9ws1253dl";
    buildInputs = [ yaml-v2 ];
  };

  cli-go = buildFromGitHub {
    rev = "v1.17.0";
    owner  = "codegangsta";
    repo   = "cli";
    sha256 = "0171xw72kvsk4zcygvrmslcir9qp7q4v1lh6rpllayf9ws1253dl";
  };

  cobra = buildFromGitHub {
    owner = "spf13";
    repo = "cobra";
    rev = "1238ba19d24b0b9ceee2094e1cb31947d45c3e86";
    date = "2016-06-07";
    sha256 = "2ffddb068550e49ad5f7f3c6e11f52b5ecd40cd220629abcf7f73a798dd5a341";
    buildInputs = [
      pflag
      viper
    ];
    propagatedBuildInputs = [
      go-md2man
    ];
  };

  columnize = buildFromGitHub {
    rev = "v2.1.0";
    owner  = "ryanuber";
    repo   = "columnize";
    sha256 = "0r9r4p4x1vnrq31dj5bvw3phhmqpsb5vwh72cs2wwxmhalzq92hx";
  };

  copystructure = buildFromGitHub {
    date = "2016-06-09";
    rev = "ae8f8315ad044b86ced2e0be9e3598e9dd94f38e";
    owner = "mitchellh";
    repo = "copystructure";
    sha256 = "185c10ab80cn4jxdp915h428lm0r9zf1cqrfsjs71im3w3ankvsn";
    propagatedBuildInputs = [ reflectwalk ];
  };

  consul = buildFromGitHub {
    rev = "v0.6.4";
    owner = "hashicorp";
    repo = "consul";
    sha256 = "157g5j6a8jf762p308w6sy4byhcqqvm3il5iyjwf5ykavvjizz31";

    buildInputs = [
      datadog-go circbuf armon_go-metrics go-radix speakeasy bolt
      go-bindata-assetfs go-dockerclient errwrap go-checkpoint
      go-immutable-radix go-memdb ugorji_go go-multierror go-reap go-syslog
      golang-lru hcl logutils memberlist net-rpc-msgpackrpc raft raft-boltdb
      scada-client yamux muxado dns mitchellh-cli mapstructure columnize
      copystructure hil hashicorp-go-uuid crypto sys
    ];

    propagatedBuildInputs = [
      go-cleanhttp
      serf
    ];

    # Keep consul.ui for backward compatability
    passthru.ui = pkgs.consul-ui;
  };

  consul-api = buildFromGitHub {
    inherit (consul) owner repo;
    rev = "6d35960361f10a74eb1454bedef24ab7f87a636e";
    date = "2016-06-09";
    sha256 = "94d138b3f50c4515d104d8ac13d91c19ea73938c4a00bdcac27be526a0bac729";
    buildInputs = [ go-cleanhttp serf ];
    subPackages = [ "api" "tlsutil" ];
  };

  consul-template = buildFromGitHub {
    rev = "v0.15.0";
    owner = "hashicorp";
    repo = "consul-template";
    sha256 = "046jcgspqaqdrxa1f5xs47hmmjxvfsycbhjjxckd1nsc9fb68sfd";

    buildInputs = [
      consul-api
      go-cleanhttp
      go-multierror
      go-reap
      go-syslog
      logutils
      mapstructure
      serf
      yaml-v2
      vault-api
    ];
  };

  context = buildGoPackage rec {
    rev = "v1.1";
    name = "config-${stdenv.lib.strings.substring 0 7 rev}";
    goPackagePath = "github.com/gorilla/context";

    src = fetchFromGitHub {
      inherit rev;
      owner = "gorilla";
      repo = "context";
    sha256 = "0fsm31ayvgpcddx3bd8fwwz7npyd7z8d5ja0w38lv02yb634daj6";
    };
  };

  cronexpr = buildFromGitHub {
    rev = "f0984319b44273e83de132089ae42b1810f4933b";
    owner  = "gorhill";
    repo   = "cronexpr";
    sha256 = "0d2c67spcyhr4bxzmnqsxnzbn6a8sw893wvc4cx7a3js4ydy7raz";
    date = "2016-03-18";
  };

  cssmin = buildFromGitHub {
    owner = "dchest";
    repo = "cssmin";
    rev = "fb8d9b44afdc258bfff6052d3667521babcb2239";
    date = "2015-12-10";
    sha256 = "246676cd9dc5adcf50685d7bc9a891ed5249a2e8db6c3babdfcc63c155c33fd5";
  };

  datadog-go = buildFromGitHub {
    date = "2016-03-29";
    rev = "cc2f4770f4d61871e19bfee967bc767fe730b0d9";
    owner = "DataDog";
    repo = "datadog-go";
    sha256 = "10c1jkghl7a7a4z80lsjg11gx3vf6nn7y5x078b98mxisf0x0cdv";
  };

  dbus = buildFromGitHub {
    rev = "v4.0.0";
    owner = "godbus";
    repo = "dbus";
    sha256 = "0q2qabf656sq0pd3candndd8nnkwwp4by4hlkxjn4fs85ld44i8s";
  };

  dns = buildFromGitHub {
    rev = "1be732049888e8c60bc7f174d7dbce1bf5c09f1d";
    date = "2016-06-08";
    owner  = "miekg";
    repo   = "dns";
    sha256 = "08qr0885bykqb0z2mkrrcrbg5a2a8gfwzf4sfhr0chbf8aj4j8mz";
  };

  weppos-dnsimple-go = buildFromGitHub {
    rev = "65c1ca73cb19baf0f8b2b33219b7f57595a3ccb0";
    date = "2016-02-04";
    owner  = "weppos";
    repo   = "dnsimple-go";
    sha256 = "0v3vnp128ybzmh4fpdwhl6xmvd815f66dgdjzxarjjw8ywzdghk9";
  };

  docker = buildFromGitHub {
    rev = "v1.11.2";
    owner = "docker";
    repo = "docker";
    sha256 = "14h1s296ayz20qj8l3qih3xi97yaji7q1rry8ic0g57hazafxayf";
  };

  docker_for_runc = buildFromGitHub {
    inherit (docker) rev owner repo sha256;
    subPackages = [
      "pkg/mount"
      "pkg/symlink"
      "pkg/system"
      "pkg/term"
    ];
    propagatedBuildInputs = [
      go-units
    ];
  };

  docker_for_go-dockerclient = buildFromGitHub {
    inherit (docker) rev owner repo sha256;
    subPackages = [
      "opts"
      "pkg/archive"
      "pkg/fileutils"
      "pkg/homedir"
      "pkg/idtools"
      "pkg/ioutils"
      "pkg/pools"
      "pkg/promise"
      "pkg/stdcopy"
    ];
    propagatedBuildInputs = [
      go-units
      logrus
      net
      runc
    ];
  };

  docopt-go = buildFromGitHub {
    rev = "0.6.2";
    owner  = "docopt";
    repo   = "docopt-go";
    sha256 = "11cxmpapg7l8f4ar233f3ybvsir3ivmmbg1d4dbnqsr1hzv48xrf";
  };

  duo_api_golang = buildFromGitHub {
    date = "2016-03-22";
    rev = "6f814b626e6aad2bb14b95969b42fdb09c4a0f16";
    owner = "duosecurity";
    repo = "duo_api_golang";
    sha256 = "01lxky92b71ayzc2fw1y7phdzn9m62sr7p1y1pm6adbzjaqlpg8n";
  };

  emoji = buildFromGitHub {
    owner = "kyokomi";
    repo = "emoji";
    rev = "v1.4";
    sha256 = "a25d220b818f42d1de44b24109567e354d7ec033288fde179d626202419b07cd";
  };

  envpprof = buildFromGitHub {
    rev = "0383bfe017e02efb418ffd595fc54777a35e48b0";
    owner = "anacrolix";
    repo = "envpprof";
    sha256 = "0i9d021hmcfkv9wv55r701p6j6r8mj55fpl1kmhdhvar8s92rjgl";
    date = "2016-05-28";
  };

  du = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "calmh";
    repo   = "du";
    sha256 = "02gri7xy9wp8szxpabcnjr18qic6078k213dr5k5712s1pg87qmj";
  };

  errors = buildFromGitHub {
    owner = "pkg";
    repo = "errors";
    rev = "v0.6.0";
    sha256 = "c76fe5a641f77227f64c51e61d5cef967fda3ca752b53136bb3e928f850b830c";
  };

  errwrap = buildFromGitHub {
    date = "2014-10-27";
    rev = "7554cd9344cec97297fa6649b055a8c98c2a1e55";
    owner  = "hashicorp";
    repo   = "errwrap";
    sha256 = "02hsk2zbwg68w62i6shxc0lhjxz20p3svlmiyi5zjz988qm3s530";
  };

  etcd = buildFromGitHub {
    owner = "coreos";
    repo = "etcd";
    rev = "v2.3.6";
    sha256 = "0x1fhn5hgdamj8xbry6b3dqaddy0ls00x4bcrpm4fp2n940k3l18";
    buildInputs = [
      pkgs.libpcap
      tablewriter
    ];
  };

  etcd-client = buildFromGitHub {
    inherit (etcd) rev owner repo sha256;
    subPackages = [
      "client"
      "pkg/pathutil"
      "pkg/transport"
      "pkg/types"
      "Godeps/_workspace/src/golang.org/x/net"
      "Godeps/_workspace/src/github.com/ugorji/go/codec"
    ];
  };

  exp = buildFromGitHub {
    date = "2015-12-07";
    rev = "c21cce1fce3e6e5bc84854aa3d02a808de44229b";
    owner  = "cznic";
    repo   = "exp";
    sha256 = "00dx5nnjxwpd8dmig210hsgag0brk8391kar97kp3dlikn6dbqb5";
    propagatedBuildInputs = [ bufs fileutil mathutil sortutil zappy ];
  };

  fileutil = buildFromGitHub {
    date = "2015-07-08";
    rev = "1c9c88fbf552b3737c7b97e1f243860359687976";
    owner  = "cznic";
    repo   = "fileutil";
    sha256 = "0naps0miq8lk4k7k6c0l9583nv6wcdbs9zllvsjjv60h4fsz856a";
    buildInputs = [ mathutil ];
  };

  fs = buildFromGitHub {
    date = "2013-11-07";
    rev = "2788f0dbd16903de03cb8186e5c7d97b69ad387b";
    owner  = "kr";
    repo   = "fs";
    sha256 = "16ygj65wk30cspvmrd38s6m8qjmlsviiq8zsnnvkhfy5l0gk4c86";
  };

  fsnotify = buildFromGitHub {
    owner = "fsnotify";
    repo = "fsnotify";
    rev = "v1.3.0";
    sha256 = "1e8a18756881e530348b763ab6182e9686e36ec252c7de524419663d96705fbd";
    propagatedBuildInputs = [
      sys
    ];
  };

  fsync = buildFromGitHub {
    owner = "spf13";
    repo = "fsync";
    rev = "eefee59ad7de621617d4ff085cf768aab4b919b1";
    date = "2016-03-01";
    sha256 = "d0d292e0a10902919ff9b30159d9ae077fd68ddffd5977fe9cb1dd2a40aa53e1";
    buildInputs = [
      afero
    ];
  };

  gateway = buildFromGitHub {
    date = "2016-05-22";
    rev = "edad739645120eeb82866bc1901d3317b57909b1";
    owner  = "calmh";
    repo   = "gateway";
    sha256 = "0gzwns51jl2jm62ii99c7caa9p7x2c8p586q1cjz8bpv2mcd8njg";
    goPackageAliases = [
      "github.com/jackpal/gateway"
    ];
  };

  gcloud-golang = buildFromGoogle {
    rev = "4a23f97e60c9a14de1269e78812e59ca94033d85";
    repo = "cloud";
    sha256 = "0x4igfpih9ci8gdk3x8cyp3y4ni3vaqvvbdkfkzw0kcldnhdp9hz";
    propagatedBuildInputs = [
      net
      oauth2
      protobuf
      google-api-go-client
      grpc
    ];
    excludedPackages = "oauth2";
    meta.hydraPlatforms = [ ];
    date = "2016-06-07";
  };

  gcloud-golang-for-go4 = buildFromGoogle {
    inherit (gcloud-golang) rev repo sha256 date;
    subPackages = [
      "storage"
    ];
    propagatedBuildInputs = [
      google-api-go-client
      grpc
      net
      oauth2
    ];
  };

  gcloud-golang-compute-metadata = buildFromGoogle {
    inherit (gcloud-golang) rev repo sha256 date;
    subPackages = [ "compute/metadata" "internal" ];
    buildInputs = [ net ];
  };

  gettext = buildFromGitHub {
    rev = "305f360aee30243660f32600b87c3c1eaa947187";
    owner = "gosexy";
    repo = "gettext";
    sha256 = "0s1f99llg462mbcdmg2yp8l6ifq56v6qp8bw33ng5yrws91xflj7";
    date = "2016-06-02";
    buildInputs = [
      go-flags
      go-runewidth
    ];
  };

  ginkgo = buildFromGitHub {
    rev = "5437a97bf824dec14e58d68c56ee36e772670c2e";
    owner = "onsi";
    repo = "ginkgo";
    sha256 = "18hbr3m7yk7zdj94cs5izgkfd491j7if2760wlip6mhlsxmfhwrh";
    date = "2016-05-09";
  };

  glob = buildFromGitHub {
    rev = "0.2.0";
    owner = "gobwas";
    repo = "glob";
    sha256 = "1lbijdwchj6v7qpy9mr0xzs3v2y868vrmsxk1y24dm6wpacz50jd";
  };

  ugorji_go = buildFromGitHub {
    date = "2016-05-31";
    rev = "b94837a2404ab90efe9289e77a70694c355739cb";
    owner = "ugorji";
    repo = "go";
    sha256 = "0419rraxl5hwpwmwf6ac5201as1456r128llwa49qnl3jg4s98rz";
    goPackageAliases = [ "github.com/hashicorp/go-msgpack" ];
  };

  go4 = buildFromGitHub {
    date = "2016-06-01";
    rev = "15c19124e43b90eba9aa27b4341e38365254a84a";
    owner = "camlistore";
    repo = "go4";
    sha256 = "bdc95657e810fc023362d563a85226ff62ba79e1ecc91e3a4683008cee5c564a";
    goPackagePath = "go4.org";
    goPackageAliases = [ "github.com/camlistore/go4" ];
    buildInputs = [
      gcloud-golang-for-go4
      oauth2
      net
      sys
    ];
    autoUpdatePath = "github.com/camlistore/go4";
  };

  goamz = buildFromGitHub {
    rev = "02d5144a587b982e33b95f484a34164ce6923c99";
    owner  = "goamz";
    repo   = "goamz";
    sha256 = "0nrw83ys5c9aiqxrangig7c0dk9xl41cqs9gskka9sk849fpl9f2";
    date = "2016-04-07";
    goPackageAliases = [
      "github.com/mitchellh/goamz"
    ];
    buildInputs = [
      check-v1
      go-ini
      go-simplejson
      sets
    ];
  };

  goautoneg = buildGoPackage rec {
    name = "goautoneg-2012-07-07";
    goPackagePath = "bitbucket.org/ww/goautoneg";
    rev = "75cd24fc2f2c2a2088577d12123ddee5f54e0675";

    src = fetchFromBitbucket {
      inherit rev;
      owner  = "ww";
      repo   = "goautoneg";
      sha256 = "9acef1c250637060a0b0ac3db033c1f679b894ef82395c15f779ec751ec7700a";
    };

    meta.autoUpdate = false;
  };

  gocapability = buildFromGitHub {
    rev = "2c00daeb6c3b45114c80ac44119e7b8801fdd852";
    owner = "syndtr";
    repo = "gocapability";
    sha256 = "0kwcqvj2fq6wl453hcc3q4fmyrv3yk9m3igxwksx9rmpnzaclz8r";
    date = "2015-07-16";
  };

  gocql = buildFromGitHub {
    rev = "b7b8a0e04b0cb0ca0b379421c58ec6fab9939b85";
    owner  = "gocql";
    repo   = "gocql";
    sha256 = "0ypkjl63xjw4r618dr94p8c1sccnw09bb1x7h124s916q9j9p3vp";
    propagatedBuildInputs = [ inf snappy hailocab_go-hostpool net ];
    date = "2016-05-25";
  };

  goconvey = buildGoPackage rec {
    version = "1.5.0";
    name = "goconvey-${version}";
    goPackagePath = "github.com/smartystreets/goconvey";
    src = fetchurl {
      name = "${name}.tar.gz";
      url = "https://github.com/smartystreets/goconvey/archive/${version}.tar.gz";
      sha256 = "0g3965cb8kg4kf9b0klx4pj9ycd7qwbw1jqjspy6i5d4ccd6mby4";
    };
    buildInputs = [ oglematchers ];
    doCheck = false; # please check again
  };

  gojsonpointer = buildFromGitHub {
    rev = "e0fe6f68307607d540ed8eac07a342c33fa1b54a";
    owner  = "xeipuuv";
    repo   = "gojsonpointer";
    sha256 = "1gm1m5vf1nkg87qhskpqfyg9r8n0fy74nxvp6ajcqb04v3k8sd7v";
    date = "2015-10-27";
  };

  gojsonreference = buildFromGitHub {
    rev = "e02fc20de94c78484cd5ffb007f8af96be030a45";
    owner  = "xeipuuv";
    repo   = "gojsonreference";
    sha256 = "1c2yhjjxjvwcniqag9i5p159xsw4452vmnc2nqxnfsh1whd8wpi5";
    date = "2015-08-08";
    propagatedBuildInputs = [ gojsonpointer ];
  };

  gojsonschema = buildFromGitHub {
    rev = "d5336c75940ef31c9ceeb0ae64cf92944bccb4ee";
    owner  = "xeipuuv";
    repo   = "gojsonschema";
    sha256 = "0qym7qakr4ibwqfw43gjz43ks9g3q8k7dyr0m9lhpc7pqr1py2sj";
    date = "2016-05-07";
    propagatedBuildInputs = [ gojsonreference ];
  };

  govers = buildFromGitHub {
    rev = "3b5f175f65d601d06f48d78fcbdb0add633565b9";
    date = "2015-01-09";
    owner = "rogpeppe";
    repo = "govers";
    sha256 = "1ir47942q9z6h5cajn84hvibhxicq93yrrgd36bagkibi4b2s5qf";
    dontRenameImports = true;
  };

  golang-lru = buildFromGitHub {
    date = "2016-02-07";
    rev = "a0d98a5f288019575c6d1f4bb1573fef2d1fcdc4";
    owner  = "hashicorp";
    repo   = "golang-lru";
    sha256 = "1q4cvlrk1pzki8lkf8b5mc3ciini8b6dlljrijycdh7izfc17vsz";
  };

  golang-petname = buildFromGitHub {
    rev = "2182cecef7f257230fc998bc351a08a5505f5e6c";
    owner  = "dustinkirkland";
    repo   = "golang-petname";
    sha256 = "0404sq4sn06f44nkw5g31qz8rywcdlhsbah3jgx64qby5826y1i5";
    date = "2016-02-01";
  };

  golang_protobuf_extensions = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "matttproud";
    repo   = "golang_protobuf_extensions";
    sha256 = "0r1sv4jw60rsxy5wlnr524daixzmj4n1m1nysv4vxmwiw9mbr6fm";
    buildInputs = [ protobuf ];
  };

  goleveldb = buildFromGitHub {
    rev = "fa5b5c78794bc5c18f330361059f871ae8c2b9d6";
    date = "2016-06-08";
    owner = "syndtr";
    repo = "goleveldb";
    sha256 = "19y1k0xmkpg31nfisf9nhx1dl21y4ivfgs33pipvqza0b71sa8zn";
    propagatedBuildInputs = [ ginkgo gomega snappy ];
  };

  gomega = buildFromGitHub {
    rev = "c73e51675ad2455a4515b6213eb7145eaade4824";
    owner  = "onsi";
    repo   = "gomega";
    sha256 = "1fiv3vslwmvrj0hmq6ywa6zc3285qvyadr69dcxscbnf9gfzkcfx";
    propagatedBuildInputs = [
      protobuf
      yaml-v2
    ];
    date = "2016-05-16";
  };

  google-api-go-client = buildFromGitHub {
    rev = "63ade871fd3aec1225809d496e81ec91ab76ea29";
    date = "2016-05-31";
    owner = "google";
    repo = "google-api-go-client";
    sha256 = "11m3gpacaqznzrfiss0vgpcm75kw08bb29flzra7lzw7i92k0jvw";
    goPackagePath = "google.golang.org/api";
    goPackageAliases = [
      "github.com/google/google-api-client"
    ];
    buildInputs = [
      net
    ];
  };

  gopass = buildFromGitHub {
    date = "2016-03-03";
    rev = "66487b23f2880ba32e185121d2cd51a338ea069a";
    owner = "howeyc";
    repo = "gopass";
    sha256 = "0r4kx80hq48fkipz4x7hkiqb74hygpja1h5xbzydaw4cdgc5vwjs";
    propagatedBuildInputs = [ crypto ];
  };

  gopsutil = buildFromGitHub {
    rev = "1.0.0";
    owner  = "shirou";
    repo   = "gopsutil";
    sha256 = "76f0b4db2d01c2f4c13cb6cecb56c6176b64702c4d1ae40be117f0753d984a85";
  };

  goskiplist = buildFromGitHub {
    rev = "2dfbae5fcf46374f166f8969cb07e167f1be6273";
    owner  = "ryszard";
    repo   = "goskiplist";
    sha256 = "1dr6n2w5ikdddq9c1fwqnc0m383p73h2hd04302cfgxqbnymabzq";
    date = "2015-03-12";
  };

  govalidator = buildFromGitHub {
    rev = "df81827fdd59d8b4fb93d8910b286ab7a3919520";
    owner = "asaskevich";
    repo = "govalidator";
    sha256 = "0bhnv6fd6msyi7y258jkrqr28gmnc34aj5fxii85494di8g2ww5z";
    date = "2016-05-19";
  };

  go-base58 = buildFromGitHub {
    rev = "1.0.0";
    owner  = "jbenet";
    repo   = "go-base58";
    sha256 = "0sbss2611iri3mclcz3k9b7kw2sqgwswg4yxzs02vjk3673dcbh2";
  };

  go-bencode = buildGoPackage rec {
    version = "1.1.1";
    name = "go-bencode-${version}";
    goPackagePath = "github.com/ehmry/go-bencode";

    src = fetchurl {
      url = "https://${goPackagePath}/archive/v${version}.tar.gz";
      sha256 = "0y2kz2sg1f7mh6vn70kga5d0qhp04n01pf1w7k6s8j2nm62h24j6";
    };
  };

  go-bindata-assetfs = buildFromGitHub {
    rev = "57eb5e1fc594ad4b0b1dbea7b286d299e0cb43c2";
    owner   = "elazarl";
    repo    = "go-bindata-assetfs";
    sha256 = "0kr3jz9lfivm0q9lsl6zpa4i02qa79304kn059skr0dnsnizj2q7";
    date = "2015-12-24";
  };

  go-checkpoint = buildFromGitHub {
    date = "2015-10-22";
    rev = "e4b2dc34c0f698ee04750bf2035d8b9384233e1b";
    owner  = "hashicorp";
    repo   = "go-checkpoint";
    sha256 = "1lnwx8c6ny3d2smj6ap4ar0d3i7fzjbi0mhmrnpmyln0anrp4yd4";
    buildInputs = [ go-cleanhttp ];
  };

  go-cleanhttp = buildFromGitHub {
    date = "2016-04-07";
    rev = "ad28ea4487f05916463e2423a55166280e8254b5";
    owner = "hashicorp";
    repo = "go-cleanhttp";
    sha256 = "1knpnv6wg2fnnsk2h2bj4m003f7xsvwm58vnn9gc753mbr78vx00";
  };

  go-colorable = buildFromGitHub {
    rev = "v0.0.5";
    owner  = "mattn";
    repo   = "go-colorable";
    sha256 = "1cj5wp5b0c5xg6hd5v9207b47aysji2zyg7zcs3z4rimzhnlbbnc";
  };

  go-difflib = buildFromGitHub {
    date = "2016-01-10";
    rev = "792786c7400a136282c1664665ae0a8db921c6c2";
    owner  = "pmezard";
    repo   = "go-difflib";
    sha256 = "0xhjjfvx97zkms5004v1k3prc5g1kljiayhf05v0n0yf89s5r28r";
  };

  go-dockerclient = buildFromGitHub {
    date = "2016-06-02";
    rev = "9df1f25d542e79d7909ef321b5c13c5d34ea7f1d";
    owner = "fsouza";
    repo = "go-dockerclient";
    sha256 = "1lxkw2y4z42zvkkpz71ddadv1x86phavyiba845xyqrscd841hr5";
    propagatedBuildInputs = [
      docker_for_go-dockerclient
      go-cleanhttp
      mux
    ];
  };

  go-flags = buildFromGitHub {
    date = "2016-05-28";
    rev = "b9b882a3990882b05e02765f5df2cd3ad02874ee";
    owner  = "jessevdk";
    repo   = "go-flags";
    sha256 = "02wzy17cl9v91ssmidqgvsk82dgg0iskd12h8dkp1ya1f9cvn7rj";
  };

  go-getter = buildFromGitHub {
    rev = "3d6040e1c4b972f6634c5aafb08901f916c5ee3c";
    date = "2016-06-03";
    owner = "hashicorp";
    repo = "go-getter";
    sha256 = "0msy19c1gnrqbfrg2yc298ysdy8fiw6q2j6db35cm9698bcfc078";
    buildInputs = [ aws-sdk-go ];
  };

  go-git-ignore = buildFromGitHub {
    rev = "228fcfa2a06e870a3ef238d54c45ea847f492a37";
    date = "2016-01-15";
    owner = "sabhiram";
    repo = "go-git-ignore";
    sha256 = "1a78b1as3xd2v3lawrb0y43bm3rmb452mysvzqk1309gw51lk4gx";
  };

  go-github = buildFromGitHub {
    date = "2016-05-09";
    rev = "c2beba44cffbb17740cc3ad8d54f2b303060027b";
    owner = "google";
    repo = "go-github";
    sha256 = "19q906fcdxxvrd4jgk8qcj3c0v6cy97dg170l5289619xlng89n8";
    buildInputs = [ oauth2 ];
    propagatedBuildInputs = [ go-querystring ];
  };

  go-homedir = buildFromGitHub {
    date = "2016-06-05";
    rev = "1111e456ffea841564ac0fa5f69c26ef44dafec9";
    owner  = "mitchellh";
    repo   = "go-homedir";
    sha256 = "0hcvxki0ckx55xxkygj5j9s1f5p7mv5wx0kcd6s96cnfi87pd02c";
  };

  hailocab_go-hostpool = buildFromGitHub {
    rev = "e80d13ce29ede4452c43dea11e79b9bc8a15b478";
    date = "2016-01-25";
    owner  = "hailocab";
    repo   = "go-hostpool";
    sha256 = "06ic8irabl0iwhmkyqq4wzq1d4pgp9vk1kmflgv1wd5d9q8qmkgf";
  };

  go-humanize = buildFromGitHub {
    rev = "499693e27ee0d14ffab67c31ad065fdb3d34ea75";
    owner = "dustin";
    repo = "go-humanize";
    sha256 = "1f04fk2lavjlhfyz683djskhcvv43lsv4rgapraz8jf5g9jx9fbn";
    date = "2016-06-02";
  };

  go-immutable-radix = buildFromGitHub {
    date = "2016-06-08";
    rev = "afc5a0dbb18abdf82c277a7bc01533e81fa1d6b8";
    owner = "hashicorp";
    repo = "go-immutable-radix";
    sha256 = "1yyhag8vnr7vi4ak2rkd651k9h8221dpdsqpva95zvf9nycgzlsd";
    propagatedBuildInputs = [ golang-lru ];
  };

  go-ini = buildFromGitHub {
    rev = "a98ad7ee00ec53921f08832bc06ecf7fd600e6a1";
    owner = "vaughan0";
    repo = "go-ini";
    sha256 = "07i40hj47z5m6wa5bzy7sc2na3hbwh84ridl40yfybgdlyrzdkf4";
    date = "2013-09-23";
  };

  go-ipfs-api = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "ipfs";
    repo   = "go-ipfs-api";
    sha256 = "0c54r9g10rcnrm9rzj815gjkcgmr5z3pjgh3b4b19vbsgm2rx7hf";
    excludedPackages = "tests";
    propagatedBuildInputs = [ go-multiaddr-net go-multipart-files tar-utils ];
  };

  go-isatty = buildFromGitHub {
    rev = "v0.0.1";
    owner  = "mattn";
    repo   = "go-isatty";
    sha256 = "0ynlb7bh0c6jfcx1d5hsv3zga56x049akdv8cf7hpfsrzkzcqwx8";
  };

  go-jmespath = buildFromGitHub {
    rev = "0.2.2";
    owner = "jmespath";
    repo = "go-jmespath";
    sha256 = "141a1i19fbmcf8qsz88kfb34vvmqpz5ya6hqz9r4v92by840xczi";
  };

  go-jose = buildFromGitHub {
    rev = "v1.0.2";
    owner = "square";
    repo = "go-jose";
    sha256 = "0pp117a464kj8br9pqk9xha87plndfg8mhfc9k1bq0v4qs7awyiq";
    goPackagePath = "gopkg.in/square/go-jose.v1";
    goPackageAliases = [
      "github.com/square/go-jose"
    ];
    buildInputs = [
      codegangsta-cli
      kingpin-v2
    ];
  };

  go-lxc-v2 = buildFromGitHub {
    rev = "8f9e220b36393c03854c2d224c5a55644b13e205";
    owner  = "lxc";
    repo   = "go-lxc";
    sha256 = "16ka135074r3i89fiwjhhrmidzfv8kv5hqk2rnhbq9mcrsv138ms";
    goPackagePath = "gopkg.in/lxc/go-lxc.v2";
    buildInputs = [ pkgs.lxc ];
    date = "2016-05-31";
  };

  go-lz4 = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "bkaradzic";
    repo   = "go-lz4";
    sha256 = "1bdh2wqp2hh81x00wmsb4px9fzj13jcrdl6w52pabqkr2wyyqwkf";
  };

  go-md2man = buildFromGitHub {
    owner = "cpuguy83";
    repo = "go-md2man";
    rev = "v1.0.5";
    sha256 = "9da2292b250e3181d176520c9fc127fcd3441f6bebe79a80f9d32991800c791a";
    propagatedBuildInputs = [
      blackfriday
    ];
  };

  go-memdb = buildFromGitHub {
    date = "2016-03-01";
    rev = "98f52f52d7a476958fa9da671354d270c50661a7";
    owner = "hashicorp";
    repo = "go-memdb";
    sha256 = "07938b1ln4x7caflhgsvaw8kikh5xcddwrc6zj0hcmzmbpfpyxai";
    buildInputs = [ go-immutable-radix ];
  };

  rcrowley_go-metrics = buildFromGitHub {
    rev = "eeba7bd0dd01ace6e690fa833b3f22aaec29af43";
    date = "2016-02-25";
    owner = "rcrowley";
    repo = "go-metrics";
    sha256 = "0xph1i8ml681xnh9qy3prvbrgzwb0sssaxlqz2yk1p6fczvq9210";
    propagatedBuildInputs = [ stathat ];
  };

  armon_go-metrics = buildFromGitHub {
    date = "2016-05-20";
    rev = "fbf75676ee9c0a3a23eb0a4d9220a3612cfbd1ed";
    owner = "armon";
    repo = "go-metrics";
    sha256 = "0wrkka9y0w8arfy08aghawwxxj36cgm6i0dw9ri6vhbb821nfar0";
    propagatedBuildInputs = [ prometheus_client_golang datadog-go ];
  };

  go-mssqldb = buildFromGitHub {
    rev = "e291d7fd2204827b9964304c46ec21c330573faf";
    owner = "denisenkom";
    repo = "go-mssqldb";
    sha256 = "0slr7wg6mnv3bcii76wp36grwaqa48p6nkgafp7kk16l0m63lnbi";
    date = "2016-06-07";
    buildInputs = [ crypto ];
  };

  go-multiaddr = buildFromGitHub {
    rev = "f3dff105e44513821be8fbe91c89ef15eff1b4d4";
    date = "2016-05-09";
    owner  = "jbenet";
    repo   = "go-multiaddr";
    sha256 = "0qdma38d4bmib063hh899h2491kgzgg16kgqdvypncchawq8nqlj";
    propagatedBuildInputs = [
      go-multihash
    ];
  };

  go-multiaddr-net = buildFromGitHub {
    rev = "d4cfd691db9f50e430528f682ca603237b0eaae0";
    owner  = "jbenet";
    repo   = "go-multiaddr-net";
    sha256 = "0nwqaqfn30qxhwa0v2sbxankkj41krbwd30bp92y0xrkz5ivvi16";
    date = "2016-05-16";
    propagatedBuildInputs = [
      go-multiaddr
      utp
    ];
  };

  go-multierror = buildFromGitHub {
    date = "2015-09-16";
    rev = "d30f09973e19c1dfcd120b2d9c4f168e68d6b5d5";
    owner  = "hashicorp";
    repo   = "go-multierror";
    sha256 = "0l1410m98pklnqkr6fqi2bpcqfag5z1l3snykn46ps38lb1sc3f3";
    propagatedBuildInputs = [ errwrap ];
  };

  go-multihash = buildFromGitHub {
    rev = "e8d2374934f16a971d1e94a864514a21ac74bf7f";
    owner  = "jbenet";
    repo   = "go-multihash";
    sha256 = "0ks70g7fg8vr17wmgcivp3x307yyr646s00iwl2p625ardcfh3wv";
    propagatedBuildInputs = [ go-base58 crypto ];
    date = "2015-04-12";
  };

  go-multipart-files = buildFromGitHub {
    rev = "3be93d9f6b618f2b8564bfb1d22f1e744eabbae2";
    owner  = "whyrusleeping";
    repo   = "go-multipart-files";
    sha256 = "0fdzi6v6rshh172hzxf8v9qq3d36nw3gc7g7d79wj88pinnqf5by";
    date = "2015-09-03";
  };

  go-nat-pmp = buildFromGitHub {
    rev = "452c97607362b2ab5a7839b8d1704f0396b640ca";
    owner  = "AudriusButkevicius";
    repo   = "go-nat-pmp";
    sha256 = "0jjwqvanxxs15nhnkdx0mybxnyqm37bbg6yy0jr80czv623rp2bk";
    date = "2016-05-22";
    buildInputs = [
      gateway
    ];
  };

  go-ole = buildFromGitHub {
    rev = "v1.2.0";
    owner  = "go-ole";
    repo   = "go-ole";
    sha256 = "1bkvi5l2sshjrg1g9x1a4i337adrv1vhk8p1xrkx5z05nfwazvx0";
  };

  go-plugin = buildFromGitHub {
    rev = "8cf118f7a2f0c7ef1c82f66d4f6ac77c7e27dc12";
    date = "2016-06-07";
    owner  = "hashicorp";
    repo   = "go-plugin";
    sha256 = "1mgj52aml4l2zh101ksjxllaibd5r8h1gcgcilmb8p0c3xwf7lvq";
    buildInputs = [ yamux ];
  };

  go-querystring = buildFromGitHub {
    date = "2016-03-10";
    rev = "9235644dd9e52eeae6fa48efd539fdc351a0af53";
    owner  = "google";
    repo   = "go-querystring";
    sha256 = "0c0rmm98vz7sk7z6a1r07dp6jyb513cyr2y753sjpnyrc28xhdwg";
  };

  go-radix = buildFromGitHub {
    rev = "4239b77079c7b5d1243b7b4736304ce8ddb6f0f2";
    owner  = "armon";
    repo   = "go-radix";
    sha256 = "0b5vksrw462w1j5ipsw7fmswhpnwsnaqgp6klw714dc6ppz57aqv";
    date = "2016-01-15";
  };

  go-reap = buildFromGitHub {
    rev = "2d85522212dcf5a84c6b357094f5c44710441912";
    owner  = "hashicorp";
    repo   = "go-reap";
    sha256 = "0q90nf4mgvxb26vd7avs1mw1m9cb6x9mx6jnz4xsia71ghi3lj50";
    date = "2016-01-13";
    propagatedBuildInputs = [ sys ];
  };

  go-runewidth = buildFromGitHub {
    rev = "v0.0.1";
    owner = "mattn";
    repo = "go-runewidth";
    sha256 = "1sf0a2fbp2fp0lgizh2bjd3cgni35czvshx5clb2m6b604k7by9a";
  };

  go-simplejson = buildFromGitHub {
    rev = "v0.5.0";
    owner  = "bitly";
    repo   = "go-simplejson";
    sha256 = "09svnkziaffkbax5jjnjfd0qqk9cpai2gphx4ja78vhxdn4jpiw0";
  };

  go-spew = buildFromGitHub {
    rev = "5215b55f46b2b919f50a1df0eaa5886afe4e3b3d";
    date = "2015-11-05";
    owner  = "davecgh";
    repo   = "go-spew";
    sha256 = "1l4dg2xs0vj49gk0f5d4ij3hrwi72ay4w9a7xjkz1syg4qi9jy40";
  };

  go-sqlite3 = buildFromGitHub {
    rev = "38ee283dabf11c9cbdb968eebd79b1fa7acbabe6";
    date = "2016-05-14";
    owner  = "mattn";
    repo   = "go-sqlite3";
    sha256 = "0nwdi1m386p8wxdvnwzqr17dwsj6px5qnn9qy22n7nd2pv49m8hs";
  };

  go-syslog = buildFromGitHub {
    date = "2015-02-18";
    rev = "42a2b573b664dbf281bd48c3cc12c086b17a39ba";
    owner  = "hashicorp";
    repo   = "go-syslog";
    sha256 = "0zbnlz1l1f50k8wjn8pgrkzdhr6hq4rcbap0asynvzw89crh7h4g";
  };

  go-systemd = buildFromGitHub {
    rev = "6dc8b843c670f2027cc26b164935635840a40526";
    owner = "coreos";
    repo = "go-systemd";
    sha256 = "1sv852jl2qqb1vi3irf9k3rblli7nxggncawnhq9s1ryzdszz9xr";
    propagatedBuildInputs = [
      dbus
      pkg
      pkgs.systemd_lib
    ];
    date = "2016-06-07";
  };

  go-systemd_journal = buildFromGitHub {
    inherit (go-systemd) rev owner repo sha256 date;
    subPackages = [
      "journal"
    ];
  };

  go-units = buildFromGitHub {
    rev = "v0.3.0";
    owner = "docker";
    repo = "go-units";
    sha256 = "15gnwpncr6ibxrvnj76r6j4fyskdixhjf6nc8vaib8lhx360avqc";
  };

  hashicorp-go-uuid = buildFromGitHub {
    rev = "73d19cdc2bf00788cc25f7d5fd74347d48ada9ac";
    date = "2016-03-29";
    owner  = "hashicorp";
    repo   = "go-uuid";
    sha256 = "1c8z6g9fyhbn35ps6agyf25mhqpsdpgr6kp3rq4kw2rsal6n8lqa";
  };

  go-version = buildFromGitHub {
    rev = "0181db47023708a38c2d20d2fe25a5fa034d5743";
    owner  = "hashicorp";
    repo   = "go-version";
    sha256 = "04kryh7dmz8zwd2kdma119fg6ydw2gm9zr041i8hr6dnjvrrp177";
    date = "2016-05-19";
  };

  go-zookeeper = buildFromGitHub {
    rev = "4b20de542e40ed2b89d65ae195fc20a330919b92";
    date = "2016-05-31";
    owner  = "samuel";
    repo   = "go-zookeeper";
    sha256 = "0qhm2bn9idjg02vdjdcnlij69ag4wc3d5vcm6pcra989hiqllqb1";
  };

  gohtml = buildFromGitHub {
    owner = "yosssi";
    repo = "gohtml";
    rev = "ccf383eafddde21dfe37c6191343813822b30e6b";
    date = "2015-09-22";
    sha256 = "c0ae0c2fb29dd7ea2b6235efd06b2cadbcd0142a04b969b70ed8c4a3055eefb4";
    propagatedBuildInputs = [
      net
    ];
  };

  goquery = buildGoPackage rec {
    rev = "0.0.1"; #tag v.0.3.2
    name = "goquery-${stdenv.lib.strings.substring 0 7 rev}";
    goPackagePath = "github.com/PuerkitoBio/goquery";
    propagatedBuildInputs = [ cascadia net ];
    buildInputs = [ cascadia net ];
    doCheck = true;
    src = fetchFromGitHub {
      inherit rev;
      owner = "PuerkitoBio";
      repo = "goquery";
      sha256 = "0bskm3nja1v3pmg7g8nqjkmpwz5p72h1h81y076x1z17zrjaw585";
    };
  };

  groupcache = buildFromGitHub {
    date = "2016-05-15";
    rev = "02826c3e79038b59d737d3b1c0a1d937f71a4433";
    owner  = "golang";
    repo   = "groupcache";
    sha256 = "093p9jiid2c03d02g8fada7bl05244caddd7qjmjs0ggsrardc46";
    buildInputs = [ protobuf ];
  };

  grpc = buildFromGitHub {
    rev = "88aeffff979aa77aa502cb011423d0a08fa12c5a";
    date = "2016-06-10";
    owner = "grpc";
    repo = "grpc-go";
    sha256 = "0k4w066qsh40hrw1d281is8dz31qhz00gm645jz50iqc0r7ghsah";
    goPackagePath = "google.golang.org/grpc";
    goPackageAliases = [ "github.com/grpc/grpc-go" ];
    propagatedBuildInputs = [ http2 net protobuf oauth2 glog ];
    excludedPackages = "\\(test\\|benchmark\\)";
  };

  gucumber = buildFromGitHub {
    date = "2016-05-11";
    rev = "5692705bb5ff96c5d7b33819b4739715008cc635";
    owner = "lsegal";
    repo = "gucumber";
    sha256 = "19hvwz21rmfkhxjdhj6jwjk0fmjwwa1yyfgvz9xyp7gi3fcnvnhy";
    buildInputs = [ testify ];
    propagatedBuildInputs = [ ansicolor ];
  };

  gx = buildFromGitHub {
    rev = "v0.7.0";
    owner = "whyrusleeping";
    repo = "gx";
    sha256 = "0c5nwmza4c07rh3j02bxgy7cqa8hc3gr5a1zhn150v15fix75l9l";
    propagatedBuildInputs = [
      go-homedir
      go-multiaddr
      go-multihash
      go-multiaddr-net
      semver
      go-git-ignore
      stump
      codegangsta-cli
      go-ipfs-api
    ];
    excludedPackages = [
      "tests"
    ];
  };

  gx-go = buildFromGitHub {
    rev = "v1.2.0";
    owner = "whyrusleeping";
    repo = "gx-go";
    sha256 = "008yfrax1kd9r63rqdi9fcqhy721bjq63d4ypm5d4nn0fbychg4s";
    buildInputs = [
      codegangsta-cli
      fs
      gx
      stump
    ];
  };

  hashstructure = buildFromGitHub {
    date = "2016-06-09";
    rev = "b098c52ef6beab8cd82bc4a32422cf54b890e8fa";
    owner  = "mitchellh";
    repo   = "hashstructure";
    sha256 = "0zg0q20hzg92xxsfsf2vn1kq044j8l7dh82fm7w7iyv03nwq0cxc";
  };

  hcl = buildFromGitHub {
    date = "2016-04-26";
    rev = "9a905a34e6280ce905da1a32344b25e81011197a";
    owner  = "hashicorp";
    repo   = "hcl";
    sha256 = "0pjyhr68pisdw6ziglskz26ql0r3ixmlsnv296bvxzfh6a46v80c";
  };

  hil = buildFromGitHub {
    date = "2016-04-08";
    rev = "6215360e5247e7c4bdc317a5f95e3fa5f084a33b";
    owner  = "hashicorp";
    repo   = "hil";
    sha256 = "6b3ab530f6980279edb5a1994226adefc377b70aa3e993b5d29c7d498d5cdbd4";
    propagatedBuildInputs = [
      mapstructure
      reflectwalk
    ];
  };

  http2 = buildFromGitHub rec {
    rev = "aa7658c0e9902e929a9ed0996ef949e59fc0f3ab";
    owner = "bradfitz";
    repo = "http2";
    sha256 = "0hzmrc9vfh83s57cvfhi26zgvwmr38yg2xxw1yhygfxn3x8ri05c";
    buildInputs = [ crypto ];
    date = "2016-01-16";
  };

  httprouter = buildFromGitHub {
    rev = "77366a47451a56bb3ba682481eed85b64fea14e8";
    owner  = "julienschmidt";
    repo   = "httprouter";
    sha256 = "12hj2pc07nzha56rcpq6js0j7gs207blasxrixbwcwcgy9pamc80";
    date = "2016-02-19";
  };

  hugo = buildFromGitHub {
    owner = "spf13";
    repo = "hugo";
    rev = "v0.16";
    sha256 = "c7234e7d3c747cd7fcf6050a04e411935d959b977a5dbc88a151eb5672f59339";
    buildInputs = [
      ace
      afero
      amber
      blackfriday
      cast
      cobra
      cssmin
      emoji
      fsnotify
      fsync
      inflect
      jwalterweatherman
      mapstructure
      mmark
      nitro
      osext
      pflag
      purell
      text
      toml
      viper
      websocket
      yaml-v2
    ];
  };

  inf = buildFromGitHub {
    rev = "v0.9.0";
    owner  = "go-inf";
    repo   = "inf";
    sha256 = "0wqf867vifpfa81a1vhazjgfjjhiykqpnkblaxxj6ppyxlzrs3cp";
    goPackagePath = "gopkg.in/inf.v0";
    goPackageAliases = [ "github.com/go-inf/inf" ];
  };

  inflect = buildFromGitHub {
    owner = "bep";
    repo = "inflect";
    rev = "b896c45f5af983b1f416bdf3bb89c4f1f0926f69";
    date = "2016-05-08";
    sha256 = "8dc92f6a2b75f0d1e38d7fb7ac2be79878f6e05c316ee474a665fd860ccccf05";
  };

  ini = buildFromGitHub {
    rev = "v1.12.0";
    owner  = "go-ini";
    repo   = "ini";
    sha256 = "0kh539ajs00ciiizf9dbf0244hfgwcflz1plk8prj4iw9070air7";
  };

  iter = buildFromGitHub {
    rev = "454541ec3da2a73fc34fd049b19ee5777bf19345";
    owner  = "bradfitz";
    repo   = "iter";
    sha256 = "0sv6rwr05v219j5vbwamfvpp1dcavci0nwr3a2fgxx98pjw7hgry";
    date = "2014-01-23";
  };

  flagfile = buildFromGitHub {
    date = "2015-02-13";
    rev = "871ce569c29360f95d7596f90aa54d5ecef75738";
    owner  = "spacemonkeygo";
    repo   = "flagfile";
    sha256 = "0s7g6xsv5y75gzky43065r7mfvdbgmmr6jv0w2b3nyir3z00frxn";
  };

  ipfs = buildFromGitHub {
    rev = "v0.4.2";
    owner = "ipfs";
    repo = "go-ipfs";
    sha256 = "0vpc8pisrv55n7g9yxz8lm7kn328ha3fqfsjsybjd9yxpv5wi7y9";
    gxSha256 = "049f1fq0lld0bq91cs4m6fw784jnarzsnghkvvgdral335xj7wrn";

    subPackages = [
      "cmd/ipfs"
    ];
  };

  jwalterweatherman = buildFromGitHub {
    owner = "spf13";
    repo = "jWalterWeatherman";
    rev = "33c24e77fb80341fe7130ee7c594256ff08ccc46";
    date = "2016-03-01";
    sha256 = "ac455d7b5001ddd0e384c36b2584c22fdca19d17df38603558a9f358ac8ed970";
    goPackageAliases = [
      "github.com/spf13/jwalterweatherman"
    ];
  };

  kingpin-v2 = buildFromGitHub {
    rev = "v2.1.11";
    owner = "alecthomas";
    repo = "kingpin";
    goPackagePath = "gopkg.in/alecthomas/kingpin.v2";
    sha256 = "0s3xz1pwqdfk466nk2qj1r5p1n9qh6y7ndik44yq56i5k3lxb9qg";
    propagatedBuildInputs = [
      template
      units
    ];
  };

  ldap = buildFromGitHub {
    rev = "v2.3.0";
    owner  = "go-ldap";
    repo   = "ldap";
    sha256 = "1iwapk3z1cz6q1a4hfyp857ny2skdjjx7hjhbcn6q5fd64ldpv8y";
    goPackageAliases = [
      "github.com/nmcclain/ldap"
      "github.com/vanackere/ldap"
    ];
    propagatedBuildInputs = [ asn1-ber ];
  };

  lego = buildFromGitHub {
    rev = "v0.3.1";
    owner = "xenolf";
    repo = "lego";
    sha256 = "12bry70rgdi0i9dybhaq1vfa83ac5cdka86652xry1j7a8gq0z76";

    buildInputs = [
      aws-sdk-go
      codegangsta-cli
      crypto
      dns
      weppos-dnsimple-go
      go-ini
      go-jose
      goamz
      google-api-go-client
      oauth2
      net
      vultr
    ];

    subPackages = [
      "."
    ];
  };

  log15-v2 = buildFromGitHub {
    rev = "v2.11";
    owner  = "inconshreveable";
    repo   = "log15";
    sha256 = "1krlgq3m0q40y8bgaf9rk7zv0xxx5z92rq8babz1f3apbdrn00nq";
    goPackagePath = "gopkg.in/inconshreveable/log15.v2";
    propagatedBuildInputs = [
      go-colorable
    ];
  };

  logrus = buildFromGitHub rec {
    rev = "v0.10.0";
    owner = "Sirupsen";
    repo = "logrus";
    sha256 = "1rf70m0r0x3rws8334rmhj8wik05qzxqch97c31qpfgcl96ibnfb";
  };

  logutils = buildFromGitHub {
    date = "2015-06-09";
    rev = "0dc08b1671f34c4250ce212759ebd880f743d883";
    owner  = "hashicorp";
    repo   = "logutils";
    sha256 = "11p4p01x37xcqzfncd0w151nb5izmf3sy77vdwy0dpwa9j8ccgmw";
  };

  luhn = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "calmh";
    repo   = "luhn";
    sha256 = "13brkbbmj9bh0b9j3avcyrj542d78l9hg3bxj7jjvkp5n5cxwp41";
  };

  lxd = buildFromGitHub {
    rev = "lxd-2.0.2";
    owner  = "lxc";
    repo   = "lxd";
    sha256 = "1d935hv0h48l9i5a023mkmy9jy0fg5i0nwq9gp3xfkqb8r3rjvq8";
    excludedPackages = "test"; # Don't build the binary called test which causes conflicts
    buildInputs = [
      crypto
      gettext
      gocapability
      golang-petname
      go-lxc-v2
      go-sqlite3
      go-systemd
      log15-v2
      pkgs.lxc
      mux
      pborman_uuid
      pongo2-v3
      protobuf
      tablewriter
      tomb-v2
      yaml-v2
      websocket
    ];
  };

  mathutil = buildFromGitHub {
    date = "2016-01-19";
    rev = "38a5fe05cd94d69433fd1c928417834c604f281d";
    owner = "cznic";
    repo = "mathutil";
    sha256 = "08z3ss9lw9r9mczba2dki1q0sa24gvvwg9ky9akgk045zpsx650b";
    buildInputs = [ bigfft ];
  };

  mapstructure = buildFromGitHub {
    date = "2016-02-11";
    rev = "d2dd0262208475919e1a362f675cfc0e7c10e905";
    owner  = "mitchellh";
    repo   = "mapstructure";
    sha256 = "1pmjkrlz0mvs90ysag12pp4sldhfm1m91472w50wjaqhda028ijh";
  };

  mdns = buildFromGitHub {
    date = "2015-12-05";
    rev = "9d85cf22f9f8d53cb5c81c1b2749f438b2ee333f";
    owner = "hashicorp";
    repo = "mdns";
    sha256 = "0hsbhh0v0jpm4cg3hg2ffi2phis4vq95vyja81rk7kzvml17pvag";
    propagatedBuildInputs = [ net dns ];
  };

  memberlist = buildFromGitHub {
    date = "2016-06-03";
    rev = "215aec831f03c9b7c61ac183d3e28fff3c7d3a37";
    owner = "hashicorp";
    repo = "memberlist";
    sha256 = "17136nhzjbr2bbccwxladkhrn2rfi5savqv1jgx70zny46nq8s5z";
    propagatedBuildInputs = [
      dns
      ugorji_go
      armon_go-metrics
      go-multierror
    ];
  };

  mgo = buildFromGitHub {
    rev = "r2016.02.04";
    owner = "go-mgo";
    repo = "mgo";
    sha256 = "0q968aml9p5x49x70ay7myfg6ibggckir3gam5n6qydj6rviqpy7";
    goPackagePath = "gopkg.in/mgo.v2";
    goPackageAliases = [ "github.com/go-mgo/mgo" ];
    buildInputs = [ pkgs.cyrus-sasl tomb-v2 ];
  };

  missinggo = buildFromGitHub {
    rev = "e40875155efce3d98562ca9e265e152c364ada3e";
    owner  = "anacrolix";
    repo   = "missinggo";
    sha256 = "0ph15im9qv4inny5vdiqcccfa5i5imckqn6h761bwlinazj5xz4i";
    date = "2016-05-31";
    propagatedBuildInputs = [
      b
      btree
      docopt-go
      envpprof
      goskiplist
      iter
      roaring
      tagflag
    ];
  };

  missinggo_lib = buildFromGitHub {
    inherit (missinggo) rev owner repo sha256 date;
    subPackages = [
      "."
    ];
    propagatedBuildInputs = [
      iter
    ];
  };

  mmark = buildFromGitHub {
    owner = "miekg";
    repo = "mmark";
    rev = "v1.3.4";
    sha256 = "7b4f3a9920c962b95304c639543cd7863c69c01c702781fbe6cc489290b1f656";
    buildInputs = [
      toml
    ];
  };

  mongo-tools = buildFromGitHub {
    rev = "r3.3.4";
    owner  = "mongodb";
    repo   = "mongo-tools";
    sha256 = "88a5ab20f2af8abcf80fdf726abcb775fd0d365b74fe4c8b96801639c093a1e0";
    buildInputs = [ crypto mgo go-flags gopass openssl tomb-v2 ];

    # Mongodb incorrectly names all of their binaries main
    # Let's work around this with our own installer
    preInstall = ''
      mkdir -p $bin/bin
      while read b; do
        rm -f go/bin/main
        go install $goPackagePath/$b/main
        cp go/bin/main $bin/bin/$b
      done < <(find go/src/$goPackagePath -name main | xargs dirname | xargs basename -a)
      rm -r go/bin
    '';
  };

  mow-cli = buildFromGitHub {
    rev = "772320464101e904cd51198160eb4d489be9cc49";
    owner  = "jawher";
    repo   = "mow.cli";
    sha256 = "1dwy7pwh3mig3xj1x8bcd8cm6ilv2581vah9rwi992agx3b8318s";
    date = "2016-02-21";
  };

  mux = buildFromGitHub {
    rev = "v1.1";
    owner = "gorilla";
    repo = "mux";
    sha256 = "1iicj9v3ippji2i1jf2g0jmrvql1k2yydybim3hsb0jashnq7794";
    propagatedBuildInputs = [ context ];
  };

  muxado = buildFromGitHub {
    date = "2014-03-12";
    rev = "f693c7e88ba316d1a0ae3e205e22a01aa3ec2848";
    owner  = "inconshreveable";
    repo   = "muxado";
    sha256 = "db9a65b811003bcb48d1acefe049bb12c8de232537cf07e1a4a949a901d807a2";
  };

  mysql = buildFromGitHub {
    rev = "3654d25ec346ee8ce71a68431025458d52a38ac0";
    owner  = "go-sql-driver";
    repo   = "mysql";
    sha256 = "17kw9n01zks3l76ybrdzib2x9bc1r6rsnnmyl8blw1w216bwd7bz";
    date = "2016-06-02";
  };

  net-rpc-msgpackrpc = buildFromGitHub {
    date = "2015-11-15";
    rev = "a14192a58a694c123d8fe5481d4a4727d6ae82f3";
    owner = "hashicorp";
    repo = "net-rpc-msgpackrpc";
    sha256 = "007pwdpap465b32cx1i2hmf2q67vik3wk04xisq2pxvqvx81irks";
    propagatedBuildInputs = [ ugorji_go go-multierror ];
  };

  netlink = buildFromGitHub {
    rev = "7995ff5647a22cbf0dc41bf5c0e977bdb0d5c6b7";
    owner  = "vishvananda";
    repo   = "netlink";
    sha256 = "0sammm1y2hnyp1cblp3asjmyfadl5sml3dna2sg7x0pchggd1x10";
    date = "2016-05-31";
    propagatedBuildInputs = [
      netns
    ];
  };

  netns = buildFromGitHub {
    rev = "8ba1072b58e0c2a240eb5f6120165c7776c3e7b8";
    owner  = "vishvananda";
    repo   = "netns";
    sha256 = "05r4qri45ngm40kp9qdbyqrs15gx7swjj27bmc7i04wg9yd65j95";
    date = "2016-04-30";
  };

  nitro = buildFromGitHub {
    owner = "spf13";
    repo = "nitro";
    rev = "24d7ef30a12da0bdc5e2eb370a79c659ddccf0e8";
    date = "2013-10-03";
    sha256 = "bffdb21463525c2e9ab628c32c3d994c24114d49c30619f20dacd374987276b5";
  };

  nomad = buildFromGitHub {
    rev = "v0.3.2";
    owner = "hashicorp";
    repo = "nomad";
    sha256 = "11n87z4f2y3s3fkf6xp41671m39fmn4b6lry4am9cqf0g2im46rh";

    buildInputs = [
      datadog-go wmi armon_go-metrics go-radix aws-sdk-go perks speakeasy
      bolt go-systemd go-units go-humanize go-dockerclient ini go-ole
      dbus protobuf cronexpr consul-api errwrap go-checkpoint go-cleanhttp
      go-getter go-immutable-radix go-memdb go-multierror go-syslog
      go-version golang-lru hcl logutils memberlist net-rpc-msgpackrpc raft
      raft-boltdb scada-client serf yamux syslogparser go-jmespath osext
      go-isatty golang_protobuf_extensions mitchellh-cli copystructure
      hashstructure mapstructure reflectwalk runc prometheus_client_golang
      prometheus_common prometheus_procfs columnize gopsutil ugorji_go sys
      go-plugin circbuf go-spew
    ];

    subPackages = [
      "."
    ];
  };

  objx = buildFromGitHub {
    date = "2015-09-28";
    rev = "1a9d0bb9f541897e62256577b352fdbc1fb4fd94";
    owner  = "stretchr";
    repo   = "objx";
    sha256 = "0ycjvfbvsq6pmlbq2v7670w1k25nydnz4scx0qgiv0f4llxnr0y9";
  };

  openssl = buildFromGitHub {
    date = "2015-03-30";
    rev = "4c6dbafa5ec35b3ffc6a1b1e1fe29c3eba2053ec";
    owner = "10gen";
    repo = "openssl";
    sha256 = "1yyq8acz9pb19mnr9j5hd0axpw6xlm8fbqnkp4m16mmfjd6l5kii";
    goPackageAliases = [ "github.com/spacemonkeygo/openssl" ];
    nativeBuildInputs = [ pkgs.pkgconfig ];
    buildInputs = [ pkgs.openssl ];
    propagatedBuildInputs = [ spacelog ];

    preBuild = ''
      find go/src/$goPackagePath -name \*.go | xargs sed -i 's,spacemonkeygo/openssl,10gen/openssl,g'
    '';
  };

  osext = buildFromGitHub {
    date = "2015-12-22";
    rev = "29ae4ffbc9a6fe9fb2bc5029050ce6996ea1d3bc";
    owner = "kardianos";
    repo = "osext";
    sha256 = "05803q7snh1pcwjs5f8g35wfhv21j0mp6yk9agmcx50rjcn3x6qr";
    goPackageAliases = [
      "github.com/bugsnag/osext"
      "bitbucket.org/kardianos/osext"
    ];
  };

  perks = buildFromGitHub rec {
    date = "2014-07-16";
    owner  = "bmizerany";
    repo   = "perks";
    rev = "d9a9656a3a4b1c2864fdb44db2ef8619772d92aa";
    sha256 = "1p5aay4x3q255vrdqv2jcl45acg61j3bz6xgljvqdhw798cyf6a3";
  };

  beorn7_perks = buildFromGitHub rec {
    date = "2016-02-29";
    owner  = "beorn7";
    repo   = "perks";
    rev = "3ac7bf7a47d159a033b107610db8a1b6575507a4";
    sha256 = "1swhv3v8vxgigldpgzzbqxmzdwpvjdii11a3xql677mfbvgv7mpq";
  };

  pflag = buildFromGitHub {
    owner = "spf13";
    repo = "pflag";
    rev = "cb88ea77998c3f024757528e3305022ab50b43be";
    date = "2016-03-16";
    sha256 = "beaca26d54399fe81ea5ef66ed71c90539c51079a81613bebcd2e55f2c4c4687";
  };

  pkg = buildFromGitHub rec {
    date = "2016-06-08";
    owner  = "coreos";
    repo   = "pkg";
    rev = "db59686ef7fbc1c63a2325fe702be75bcfe7eedf";
    sha256 = "1raswqh6j47ldabsgqg4mrwlj1c048kq222g94znmizpvmqm46gh";
    buildInputs = [
      crypto
      go-systemd_journal
      yaml-v1
    ];
  };

  pongo2-v3 = buildFromGitHub {
    rev = "v3.0";
    owner  = "flosch";
    repo   = "pongo2";
    sha256 = "1qjcj7hcjskjqp03fw4lvn1cwy78dck4jcd0rcrgdchis1b84isk";
    goPackagePath = "gopkg.in/flosch/pongo2.v3";
  };

  pq = buildFromGitHub {
    rev = "ee1442bda7bd1b6a84e913bdb421cb1874ec629d";
    owner  = "lib";
    repo   = "pq";
    sha256 = "0ds49x3glbxx3b1wycgn2vcalhqqv2vzhfv8r75bzb16snzpmy6x";
    date = "2016-05-10";
  };

  prometheus_client_golang = buildFromGitHub {
    rev = "488edd04dc224ba64c401747cd0a4b5f05dfb234";
    owner = "prometheus";
    repo = "client_golang";
    sha256 = "0fvsa9qg10cswzdal96w90gk96h96wdm8cji1rrdf83zccbr7src";
    propagatedBuildInputs = [
      goautoneg
      net
      protobuf
      prometheus_client_model
      prometheus_common_for_client
      prometheus_procfs
      beorn7_perks
    ];
    date = "2016-05-31";
  };

  prometheus_client_model = buildFromGitHub {
    rev = "fa8ad6fec33561be4280a8f0514318c79d7f6cb6";
    date = "2015-02-12";
    owner  = "prometheus";
    repo   = "client_model";
    sha256 = "150fqwv7lnnx2wr8v9zmgaf4hyx1lzd4i1677ypf6x5g2fy5hh6r";
    buildInputs = [
      protobuf
    ];
  };

  prometheus_common = buildFromGitHub {
    date = "2016-06-07";
    rev = "3a184ff7dfd46b9091030bf2e56c71112b0ddb0e";
    owner = "prometheus";
    repo = "common";
    sha256 = "1nvchgb0zirf22ywpsl63068nhrj19pr57xzrdsqg4nvz2sgdcb0";
    buildInputs = [ net prometheus_client_model httprouter logrus protobuf ];
    propagatedBuildInputs = [
      golang_protobuf_extensions
      prometheus_client_golang
    ];
  };

  prometheus_common_for_client = buildFromGitHub {
    inherit (prometheus_common) date rev owner repo sha256;
    subPackages = [
      "expfmt"
      "model"
      "internal/bitbucket.org/ww/goautoneg"
    ];
    propagatedBuildInputs = [
      golang_protobuf_extensions
      prometheus_client_model
      protobuf
    ];
  };

  prometheus_procfs = buildFromGitHub {
    rev = "abf152e5f3e97f2fafac028d2cc06c1feb87ffa5";
    date = "2016-04-11";
    owner  = "prometheus";
    repo   = "procfs";
    sha256 = "08536i8yaip8lv4zas4xa59igs4ybvnb2wrmil8rzk3a2hl9zck8";
  };

  properties = buildFromGitHub {
    owner = "magiconair";
    repo = "properties";
    rev = "v1.7.0";
    sha256 = "059d16df4de73d818e647127182629d251fdf71d1a110d4b91e3c15fdd594903";
  };

  purell = buildFromGitHub {
    owner = "PuerkitoBio";
    repo = "purell";
    rev = "1d5d1cfad45d42ec5f81fa8ef23de09cebc6dcc3";
    date = "2015-06-07";
    sha256 = "b2f08f8354c10ada86e67e29710de9862d5c2d282d7bd087f15bbf134f91a8b6";
    propagatedBuildInputs = [
      urlesc
    ];
  };

  qart = buildFromGitHub {
    rev = "0.1";
    owner  = "vitrun";
    repo   = "qart";
    sha256 = "02n7f1j42jp8f4nvg83nswfy6yy0mz2axaygr6kdqwj11n44rdim";
  };

  ql = buildFromGitHub {
    rev = "v1.0.3";
    owner  = "cznic";
    repo   = "ql";
    sha256 = "1r1370h0zpkhi9fs57vx621vsj8g9j0ijki0y4mpw18nz2mq620n";
    propagatedBuildInputs = [
      go4
      b
      exp
      strutil
    ];
  };

  raft = buildFromGitHub {
    date = "2016-06-03";
    rev = "4bcac2adb06930200744feb591fee8a0790f9c98";
    owner  = "hashicorp";
    repo   = "raft";
    sha256 = "06i42mcm12fipxqblmamasxlhfgy8p179gb429wa7625icnh4cb1";
    propagatedBuildInputs = [ armon_go-metrics ugorji_go ];
  };

  raft-boltdb = buildFromGitHub {
    date = "2015-02-01";
    rev = "d1e82c1ec3f15ee991f7cc7ffd5b67ff6f5bbaee";
    owner  = "hashicorp";
    repo   = "raft-boltdb";
    sha256 = "07g818sprpnl0z15wl16wj9dvyl9igqaqa0w4y7mbfblnpydvgis";
    propagatedBuildInputs = [ bolt ugorji_go raft ];
  };

  ratelimit = buildFromGitHub {
    rev = "77ed1c8a01217656d2080ad51981f6e99adaa177";
    date = "2015-11-25";
    owner  = "juju";
    repo   = "ratelimit";
    sha256 = "0m7bvg8kg9ffl624lbcq47207n6r54z9by1wy0axslishgp1lh98";
  };

  raw = buildFromGitHub {
    rev = "724aedf6e1a5d8971aafec384b6bde3d5608fba4";
    owner  = "feyeleanor";
    repo   = "raw";
    sha256 = "0pkvvvln5cyyy0y2i82jv39gjnfgzpb5ih94iav404lfsachh8m1";
    date = "2013-03-27";
  };

  reflectwalk = buildFromGitHub {
    date = "2015-05-27";
    rev = "eecf4c70c626c7cfbb95c90195bc34d386c74ac6";
    owner  = "mitchellh";
    repo   = "reflectwalk";
    sha256 = "0zpapfp4vx9zr3zlw2405clgix7jzhhdphmsyhar4yhhs04fb3qz";
  };

  roaring = buildFromGitHub {
    rev = "v0.2.5";
    owner  = "RoaringBitmap";
    repo   = "roaring";
    sha256 = "1kc85xpk5p0fviywck9ci3i8nzsng34gx29i2j3322ax1nyj93ap";
  };

  runc = buildFromGitHub {
    rev = "v0.1.1";
    owner  = "opencontainers";
    repo   = "runc";
    sha256 = "4cf4042352f6a1cb21889dc5b7511b42f3808c7602c469e458a320e39d46a0b4";
    propagatedBuildInputs = [
      go-units
      logrus
      docker_for_runc
      go-systemd
      protobuf
      gocapability
      netlink
      codegangsta-cli
      runtime-spec
    ];
  };

  runtime-spec = buildFromGitHub {
    rev = "6de52a7d39c52a1e287182d0b4e6c03068236639";
    date = "2016-06-10";
    owner  = "opencontainers";
    repo   = "runtime-spec";
    sha256 = "aa192d6707e4828152cbd7ae4dbfa5b77764dacee76dac691e39640465568f0e";
    buildInputs = [
      gojsonschema
    ];
  };

  sanitized-anchor-name = buildFromGitHub {
    owner = "shurcooL";
    repo = "sanitized_anchor_name";
    rev = "10ef21a441db47d8b13ebcc5fd2310f636973c77";
    date = "2015-10-27";
    sha256 = "7c4e047c746e2336c6e8fca1dc827aec081632324ac96c6350204712526fb35e";
  };

  scada-client = buildFromGitHub {
    date = "2016-06-01";
    rev = "6e896784f66f82cdc6f17e00052db91699dc277d";
    owner  = "hashicorp";
    repo   = "scada-client";
    sha256 = "1by4kyd2hrrrghwj7snh9p8fdlqka24q9yr6nyja2acs2zpjgh7a";
    buildInputs = [ armon_go-metrics net-rpc-msgpackrpc yamux ];
  };

  semver = buildFromGitHub {
    rev = "v3.1.0";
    owner = "blang";
    repo = "semver";
    sha256 = "0s7pzm46x92fw63cfp8v7gjdwb5mpgsrxgp01mx2j5wvjw5ygppb";
  };

  serf = buildFromGitHub {
    rev = "v0.7.0";
    owner  = "hashicorp";
    repo   = "serf";
    sha256 = "1qzphmv2kci14v5xis08by1bhl09a3yhjy0glyh1wk0s96mx2d1b";

    buildInputs = [
      net circbuf armon_go-metrics ugorji_go go-syslog logutils mdns memberlist
      dns mitchellh-cli mapstructure columnize
    ];
  };

  sets = buildFromGitHub {
    rev = "6c54cb57ea406ff6354256a4847e37298194478f";
    owner  = "feyeleanor";
    repo   = "sets";
    sha256 = "11gg27znzsay5pn9wp7rl427v8bl1rsncyk8nilpsbpwfbz7q7vm";
    date = "2013-02-27";
    propagatedBuildInputs = [
      slices
    ];
  };

  sftp = buildFromGitHub {
    owner = "pkg";
    repo = "sftp";
    rev = "526cf9b2b38d2f3675e34e473f2cef38e1e0565b";
    date = "2016-05-30";
    sha256 = "c3c6026c2a4130bcb1c6939d17c89148d6d4d9a477c7384922df39d4b4b4a2b5";
    propagatedBuildInputs = [
      crypto
      errors
      fs
    ];
  };

  slices = buildFromGitHub {
    rev = "bb44bb2e4817fe71ba7082d351fd582e7d40e3ea";
    owner  = "feyeleanor";
    repo   = "slices";
    sha256 = "05i934pmfwjiany6r9jgp27nc7bvm6nmhflpsspf10d4q0y9x8zc";
    date = "2013-02-25";
    propagatedBuildInputs = [
      raw
    ];
  };

  sortutil = buildFromGitHub {
    date = "2015-06-17";
    rev = "4c7342852e65c2088c981288f2c5610d10b9f7f4";
    owner = "cznic";
    repo = "sortutil";
    sha256 = "11iykyi1d7vjmi7778chwbl86j6s1742vnd4k7n1rvrg7kq558xq";
  };

  spacelog = buildFromGitHub {
    date = "2016-06-06";
    rev = "f936fb050dc6b5fe4a96b485a6f069e8bdc59aeb";
    owner = "spacemonkeygo";
    repo = "spacelog";
    sha256 = "008npp1bdza55wqyv157xd1512xbpar6hmqhhs3bi5xh7xlwpswj";
    buildInputs = [ flagfile ];
  };

  speakeasy = buildFromGitHub {
    date = "2016-05-20";
    rev = "e1439544d8ecd0f3e9373a636d447668096a8f81";
    owner = "bgentry";
    repo = "speakeasy";
    sha256 = "1aks9mz0xrgxb9fvpf9pac104zwamzv2j53bdirgxsjn12904cqm";
  };

  stathat = buildFromGitHub {
    date = "2016-03-03";
    rev = "91dfa3a59c5b233fef9a346a1460f6e2bc889d93";
    owner = "stathat";
    repo = "go";
    sha256 = "1d9ahyn0w7n4kyn05b7hrm7gx9nj2rws4m6zg762v1wilq96d2nh";
  };

  structs = buildFromGitHub {
    date = "2016-06-01";
    rev = "5ada2f449b108d87dbd8c1e60c32cdd065c27886";
    owner  = "fatih";
    repo   = "structs";
    sha256 = "0y77w9w91w72i96d6myp8gv7dn3v49pi2w9d4qhv071iplfg8hzn";
  };

  stump = buildFromGitHub {
    date = "2015-11-05";
    rev = "bdc01b1f13fc5bed17ffbf4e0ed7ea17fd220ee6";
    owner = "whyrusleeping";
    repo = "stump";
    sha256 = "010lm1yr8pdnba5z2lbbwwqqf6i5bdwmm1vhbbq5375nmxxb4h6j";
  };

  strutil = buildFromGitHub {
    date = "2015-04-30";
    rev = "1eb03e3cc9d345307a45ec82bd3016cde4bd4464";
    owner = "cznic";
    repo = "strutil";
    sha256 = "0ipn9zaihxpzs965v3s8c9gm4rc4ckkihhjppchr3hqn2vxwgfj1";
  };

  suture = buildFromGitHub {
    rev = "v1.1.1";
    owner  = "thejerf";
    repo   = "suture";
    sha256 = "0hpi9swsln9nrj4c18hac8905g8nbgfd8arpi8v118pasx5pw2l0";
  };

  sync = buildFromGitHub {
    rev = "812602587b72df6a2a4f6e30536adc75394a374b";
    owner  = "anacrolix";
    repo   = "sync";
    sha256 = "10rk5fkchbmfzihyyxxcl7bsg6z0kybbjnn1f2jk40w18vgqk50r";
    date = "2015-10-30";
    buildInputs = [
      missinggo
    ];
  };

  syncthing = buildFromGitHub rec {
    rev = "v0.13.5";
    owner = "syncthing";
    repo = "syncthing";
    sha256 = "177z4x7q7ym1m9divvaskzgmka47mmcqff33qawvsirl3dkmn6pn";
    buildFlags = [ "-tags noupgrade" ];
    buildInputs = [
      go-lz4 du luhn xdr snappy ratelimit osext
      goleveldb suture qart crypto net text rcrowley_go-metrics
      go-nat-pmp glob gateway ql groupcache pq
    ];
    postPatch = ''
      # Mostly a cosmetic change
      sed -i 's,unknown-dev,${rev},g' cmd/syncthing/main.go
    '';
    preBuild = ''
      pushd go/src/$goPackagePath
      go run script/genassets.go gui > lib/auto/gui.files.go
      popd
    '';
  };

  syncthing-lib = buildFromGitHub {
    inherit (syncthing) rev owner repo sha256;
    subPackages = [
      "lib/sync"
      "lib/logger"
      "lib/protocol"
      "lib/osutil"
      "lib/tlsutil"
      "lib/dialer"
      "lib/relay/client"
      "lib/relay/protocol"
    ];
    propagatedBuildInputs = [ go-lz4 luhn xdr text suture du net ];
  };

  syslogparser = buildFromGitHub {
    rev = "ff71fe7a7d5279df4b964b31f7ee4adf117277f6";
    date = "2015-07-17";
    owner  = "jeromer";
    repo   = "syslogparser";
    sha256 = "1x1nq7kyvmfl019d3rlwx9nqlqwvc87376mq3xcfb7f5vxlmz9y5";
  };

  tablewriter = buildFromGitHub {
    rev = "8d0265a48283795806b872b4728c67bf5c777f20";
    date = "2016-05-27";
    owner  = "olekukonko";
    repo   = "tablewriter";
    sha256 = "10asls1x37b0qibj850y6940rx7bhr20qvbcihcwn162qa50qlh0";
    propagatedBuildInputs = [
      go-runewidth
    ];
  };

  tagflag = buildFromGitHub {
    rev = "b4e0d6bdcd327e72ac967a672213c45c36fa9735";
    date = "2016-05-11";
    owner  = "anacrolix";
    repo   = "tagflag";
    sha256 = "1m1qjwlb4w9fvvxd2bbbm2ypvqbdlmrw2smqmc36vv8bw8gi6wcp";
    propagatedBuildInputs = [
      go-humanize
      missinggo_lib
      xstrings
    ];
  };

  tar-utils = buildFromGitHub {
    rev = "beab27159606f5a7c978268dd1c3b12a0f1de8a7";
    date = "2016-03-22";
    owner  = "whyrusleeping";
    repo   = "tar-utils";
    sha256 = "0p0cmk30b22bgfv4m29nnk2359frzzgin2djhysrqznw3wjpn3nz";
  };

  template = buildFromGitHub {
    rev = "a0175ee3bccc567396460bf5acd36800cb10c49c";
    owner = "alecthomas";
    repo = "template";
    sha256 = "10albmv2bdrrgzzqh1rlr88zr2vvrabvzv59m15wazwx39mqzd7p";
    date = "2016-04-05";
  };

  testify = buildFromGitHub {
    rev = "v1.1.3";
    owner = "stretchr";
    repo = "testify";
    sha256 = "12r2v07zq22bk322hn8dn6nv1fg04wb5pz7j7bhgpq8ji2sassdp";
    propagatedBuildInputs = [ objx go-difflib go-spew ];
  };

  tokenbucket = buildFromGitHub {
    rev = "c5a927568de7aad8a58127d80bcd36ca4e71e454";
    date = "2013-12-01";
    owner = "ChimeraCoder";
    repo = "tokenbucket";
    sha256 = "11zasaakzh4fzzmmiyfq5mjqm5md5bmznbhynvpggmhkqfbc28gz";
  };

  tomb-v2 = buildFromGitHub {
    date = "2014-06-26";
    rev = "14b3d72120e8d10ea6e6b7f87f7175734b1faab8";
    owner = "go-tomb";
    repo = "tomb";
    sha256 = "1ixpcahm1j5s9rv52al1k8047hsv7axxqvxcpdpa0lr70b33n45f";
    goPackagePath = "gopkg.in/tomb.v2";
    goPackageAliases = [ "github.com/go-tomb/tomb" ];
  };

  toml = buildFromGitHub {
    owner = "BurntSushi";
    repo = "toml";
    rev = "v0.2.0";
    sha256 = "bc57e22177107f0ec08305aed9a5aca41b4a3a5c37fef63cbb4c1fd1738910eb";
  };

  units = buildFromGitHub {
    rev = "2efee857e7cfd4f3d0138cc3cbb1b4966962b93a";
    owner = "alecthomas";
    repo = "units";
    sha256 = "1jj055kgx6mfx5zw263ci70axk3z5006db74dqhcilxwk1a2ga23";
    date = "2015-10-22";
  };

  urlesc = buildFromGitHub {
    owner = "PuerkitoBio";
    repo = "urlesc";
    rev = "5fa9ff0392746aeae1c4b37fcc42c65afa7a9587";
    sate = "2015-02-08";
    sha256 = "24b587128143a8259f9a9e0f35b230f4fcc5d19d02144bfcc3c6bf35c31bc547";
  };

  utp = buildFromGitHub {
    rev = "d7ad5aff2b8a5fa415d1c1ed00b71cfd8b4c69e0";
    owner  = "anacrolix";
    repo   = "utp";
    sha256 = "148gsqvb47bpvnf232g1k1095bqpvhr3l22bscn8chbf6xyp5fjz";
    date = "2016-06-01";
    propagatedBuildInputs = [
      envpprof
      missinggo
      sync
    ];
  };

  pborman_uuid = buildFromGitHub {
    rev = "v1.0";
    owner = "pborman";
    repo = "uuid";
    sha256 = "1yk7vxrhsyk5izazdqywzfwb7iq6b5lwwdp0yc4rl4spqx30s0f9";
  };

  hashicorp_uuid = buildFromGitHub {
    rev = "ebb0a03e909c9c642a36d2527729104324c44fdb";
    date = "2016-03-11";
    owner = "hashicorp";
    repo = "uuid";
    sha256 = "0ifcaib2q3j90z0yxgprp6w7hawihhbx1qcdkyzr6c7qy3c808w0";
  };

  vault = buildFromGitHub rec {
    rev = "v0.5.3";
    owner = "hashicorp";
    repo = "vault";
    sha256 = "00czqns7w4km48j9hhmq825dia8j0r03zv5ajk5ii6i3dwq8bw2h";

    buildInputs = [
      armon_go-metrics go-radix govalidator aws-sdk-go speakeasy etcd-client
      duo_api_golang structs ini ldap mysql gocql snappy go-github
      go-querystring hailocab_go-hostpool consul-api errwrap go-cleanhttp
      go-multierror go-syslog golang-lru logutils serf hashicorp_uuid
      go-jmespath osext pq mitchellh-cli copystructure go-homedir mapstructure
      reflectwalk columnize go-zookeeper ugorji_go crypto net oauth2 sys
      asn1-ber inf yaml yaml-v2 hashicorp-go-uuid hcl go-mssqldb
    ];
  };

  vault-api = buildFromGitHub {
    inherit (vault) rev owner repo sha256;
    subPackages = [ "api" ];
    propagatedBuildInputs = [
      hcl
      structs
      go-cleanhttp
      go-multierror
      mapstructure
    ];
  };

  viper = buildFromGitHub {
    owner = "spf13";
    repo = "viper";
    rev = "c1ccc378a054ea8d4e38d8c67f6938d4760b53dd";
    date = "2016-06-05";
    sha256 = "e7a14b1243a9c60aaaf739ba0d7fff0512395ec558d04a41f941ca5371688bb6";
    buildInputs = [
      crypt
      pflag
    ];
    propagatedBuildInputs = [
      cast
      fsnotify
      hcl
      jwalterweatherman
      mapstructure
      properties
      toml
      yaml-v2
    ];
    patches = [
      (fetchTritonPatch {
        rev = "89c1dace6882bef6b3f05e5e6da3e9166665ef57";
        file = "viper/viper-2016-06-remove-etcd-support.patch";
        sha256 = "3cd7132e57b325168adf3f547f5123f744864ba8630ca653b8ee1e928e0e1ac9";
      })
    ];
  };

  vultr = buildFromGitHub {
    rev = "v1.8";
    owner  = "JamesClonk";
    repo   = "vultr";
    sha256 = "1p4vb6rbcfr02fml2sj8nwsy34q4n9ylidhr90vjzk99x57pcjf7";
    propagatedBuildInputs = [
      mow-cli
      tokenbucket
      ratelimit
    ];
  };

  websocket = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "gorilla";
    repo   = "websocket";
    sha256 = "11sggyd6plhcd4bdi8as0bx70bipda8li1rdf0y2n5iwnar3qflq";
  };

  wmi = buildFromGitHub {
    rev = "f3e2bae1e0cb5aef83e319133eabfee30013a4a5";
    owner = "StackExchange";
    repo = "wmi";
    sha256 = "1paiis0l4adsq68v5p4mw7g7vv39j06fawbaph1d3cglzhkvsk7q";
    date = "2015-05-20";
  };

  yaml = buildFromGitHub {
    rev = "aa0c862057666179de291b67d9f093d12b5a8473";
    date = "2016-06-03";
    owner = "ghodss";
    repo = "yaml";
    sha256 = "0vayx9m09flqlkwx8jy4cih01d8637cvnm1x3yxfvzamlb5kdm9p";
    propagatedBuildInputs = [ candiedyaml ];
  };

  yaml-v2 = buildFromGitHub {
    rev = "a83829b6f1293c91addabc89d0571c246397bbf4";
    date = "2016-03-01";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "0jf2man0a6jz02zcgqaadqa3844jz5kihrb343jq52xp2180zwzz";
    goPackagePath = "gopkg.in/yaml.v2";
  };

  yaml-v1 = buildFromGitHub {
    rev = "9f9df34309c04878acc86042b16630b0f696e1de";
    date = "2014-09-24";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "128xs9pdz042hxl28fi2gdrz5ny0h34xzkxk5rxi9mb5mq46w8ys";
    goPackagePath = "gopkg.in/yaml.v1";
  };

  yamux = buildFromGitHub {
    date = "2016-06-09";
    rev = "badf81fca035b8ebac61b5ab83330b72541056f4";
    owner  = "hashicorp";
    repo   = "yamux";
    sha256 = "063capa74w4q6sj2bm9gs75vri3cxa06pzgzly17rl5grzilsw3y";
  };

  xdr = buildFromGitHub {
    rev = "v2.0.0";
    owner  = "calmh";
    repo   = "xdr";
    sha256 = "017k3y66fy2azbv9iymxsixpyda9czz8v3mhpn17750vlg842dsp";
  };

  xstrings = buildFromGitHub {
    rev = "3959339b333561bf62a38b424fd41517c2c90f40";
    date = "2015-11-30";
    owner  = "huandu";
    repo   = "xstrings";
    sha256 = "16l1cqpqsgipa4c6q55n8vlnpg9kbylkx1ix8hsszdikj25mcig1";
  };

  zappy = buildFromGitHub {
    date = "2016-03-05";
    rev = "4f5e6ef19fd692f1ef9b01206de4f1161a314e9a";
    owner = "cznic";
    repo = "zappy";
    sha256 = "1kinbjs95hv16kn4cgm3vb1yzv09ina7br5m3ygh803qzxp7i5jz";
  };
}; in self
