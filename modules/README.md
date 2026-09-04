## Modules

Everything here runs on macOS (aarch64-darwin). There is no `shared` /
`darwin` split anymore — there is only one target.

## Layout
```
.
├── config/                # Config files not written in Nix (emacs, raycast, datagrip)
├── desktop/               # Window management & display: aerospace, betterdisplay,
│                          # dock, sketchybar
├── services/              # Nix-darwin services (screen-lock-monitor)
├── nixpkgs.nix            # nixpkgs config; defines how we import overlays
├── secrets.nix            # agenix secrets
├── home-manager.nix       # The nix-darwin module wiring up home-manager
├── programs.nix           # home-manager programs (git, zsh, vim, tmux, ssh, ...)
├── files.nix              # Non-Nix, static configuration files (now immutable!)
├── homebrew.nix           # Homebrew policy, packages & casks
├── packages.nix           # System packages (environment.systemPackages)
└── home-packages.nix      # User packages (home-manager), packages.nix plus extras
```

### Services
When services exist, they're usually in their own folder with .nix & config files
next to one another.

### Secrets
Follow guide in nix-secrets to create secret, then
1. `nix flake update secrets`
2. Update secrets.nix with
```nix
  age.secrets.MY_SECRET = {
    symlink = true;
    path = "whereToPutTheDecryptedSecret";
    file = "${secrets}/encrypted.age";
  };
```
3. Build & switch

> Secrets in ~/.secrets are automatically picked up by zsh
