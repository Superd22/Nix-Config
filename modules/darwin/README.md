
## Layout
```
.
├── home/                  # Home-manager sub-files
│   ├── dock.nix          # MacOS dock configuration
│   └── homebrew.nix      # Configuration for homebrew (packages & casks)
├── services/             # Nix-darwin services
│   ├── aerospace/        # Aerospace window manager config
│   ├── sketchybar/       # Sketchybar status bar config
│   └── default.nix     # re-exports all of the services
├── default.nix           # Defines module, system-level config
├── files.nix             # Non-Nix, static configuration files
├── home-manager.nix      # Nix home-manager
└── packages.nix          # List of packages to install for MacOS
```

### Services
When services exist, they're usually in services/ in their own folders with .nix & config files next to one another


### Secrets
Follow guide in nix-secrets to create secret, then
1. `nix flake update secrets
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
