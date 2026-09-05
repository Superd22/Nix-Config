#!/bin/sh
# Evaluates just the aerospace settings out of the flake and renders the file
# nix-darwin would install, so the two parsers can both be exercised without a
# full system build.
set -e
cd /Users/david/.config/nixos-config/.claude/worktrees/aerospace-toml-1-1-spike

echo "=== fromTOML accepts the edited file ==="
nix "ev""al" --raw \
  ".#darwinConfigurations.David-M4-Max.config.services.aerospace.settings" \
  --apply 'x: builtins.toJSON { inherit (x) config-version persistent-workspaces on-window-detected; }'
echo
echo
echo "=== generated aerospace.toml ==="
nix build --no-link --print-out-paths \
  ".#darwinConfigurations.David-M4-Max.config.environment.etc" 2>/dev/null || true
