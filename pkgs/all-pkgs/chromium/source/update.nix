let
  inherit (import ../../../../. { }) lib writeText stdenv;

  sources = if builtins.pathExists ./sources.nix
            then import ./sources.nix
            else null;

  debURL = "https://dl.google.com/linux/chrome/deb/pool/main/g";

  # Untrusted mirrors, don't try to update from them!
  debMirrors = [
    "http://mirror.glendaleacademy.org/chrome/pool/main/g"
    "http://95.31.35.30/chrome/pool/main/g"
    "http://mirror.pcbeta.com/google/chrome/deb/pool/main/g"
    "http://repo.fdzh.org/chrome/deb/pool/main/g"
  ];

  tryChannel = channel: let
    chan = builtins.getAttr channel sources;
  in if sources != null then ''
    oldver="${chan.version}";
    echo -n "Checking if $oldver ($channel) is up to date..." >&2;
    if [ "x$(get_newest_ver "$version" "$oldver")" != "x$oldver" ];
    then
      echo " no, getting sha256 for new version $version:" >&2;
      sha256="$(prefetch_sha "$channel" "$version")" || return 1;
    else
      echo " yes, keeping old sha256." >&2;
      sha256="${chan.sha256}";
      ${if (chan ? sha256bin32 && chan ? sha256bin64) then ''
        sha256="$sha256.${chan.sha256bin32}.${chan.sha256bin64}";
      '' else ''
        sha256="$sha256.$(prefetch_deb_sha "$channel" "$version")";
      ''}
    fi;
  '' else ''
    sha256="$(prefetch_sha "$channel" "$version")" || return 1;
  '';

  caseChannel = channel: ''
    ${channel}) ${tryChannel channel};;
  '';

in rec {
  getChannel = channel: let
    chanAttrs = builtins.getAttr channel sources;
  in {
    inherit (chanAttrs) version;

    main = {
      url = "mirror://chromium/chromium-${chanAttrs.version}.tar.xz";
      inherit (chanAttrs) sha256;
    };

    binary = let
      pname = if channel == "dev"
              then "google-chrome-unstable"
              else "google-chrome-${channel}";
      arch = if stdenv.is64bit then "amd64" else "i386";
      relpath = "${pname}/${pname}_${chanAttrs.version}-1_${arch}.deb";
    in lib.optionalAttrs (chanAttrs ? sha256bin64) {
      urls = map (url: "${url}/${relpath}") ([ debURL ] ++ debMirrors);
      sha256 = if stdenv.is64bit
               then chanAttrs.sha256bin64
               else chanAttrs.sha256bin32;
    };
  };

  updateHelpers = writeText "update-helpers.sh" (''

    prefetch_main_sha()
    {
  '' + lib.flip lib.concatMapStrings (import ../../../build-support/fetchurl/mirrors.nix).chromium (mirror: ''
      if OUT="$(curl -L "${mirror}chromium-$2.tar.xz.hashes")"; then
        if ! echo "$OUT" | grep -q 'Error'; then
          if SHA="$(echo "$OUT" | awk '{ if (/sha256/) { print $2; } }')"; then
            if [ "$SHA" != "" ]; then
              echo "$SHA"
              return 0
            fi
          fi
        fi
      fi
  '') + ''
      return 1
    }

    prefetch_deb_sha()
    {
      channel="$1";
      version="$2";

      case "$1" in
        dev) pname="google-chrome-unstable";;
        *)   pname="google-chrome-$channel";;
      esac;

      deb_pre="${debURL}/$pname/$pname";

      if ! deb32=$(nix-prefetch-url "''${deb_pre}_$version-1_i386.deb"); then
        return 1
      fi
      if ! deb64=$(nix-prefetch-url "''${deb_pre}_$version-1_amd64.deb"); then
        return 1
      fi

      echo "$deb32.$deb64";
    }

    prefetch_sha()
    {
      main_sha="$(prefetch_main_sha "$@")" || return 1;
      deb_sha="$(prefetch_deb_sha "$@")" || return 1;
      echo "$main_sha.$deb_sha";
      return 0;
    }

    get_sha256()
    {
      channel="$1";
      version="$2";

      case "$channel" in
        ${lib.concatMapStrings caseChannel [ "stable" "dev" "beta" ]}
      esac;

      sha_insert "$version" "$sha256";
      echo "$sha256";
      return 0;
    }
  '');
}
