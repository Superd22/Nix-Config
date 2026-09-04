# david-m5-max. Copied from hosts/David-M3-Pro by init on 2026-09-04.
#
# The directory name is the flake attribute name and matches `hostname -s`,
# so `nix run .#build-switch` picks this host with no argument.
#
# hosts/common/darwin.nix is composed in by flake.nix; this file holds only
# what is specific to this machine: the identity that used to be duplicated as
# `let user = "david"` across five module files (#2), the enable flags that used
# to be hardcoded inside the modules themselves (#3), and the Homebrew lists
# that used to sit in modules/homebrew.nix (#9).
{ ... }:

{
  mine.user = {
    name = "david";
    fullName = "David";
    email = "superd001@gmail.com";
  };

  # Every flag below is spelled out even where it looks obvious. `mkEnableOption`
  # defaults to `false`, so nothing arrives here by default and nothing can drift
  # back in by someone changing a default in modules/. What this machine runs is
  # readable in one screen, which is the whole point.
  mine.desktop = {
    # Tiling window manager. The reason this laptop exists in this shape.
    aerospace.enable = true;

    # Off. It was previously off via `services.sketchybar.enable = false` inside
    # modules/desktop/sketchybar/sketchybar.nix; same end state, expressed here.
    sketchybar.enable = false;

    # `betterdisplaycli`, which the raycast scripts below are built out of.
    betterdisplay.enable = true;

    # On: this config manages the Dock. Which today means stripping it, since
    # `local.dock.enable` is false and the entries list is empty.
    dock.enable = true;

    # The ultra-wide script commands. These assert betterdisplay.enable above.
    raycast.enable = true;
  };

  # Work (#8). One flag: ~/.aws/config with every SSO profile, the RDS CA
  # bundle, `withPg`/`withPgProd`, the DataGrip datasources for the same
  # databases, gcloud on the data project, the Pritunl cask and its VPN
  # profile (#32), and `wm-login` to do all the browser halves. The profiles,
  # accounts and databases are declared by the module; anything personal on
  # top of them would go here as another `mine.work.wemaintain.*` entry.
  #
  # Note the staging datasource in DataGrip is now backend_dev over prod:back,
  # as the shell helper always was, rather than the wmadmin over prod:sudo it
  # had by hand. `mine.work.wemaintain.databases.staging.user = "wmadmin"`
  # would put it back for both tools at once.
  mine.work.wemaintain = {
    enable = true;
    email = "david@wemaintain.com";
  };

  # DataGrip (#7). The WeMaintain datasources come from the block above; only
  # what is personal to this machine is listed here.
  mine.programs.datagrip = {
    enable = true;

    datasources."postgres@localhost" = {
      driver = "postgresql";
      url = "jdbc:postgresql://localhost:5432/postgres";
    };
  };

  # Homebrew (#9). These used to be a flat list inside modules/homebrew.nix,
  # which meant a fork of this repo got Steam, NordVPN and Autodesk Fusion
  # whether it wanted them or not. Nothing here is a dependency of anything in
  # modules/ — the casks that are (betterdisplay, raycast, datagrip) are
  # declared by the modules that need them and follow the flags above.
  mine.homebrew = {
    brews = [
      "git-secret"
      "deno"
      "fga"
      "scrcpy"
      "rust"
      "httpie"
      # Salesforce CLI. Was also listed as a cask, where the same tool ships
      # under the token `salesforce-cli` and is disabled upstream since
      # 2026-09-01 for failing Gatekeeper; the formula is the one that works.
      "sf"
    ];

    casks = [
      # Development
      "docker-desktop"
      "visual-studio-code"
      "zed"
      "openlens"
      "warp"
      "claude-code"
      "claude"
      # Communication
      "discord"
      "signal"
      "ferdium"

      # Entertainment
      "vlc"
      "spotify"
      "jellyfin-media-player"
      "steam"
      "obs"

      # Browsers
      "google-chrome"

      # Networking. Pritunl is not here: it comes with
      # `mine.work.wemaintain.enable`, which owns the VPN profile too (#32).
      "zerotier-one"
      "nordvpn"

      # 3D printing and CAD
      "autodesk-fusion"
      "orcaslicer"

      # Screens and peripherals
      "deskflow"
      "parsec"
      "camo-studio"
    ];
  };

  mine.services."screen-lock-monitor".enable = true;

  # This machine has SSH access to the private secrets repo (#17).
  mine.secrets.enable = true;
}
