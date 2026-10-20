# No linkFonts: on macOS the apps read /System/Library/Fonts, /Library/Fonts
# and ~/Library/Fonts. nix-darwin links the .app bundles into /Applications/Nix Apps.
craftapps: {
  imports = [ (import ./system.nix craftapps) ];
}
