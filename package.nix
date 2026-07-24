{
  lib,
  wineWow64Packages,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  autoconf,
  automake,
  perl,
  python3,
  util-linux,
  tag,
  hash,
}:
let
  version = lib.replaceStrings [ "-" ] [ "." ] (
    lib.removeSuffix "-wine" (lib.removePrefix "cachyos-" tag)
  );
  major = lib.head (builtins.match "cachyos-([0-9]+)\\..*" tag);

  geckoVersion = "2.47.4";
  monoVersion = "10.4.1";
  xaliaVersion = "0.4.8";

  gecko32Hash = "sha256-Js7MR3BrCRkI9/gUvdsHTGG+uAYzGOnvxaf3iYV3k9Y=";
  gecko64Hash = "sha256-5ZC32YijLWqkzx2Ko6o9M3Zv3Uz0yJwtzCCV7LKNBm8=";
  monoHash = "sha256-Bx9LKIfhyXoR15H/PWW+lCnu1t7EwnCIiL/VRro1jiM=";
  xaliaHash = "sha256-09GVpyVTiXAX8tR1y55/+J4ud3LE6TF0KT+taKnG13o=";

  geckoMsi =
    arch: geckoHash:
    fetchurl {
      url = "https://dl.winehq.org/wine/wine-gecko/${geckoVersion}/wine-gecko-${geckoVersion}-${arch}.msi";
      hash = geckoHash;
    };

  monoMsi = fetchurl {
    url = "https://dl.winehq.org/wine/wine-mono/${monoVersion}/wine-mono-${monoVersion}-x86.msi";
    hash = monoHash;
  };

  xalia = fetchzip {
    url = "https://github.com/madewokherd/xalia/releases/download/xalia-${xaliaVersion}/xalia-${xaliaVersion}-net48-mono.zip";
    hash = xaliaHash;
    stripRoot = false;
  };

  optimizeFlags = "-O2 -march=nocona -mtune=core-avx2 -mfpmath=sse -pipe -mno-avx -mno-avx2 -mno-avx512f -fvect-cost-model=cheap -fipa-pta";
  sanityFlags = "-fwrapv -fno-strict-aliasing -D_TIME_BITS=64 -D_FILE_OFFSET_BITS=64";
  debugFlags = "-ffunction-sections -fdata-sections -fno-omit-frame-pointer";
  warningFlags = "-Wno-incompatible-pointer-types";
  commonFlags = "${optimizeFlags} ${sanityFlags} ${debugFlags} ${warningFlags}";

  # Wine before 10 uses `bool` as an identifier; C23 reserves it as a keyword.
  legacyCStd = lib.optionalString (lib.versionOlder major "10") " -std=gnu17";
in
(wineWow64Packages.stableFull.override { embedInstallers = false; }).overrideAttrs (old: {
  pname = "wine-cachyos";
  inherit version;

  src = fetchFromGitHub {
    owner = "CachyOS";
    repo = "wine-cachyos";
    rev = tag;
    inherit hash;
  };

  patches = [ ./cert-path.patch ];

  nativeBuildInputs = old.nativeBuildInputs ++ [
    autoconf
    automake
    perl
    python3
    util-linux
  ];

  postPatch = ''
    export HOME="$TMPDIR"
    patchShebangs tools dlls/winevulkan/make_vulkan autogen.sh
    ./autogen.sh
  '';

  # Upstream passes each --with-* explicitly so configure fails loudly when a
  # dependency is absent, instead of autodetecting it away into a silent
  # feature drop.
  configureFlags = old.configureFlags ++ [
    "--with-x"
    "--with-freetype"
    "--with-mingw"
    "--with-alsa"
    "--with-gstreamer"
    "--with-ffmpeg"
    "--without-oss"
    "--disable-lsteamclient"
    "--disable-tests"
    "--enable-build-id"
  ];

  env = old.env // {
    CFLAGS = "${commonFlags} -mcmodel=small${legacyCStd}";
    CXXFLAGS = "${commonFlags} -mcmodel=small -std=c++17";
    CROSSCFLAGS = "${commonFlags} -s${legacyCStd}";
    CROSSCXXFLAGS = "${commonFlags} -s -std=c++17";
    CROSSLDFLAGS = "-Wl,-O1,--sort-common,--as-needed -Wl,--file-alignment,4096";
  };

  postInstall = (old.postInstall or "") + ''
    install -d "$out/share/wine/gecko" "$out/share/wine/mono" "$out/share/xalia"
    ln -s ${geckoMsi "x86" gecko32Hash} "$out/share/wine/gecko/wine-gecko-${geckoVersion}-x86.msi"
    ln -s ${geckoMsi "x86_64" gecko64Hash} "$out/share/wine/gecko/wine-gecko-${geckoVersion}-x86_64.msi"
    ln -s ${monoMsi} "$out/share/wine/mono/wine-mono-${monoVersion}-x86.msi"
    cp -r ${xalia}/. "$out/share/xalia/"
  '';

  passthru = (old.passthru or { }) // {
    updateScript = null;
    inherit
      tag
      major
      geckoVersion
      monoVersion
      xaliaVersion
      ;
  };

  meta = old.meta // {
    description = "Wine with CachyOS and Proton patches, new WoW64 (x86_64 + i386)";
    homepage = "https://github.com/CachyOS/wine-cachyos";
    platforms = [ "x86_64-linux" ];
    badPlatforms = [ ];
    maintainers = [ ];
    inherit version;
  };
})
