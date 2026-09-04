# A package set rather than a module, so modules/desktop/raycast can take
# `betterdisplaycli` as a runtime input without depending on this module's
# `config` having been evaluated.
{ pkgs }:

{
  # BetterDisplay ships its CLI inside the .app bundle and puts nothing on PATH.
  # This used to be a here-doc written into /usr/local/bin by an activation
  # script; as a package it is in the store, on PATH for both the shell and
  # anything that lists it as a runtime input, and a rollback takes it with it
  # (#21).
  #
  # The path it execs is outside the store and always will be — it belongs to
  # the cask, which Homebrew owns. Nothing can be done about that here.
  betterdisplaycli = pkgs.writeShellApplication {
    name = "betterdisplaycli";
    text = ''
      exec /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay "$@"
    '';
  };
}
