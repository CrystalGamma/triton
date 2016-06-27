{ stdenv
, buildPythonPackage
, fetchFromGitHub
, fetchTritonPatch
, glibcLocales
, isPy3k
, makeWrapper
, pythonPackages
, writeScript

, bash
, bashCompletion
, beautifulsoup
, bs1770gain
, discogs-client
, enum34
, flac
, flask
, imagemagick
, itsdangerous
, jellyfish
, jinja2
, mock
, mp3val
, mpd
, munkres
, musicbrainzngs
, mutagen
, nose
, pathlib
, pyacoustid
, pyechonest
, pylast
, pyxdg
, pyyaml
, rarfile
, requests
, responses
, unidecode
, werkzeug

# For use in inline plugin
, pycountry

# External plugins
, enableAlternatives ? true
#, enableCopyArtifacts ? true
, enableDsedivecBeetsPlugins ? true
}:

let
  inherit (stdenv)
    targetSystem;
  inherit (stdenv.lib)
    attrNames
    concatMapStrings
    concatStringsSep
    elem
    filterAttrs
    id
    makeSearchPath
    optional
    optionals
    optionalString
    platforms;
in

let
  optionalPlugins = {
    # TODO: write a generic function to detect null dependencies
    acousticbrainz =
      if requests != null then
        true
      else
        false;
    badfiles =
      if flac != null
         && mp3val != null then
        true
      else
        false;
    beatport =
      if requests != null then
        true
      else
        false;
    bpd =
      #if pygobject_2 != null
      #   && gst-plugins-base_0 != null
      #   && gstreamer_0 != null then
      #  true
      #else
        false;
    chroma =
      if pyacoustid != null then
        true
      else
        false;
    discogs =
      if discogs-client != null then
        true
      else
        false;
    /*echonest =
      if pyechonest != null then
        true
      else
        false;*/
    embyupdate =
      if requests != null then
        true
      else
        false;
    fetchart =
      if requests != null then
        true
      else
        false;
    lastgenre =
      if pylast != null then
        true
      else
        false;
    lastimport =
      if pylast != null then
        true
      else
        false;
    mpdstats =
      if mpd != null then
        true
      else
        false;
    mpdupdate =
      if mpd != null then
        true
      else
        false;
    replaygain =
      if bs1770gain != null then
        true
      else
        false;
    thumbnails =
      if pyxdg != null then
        true
      else
        false;
    web =
      if flask != null then
        true
      else
        false;
  };

  pluginsWithoutDeps = [
    "bench"
    "bpd"
    "bpm"
    "bucket"
    "convert"
    "cue"
    "duplicates"
    "edit"
    "embedart"
    "embyupdate"
    "export"
    "filefilter"
    "freedesktop"
    "fromfilename"
    "ftintitle"
    "fuzzy"
    "hook"
    "ihate"
    "importadded"
    "importfeeds"
    "info"
    "inline"
    "ipfs"
    "keyfinder"
    "lyrics"
    "mbcollection"
    "mbsubmit"
    "mbsync"
    "metasync"
    "missing"
    "permissions"
    "play"
    "plexupdate"
    "random"
    "rewrite"
    "scrub"
    "smartplaylist"
    "spotify"
    "the"
    "types"
    "zero"
  ];

  enabledOptionalPlugins = attrNames (filterAttrs (_: id) optionalPlugins);

  allPlugins = pluginsWithoutDeps ++ attrNames optionalPlugins;
  allEnabledPlugins = pluginsWithoutDeps ++ enabledOptionalPlugins;

  testShell = "${bash}/bin/bash --norc";
  completion = "${bashCompletion}/share/bash-completion/bash_completion";
in

