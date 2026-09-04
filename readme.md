# Nix & Dotfiles

Nix & dotfiles for personal & work laptop
`nix run .#build-switch` to up (see apps for scripts). It builds the host whose
name matches `hostname -s`; pass a host name to build another one, e.g.
`nix run .#build-switch -- example`.
`nix flake update` to upgrade

**hosts** one directory per machine, named after its hostname, plus
`hosts/common` for the darwin config they share. Each becomes
`darwinConfigurations.<hostname>`.
**modules** the actual configuration.
**overlays** if required


# todo
- [ ] id_rsa auto
- [ ] auto zerotier
- [ ] auto pritnul
- [ ] auto aws config
