# Nix-Config

The nix-darwin and home-manager config for my Macs: packages, dotfiles, Homebrew, the
desktop (AeroSpace, SketchyBar, Raycast) and, behind one flag, everything needed to work
at WeMaintain. It is written to be forked. Every personal choice is a `mine.*` option,
and a new host starts from a neutral template rather than from mine.

macOS on Apple silicon only.

## Set up a Mac

On a factory Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/Superd22/Nix-Config/main/bootstrap.sh | sh
```

This installs the Xcode command line tools and Determinate Nix, then runs a wizard
(`nix run .#init`) that asks who you are:

- Myself moving from an other Mac: export your keys on the old one first with
  `nix run .#keys -- export`. The wizard imports that bundle, checks it, and builds.
  Don't wipe the old Mac until `keys doctor` passes on the new one; one of those keys
  cannot be regenerated.
- Someone else: the wizard sets up your copy (private mirror, public fork, or a plain
  clone), writes
  `hosts/<your-hostname>/default.nix` from [`hosts/example`](./hosts/example), asks which
  modules to keep, and builds. Answer yes to "WeMaintain?" to get the work setup.

Re-running it is safe. [docs/new-machine.md](./docs/new-machine.md) covers both paths
step by step, the keys, and what to do when a step fails.

## Day to day

| Command                            | Does                                                            |
| ---------------------------------- | --------------------------------------------------------------- |
| `nix run .#build-switch`           | Build and activate the host named after `hostname -s`           |
| `nix run .#build-switch -- <host>` | Same, for another host under `hosts/`                           |
| `nix run .#build`                  | Build without activating                                        |
| `nix run .#rollback`               | Pick an earlier generation and switch back to it                |
| `nix run .#keys -- doctor`         | Check the SSH and GPG keys this config expects are in place     |
| `nix flake update <input>…`        | Upgrade. Name the inputs; see [private inputs](#private-inputs) |

## Layout

| Path                                | Contents                                                                                                                                                                           |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`hosts/`](./hosts)                 | One directory per machine, named after its hostname. `common/` is shared, `example/` is the template for forks                                                                     |
| [`modules/`](./modules/README.md)   | The configuration. [`options.nix`](./modules/options.nix) declares every `mine.*` flag                                                                                             |
| [`modules/work/`](./modules/work)   | Employer-specific modules, each off by default                                                                                                                                     |
| [`apps/`](./apps)                   | The scripts behind `nix run .#<name>`                                                                                                                                              |
| [`docs/`](./docs)                   | [new-machine.md](./docs/new-machine.md), and [two-paths.md](./docs/two-paths.md) on why `claude-code` links `~/.claude` into the repo while every other module generates its files |
| [`overlays/`](./overlays/README.md) | nixpkgs overlays, applied on every build                                                                                                                                           |
| [`bootstrap.sh`](./bootstrap.sh)    | The `curl` script above                                                                                                                                                            |

## WeMaintain

In your host:

```nix
mine.work.wemaintain.enable = true;
```

Then `build-switch` and `wm-login`. You get the AWS SSO profiles in `~/.aws/config`, the
`withPg` / `withPgProd` RDS helpers, DataGrip datasources for the same databases, and the
Pritunl VPN client.

The account ids, endpoints and helpers come from the `wm` flake input,
[wemaintain/devenv](https://github.com/wemaintain/devenv). WeMaintain repos import the same
repo for their dev shells, so this machine and every project read one copy of those
values. See [`modules/work/wemaintain`](./modules/work/wemaintain/default.nix).

## Private inputs

Two inputs are private repos: `secrets` (my agenix store) and `wm` (WeMaintain's devenv).
A host that doesn't use them never fetches them, but a bare `nix flake update` tries to
relock both and fails if your GitHub account can't see them. Update by name instead:

```sh
nix flake update nixpkgs home-manager darwin nix-homebrew
```

If you forked this, point `secrets` at your own repo, or leave it off
(`mine.secrets.enable` defaults to false). [docs/new-machine.md](./docs/new-machine.md#secrets)
shows how to create one.

## Todo

- [ ] auto zerotier
