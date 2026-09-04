# David's M3 Pro MacBook.
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

  # DataGrip and its connections (#7). These are the datasources that used to
  # live in a committed `.idea/dataSources.xml` nothing imported; they are now
  # global, so they are in every project this machine's DataGrip opens.
  #
  # The user names are the ones DataGrip was actually using. They disagree with
  # the `withPg` shell helpers on staging (wmadmin here, backend_dev there);
  # that reconciliation belongs to #8, which will feed both from one
  # declaration. Until then this is a faithful copy of what was in use.
  mine.programs.datagrip = {
    enable = true;

    datasources =
      let
        wemaintain = host: {
          driver = "postgresql";
          url = "jdbc:postgresql://wemaintain-pgsql-${host}.cdtgkxemrw9j.eu-west-1.rds.amazonaws.com:5432/postgres";
          awsProfile = "prod:sudo";
          awsRegion = "eu-west-1";
        };
      in
      {
        "[STAGING] PG" = wemaintain "staging" // { userName = "wmadmin"; };
        "[PROD] PG" = wemaintain "prod" // { userName = "backend_dev"; };
        "DANGER WRITE PG PROD" = wemaintain "prod" // { userName = "wmadmin"; };

        "postgres@localhost" = {
          driver = "postgresql";
          url = "jdbc:postgresql://localhost:5432/postgres";
        };
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

      # Communication
      "discord"
      "signal"

      # Entertainment
      "vlc"
      "spotify"
      "jellyfin-media-player"
      "steam"
      "obs"

      # Browsers
      "sigmaos"

      # Networking
      "zerotier-one"
      "pritunl"
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
