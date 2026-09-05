#!/bin/sh
# Does the edited .aerospace.toml survive both parsers?
#  1. builtins.fromTOML, via the module's lib.importTOML
#  2. AeroSpace itself, via the generated file
set -e
cd /Users/david/.config/nixos-config/.claude/worktrees/aerospace-toml-1-1-spike

echo "=== 1. nix build of the darwin system ==="
nix build --no-link --print-out-paths \
  ".#darwinConfigurations.David-M4-Max.system" 2>&1 | tail -20
