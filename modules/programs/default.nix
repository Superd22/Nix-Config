# Home-manager modules, one per program. `config` inside these files is the
# home-manager user config, not the nix-darwin system config — the system one
# arrives as `osConfig`, which is where the `mine.*` identity lives.
#
# Nothing here is conditional yet. When per-program opt-out arrives (#3) the
# flag goes inside each file, so this list stays a plain enumeration that the
# wizard (#5) can read and a forker can `rm` an entry from.
{ ... }:

{
  imports = [
    ./zsh.nix
    ./starship.nix
    ./git.nix
    ./vim.nix
    ./alacritty.nix
    ./ssh.nix
    ./tmux.nix
    ./direnv.nix
    # ./datagrip is deliberately absent: it is a nix-darwin module, not a
    # home-manager one, and is imported from modules/home-manager.nix.
  ];
}
