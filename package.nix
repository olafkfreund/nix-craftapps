{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
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
in
stdenv.mkDerivation {
  pname = name;
  inherit (info) version;

  src = fetchurl { inherit (source) url hash; };

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

  dontConfigure = true;
  dontBuild = true;

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
