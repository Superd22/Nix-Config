
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
