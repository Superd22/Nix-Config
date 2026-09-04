# Nix & Dotfiles

Nix & dotfiles for personal & work laptop
`nix run .#build-switch` to up (see apps for scripts). It builds the host whose
name matches `hostname -s`; pass a host name to build another one, e.g.
`nix run .#build-switch -- example`.
`nix flake update` to upgrade

**docs/new-machine.md** how to set up a new Mac, and how to move the three
keys nothing can regenerate from the old one (`nix run .#keys`).
**hosts** one directory per machine, named after its hostname, plus
`hosts/common` for the darwin config they share. Each becomes
`darwinConfigurations.<hostname>`.
**modules** the actual configuration.
**overlays** if required


# todo
- [ ] auto zerotier
- [ ] auto pritnul
- [x] auto aws config (`mine.work.wemaintain`, #8)
