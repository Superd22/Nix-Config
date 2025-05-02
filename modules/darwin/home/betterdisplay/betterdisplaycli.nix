{ config, lib, pkgs, ... }:

{
  system.activationScripts.extraActivation.text = ''
    cat > /usr/local/bin/betterdisplaycli << 'EOF'
    #!/bin/bash
    exec /Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay "$@"
    EOF
    chmod +x /usr/local/bin/betterdisplaycli
  '';
}
