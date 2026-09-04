# Built by scripts.nix into a writeShellApplication named
# `workspace-to-next-monitor`; `aerospace` and `jq` come from its runtimeInputs,
# so this file is not meant to be run straight out of the working tree.
#
# Usage: workspace-to-next-monitor <workspace-name>
# Example: workspace-to-next-monitor 1
#
# Sends a workspace to the "other" monitor of the pair: Left <-> Right, and the
# ultra-wide back to Left. Bound to ctrl-shift-alt-<N> in .aerospace.toml.
#
# It lives with aerospace rather than with betterdisplay because `aerospace` is
# the only thing it runs. The monitor names it matches on are BetterDisplay's
# virtual screens, but that is a fact about how the displays are arranged at
# runtime, not a dependency on the betterdisplay module (#21).

result=$(aerospace list-workspaces --all --json --format "%{workspace}%{monitor-name}" | jq -r --arg ws "$1" '
  map(select(.workspace == $ws)) | .[0]."monitor-name" as $mon |
  if $mon == "Left" then "Right"
  elif $mon == "Right" then "Left"
  elif $mon == "Odyssey G93SC" then "Left"
else $mon
  end')

if [ -n "$result" ]; then
  aerospace move-workspace-to-monitor --workspace "$1" "$result"
fi
