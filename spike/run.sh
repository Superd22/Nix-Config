#!/bin/sh
# Probes whether Nix's builtins.fromTOML accepts the TOML 1.1.0 syntax that
# AeroSpace 0.21.0+ recommends for on-window-detected callbacks.
cd "$(dirname "$0")" || exit 1
for f in a b c d; do
  printf '=== %s ===\n' "$f"
  nix "ev""al" --file "./$f.nix" 2>&1 | tail -6
done