buildPythonPackage rec {
  name = "beets-${version}";
  version = "1.3.19";
  namePrefix = "";

  src = fetchFromGitHub {
    owner = "sampsyo";
    repo = "beets";
    rev = "v${version}";
    sha256 = "af9cacc3cf28e11aae007549ad7e6172c239d976aa90aea08484ad715cfa5946";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  propagatedBuildInputs = [
    beautifulsoup
    bs1770gain
    discogs-client
    enum34
    flac
    flask
    imagemagick
    itsdangerous
    jellyfish
    jinja2
    mock
    mp3val
    mpd
    munkres
    musicbrainzngs
    mutagen
    nose
    pathlib
    pyacoustid
    pyechonest
    pylast
    pyxdg
    pyyaml
    rarfile
    responses
    requests
    unidecode
    werkzeug
  ] ++ [
    pycountry
  ] ++ optional enableAlternatives (
      import ./plugins/beets-alternatives.nix {
        inherit
          stdenv
          buildPythonPackage
          fetchFromGitHub
          pythonPackages;
      }
    )
    /* FIXME: Causes other plugins to fail to load
    ++ optional enableCopyArtifacts (
      import ./plugins/beets-copyartifacts.nix {
        inherit
          stdenv
          buildPythonPackage
          fetchFromGitHub
          fetchTritonPatch
          pythonPackages;
      }
    )*/
    /* Provides edit & moveall plugins */
    ++ optional enableDsedivecBeetsPlugins (
      import ./plugins/dsedivec-beets-plugins.nix {
        inherit
          stdenv
          buildPythonPackage
          fetchFromGitHub
          pythonPackages;
      }
    );

  patches = [
    (fetchTritonPatch {
      rev = "d3fc5e59bd2b4b465c2652aae5e7428b24eb5669";
      file = "beets/beets-1.3-replaygain-default-bs1770gain.patch";
      sha256 = "d864aa643c16d5df9b859b5f186766a94bf2db969d97f255a88f33acf903b5b6";
    })
  ];

  postPatch = ''
    sed -i -e '/assertIn.*item.*path/d' test/test_info.py
    echo echo completion tests passed > test/rsrc/test_completion.sh

    sed -i -e '/^BASH_COMPLETION_PATHS *=/,/^])$/ {
      /^])$/i u"${completion}"
    }' beets/ui/commands.py
  '' + /* fix paths for badfiles plugin */ ''
    sed -i -e '/self\.run_command(\[/ {
      s,"flac","${flac}/bin/flac",
      s,"mp3val","${mp3val}/bin/mp3val",
    }' beetsplug/badfiles.py
  '' + /* Replay gain */ ''
    sed -i -re '
      s!^( *cmd *= *b?['\'''"])(bs1770gain['\'''"])!\1${bs1770gain}/bin/\2!
    ' beetsplug/replaygain.py
    sed -i -e 's/if has_program.*bs1770gain.*:/if True:/' \
      test/test_replaygain.py
  '';

  preCheck = ''
    (${concatMapStrings (s: "echo \"${s}\";") allPlugins}) \
      | sort -u > plugins_defined
    find beetsplug -mindepth 1 \
      \! -path 'beetsplug/__init__.py' -a \
      \( -name '*.py' -o -path 'beetsplug/*/__init__.py' \) -print \
      | sed -n -re 's|^beetsplug/([^/.]+).*|\1|p' \
      | sort -u > plugins_available

    if ! mismatches="$(diff -y plugins_defined plugins_available)"; then
      echo "The the list of defined plugins (left side) doesn't match" \
           "the list of available plugins (right side):" >&2
      echo "$mismatches" >&2
      exit 1
    fi
  '';

  # TODO: fix LOCALE_ARCHIVE for freebsd
  checkPhase = ''
    runHook 'preCheck'

    LANG=en_US.UTF-8 \
    LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive \
    BEETS_TEST_SHELL="${testShell}" \
    BASH_COMPLETION_SCRIPT="${completion}" \
    HOME="$(mktemp -d)" \
      nosetests -v

    runHook 'postCheck'
  '';

  installCheckPhase = ''
    runHook 'preInstallCheck'

    tmphome="$(mktemp -d)"

    EDITOR="${writeScript "beetconfig.sh" ''
      #!${stdenv.shell}
      cat > "$1" <<CFG
      plugins: ${concatStringsSep " " allEnabledPlugins}
      CFG
    ''}" HOME="$tmphome" "$out/bin/beet" config -e
    EDITOR=true HOME="$tmphome" "$out/bin/beet" config -e

    runHook 'postInstallCheck'
  '';

  disabled = isPy3k;
  doCheck = true;
  doInstallCheck = true;

  meta = with stdenv.lib; {
    description = "Music tagger and library organizer";
    homepage = http://beets.radbox.org;
    license = licenses.mit;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
