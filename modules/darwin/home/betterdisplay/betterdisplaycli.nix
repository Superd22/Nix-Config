{ config, lib, pkgs, ... }:

{
  system.activationScripts.extraActivation.text = ''
    cat > /usr/local/bin/betterdisplaycli << 'EOF'
    #!/bin/bash
    exec /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay "$@"
    EOF
    chmod +x /usr/local/bin/betterdisplaycli
    ln -f /Users/david/.config/nixos-config/modules/darwin/home/betterdisplay/next-monitor-of-workspace.sh /usr/local/bin/workspace-to-next-monitor
  '';
}
