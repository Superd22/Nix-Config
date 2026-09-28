{ pkgs }:

with pkgs; [
  # General packages for development and system management
  aspell
  aspellDicts.en
  bash-completion
  bat
  btop
  coreutils
  openssh
  wget
  zip

  # Encryption and security tools
  age
  age-plugin-yubikey
  gnupg
  libfido2

  # Cloud-related tools and SDKs
  docker
  docker-compose

  # Media-related packages
  emacs-all-the-icons-fonts
  dejavu_fonts
  ffmpeg
  fd
  font-awesome
  hack-font
  noto-fonts
  noto-fonts-color-emoji
  meslo-lgs-nf

  # Text and terminal utilities
  htop
  hunspell
  iftop
  jetbrains-mono
  jq
  ripgrep
  tree
  tmux
  unrar
  unzip

  # Python packages
  python3
  virtualenv

  # Communications
  # signal-desktop

  nixd
  github-cli
  terraform

  # Per-project dev shells. Activation on `cd` is direnv's job, not devenv's —
  # see modules/programs/direnv.nix.
  devenv

  # awscli2 comes with mine.work.wemaintain (#8); a fork that does not work
  # there does not get it. google-cloud-sdk comes from the data repo's devenv
  # shell, the only place it is used (#43).
]
