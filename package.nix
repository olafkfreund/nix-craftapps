{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  undmg,
  unzip,
  alsa-lib,
  dbus,
  libGL,
  vulkan-loader,
  wayland,
  libxkbcommon,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxrandr,
  name,
  info,
}:

let
  source =
    info.sources.${stdenv.hostPlatform.system}
      or (throw "${name}: no release for ${stdenv.hostPlatform.system}");
  fetch = s: fetchurl { inherit (s) url hash; };

  linux = {
    src = fetch source;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];
    buildInputs = [
      stdenv.cc.cc.lib
      alsa-lib
    ];
    # dlopen()ed at runtime, so autoPatchelf cannot see them in NEEDED.
    runtimeDependencies = [
      dbus.lib
      libGL
      vulkan-loader
      wayland
      libxkbcommon
      libx11
      libxcb
      libxcursor
      libxi
      libxrandr
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r bin share $out/
      runHook postInstall
    '';

    # Some apps pre-check their graphics libraries with `ldconfig -p`, which
    # cannot see the RUNPATH, and refuse to start; the libraries load fine.
    postFixup = ''
      wrapProgram $out/bin/${name} --set-default ${lib.toUpper name}_SKIP_LIB_CHECK 1
    '';
  };

  # The binaries link only system frameworks and are signed and notarized
  # upstream, so they are copied untouched.
  darwin = {
    srcs = [
      (fetch source)
      (fetch source.cli)
    ];
    sourceRoot = ".";

    nativeBuildInputs = [
      makeWrapper
      undmg
      unzip
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications $out/bin $out/share/doc/${name}
      cp -R *.app $out/Applications/
      makeWrapper $out/Applications/*.app/Contents/MacOS/* $out/bin/${name}
      install -m755 ${name}-cli-*/${name}-cli $out/bin/
      find ${name}-cli-* -maxdepth 1 -type f ! -name ${name}-cli -exec cp -t $out/share/doc/${name} {} +
      runHook postInstall
    '';

    # Stripping would invalidate the code signature.
    dontFixup = true;
  };
in
stdenv.mkDerivation (
  {
    pname = name;
    inherit (info) version;

    dontConfigure = true;
    dontBuild = true;

    meta = {
      description = "${info.title}: ${info.description}";
      homepage = "https://github.com/${info.repo}";
      changelog = "https://github.com/${info.repo}/releases/tag/${info.tag}";
      license = with lib.licenses; [
        mit
        asl20
      ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = builtins.attrNames info.sources;
      mainProgram = name;
    };
  }
  // (if stdenv.hostPlatform.isDarwin then darwin else linux)
)
