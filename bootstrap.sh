#!/bin/sh
# One command from a factory Mac to the wizard:
#
#   curl -fsSL https://raw.githubusercontent.com/Superd22/Nix-Config/main/bootstrap.sh | sh
#
# This stub stays small on purpose. Nothing interesting can run yet: nix does
# not exist, so the wizard cannot, and there are no keys, so nothing private can
# be cloned. It installs the two prerequisites and hands over to `#init`, a
# real nix-built program (apps/init.sh) that is versioned and shellchecked
# instead of debugged by re-curling it onto a fresh machine.
set -eu

main() {
  # 1. Xcode command line tools. `--install` opens a dialog and returns at
  #    once, so wait for the user to finish it.
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
    echo "Finish the Xcode Command Line Tools dialog; waiting for it..."
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  fi

  # 2. Determinate Nix. hosts/common/darwin.nix sets `nix.enable = false`, so
  #    this installer is a hard prerequisite, not a preference.
  if ! command -v nix >/dev/null 2>&1 && [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
    installer="$(mktemp)"
    curl -fsSL https://install.determinate.systems/nix -o "$installer"
    sh "$installer" install --determinate
    rm -f "$installer"
  fi
  # The installer edits shell profiles; this shell predates that.
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  # 3. Everything interactive lives in the flake.
  exec nix run github:Superd22/Nix-Config#init -- "$@"
}

# `curl | sh` leaves stdin as the pipe the script arrives on, and `nix run`
# execs the wizard without a fork, so it would inherit that pipe. Wrapping the
# body in a function also makes sh read the whole file before running any of
# it. Run with the terminal as stdin, like rustup does.
if [ -t 1 ] && [ -e /dev/tty ]; then
  main "$@" </dev/tty
else
  echo "bootstrap.sh needs a terminal." >&2
  exit 1
fi
