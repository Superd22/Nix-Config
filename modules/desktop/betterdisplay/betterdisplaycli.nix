{ config, lib, pkgs, ... }:

let
  scripts = import ./scripts.nix { inherit pkgs; };
in
{
  config = lib.mkIf config.mine.desktop.betterdisplay.enable {
    environment.systemPackages = [ scripts.workspace-to-next-monitor ];

    system.activationScripts.extraActivation.text = ''
      cat > /usr/local/bin/betterdisplaycli << 'EOF'
      #!/bin/bash
      exec /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay "$@"
      EOF
      chmod +x /usr/local/bin/betterdisplaycli
      # AeroSpace's `exec-and-forget` inherits the PATH of the GUI process that
      # launched it, which is not guaranteed to include the system profile, so
      # the keybindings in .aerospace.toml go through an absolute path. The shim
      # points at the store, not at the working tree.
      ln -sfn ${scripts.workspace-to-next-monitor}/bin/workspace-to-next-monitor /usr/local/bin/workspace-to-next-monitor
    '';
  };
}
