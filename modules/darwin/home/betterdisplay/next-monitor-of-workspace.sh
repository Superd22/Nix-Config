#!/bin/sh

# Scripts to get the next monitor of a workspace in BetterDisplay
# Usage: ./next-monitor-of-workspace.sh <workspace-name>
# Example: ./next-monitor-of-workspace.sh "1"
result=$(/Users/david/.nix-profile/bin/aerospace list-workspaces --all --json  --format "%{workspace}%{monitor-name}" | jq -r --arg ws "$1" '
  map(select(.workspace == $ws)) | .[0]."monitor-name" as $mon |
  if $mon == "Left" then "Right"
  elif $mon == "Right" then "Left"
  else $mon
  end')

if [ ! -z "$result" ]; then
  /Users/david/.nix-profile/bin/aerospace move-workspace-to-monitor --workspace $1 "$result"
fi