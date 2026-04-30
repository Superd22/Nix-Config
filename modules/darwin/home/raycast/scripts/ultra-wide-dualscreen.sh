#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Ultra-Wide Dual Screen
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName KVM

# Ensure aerospace is enabled
echo "Checking aerospace status..."
if ! /Users/david/.nix-profile/bin/aerospace list-windows --focused &>/dev/null; then
    echo "Aerospace appears to be disabled. Enabling it..."
    /Users/david/.nix-profile/bin/aerospace enable on
    sleep 1
else
    echo "Aerospace is already enabled."
fi

# Get JSON info of all displays
displays=$(betterdisplaycli get -identifiers)

# Check if Odyssey G93SC is connected
if echo "$displays" | betterdisplaycli get -identifiers | paste -sd '\0' - | sed 's/^/[/' | sed 's/$/]/' | jq -e 'map(select(.name == "Odyssey G93SC")) | length > 0' > /dev/null; then
    echo "Odyssey G93SC is connected. Setting up full-size PiP windows..."

    # Make sure Left is the main screen
    echo "Setting Left as the main screen..."
    betterdisplaycli set -name="Left" -main=on

    # First disable PiP for both monitors
    echo "Disabling PiP for Left and Right monitors..."
    betterdisplaycli set -name="Left" -pip=off
    betterdisplaycli set -name="Right" -pip=off

    # Re-enable and configure Left monitor PiP
    echo "Configuring Left monitor PiP..."
    betterdisplaycli set -name="Left" -pip=on -targetName="Odyssey G93SC" -originX=0% -originY=0% -width=50% -height=100% -priority=absolute -showTitlebar=off -showShadow=off -unmovable=on -clickthrough=on

    # Re-enable and configure Right monitor PiP
    echo "Configuring Right monitor PiP..."
    betterdisplaycli set -name="Right" -pip=on -targetName="Odyssey G93SC" -originX=50% -originY=0% -width=50% -height=100% -priority=absolute -showTitlebar=off -showShadow=off -unmovable=on -clickthrough=on

     # Put everything in odyssey but the pip windows on the left
     /Users/david/.nix-profile/bin/aerospace list-workspaces --all --format "%{workspace} %{monitor-name}" --json | jq -r '.[] | select(.["monitor-name"] != "Left" and .["monitor-name"] != "Right") | .["workspace"]' | while read -r id; do
         /Users/david/.nix-profile/bin/aerospace move-workspace-to-monitor --workspace "$id" "Left"
     done
    #  aerospace move-workspace-to-monitor --workspace "1" --monitor "Left"
# /Users/david/.nix-profile/bin/aerospace list-windows --all --json --format "%{window-id}%{monitor-name}" | jq -r '.[] | select(.["monitor-name"] != "Left" and .["monitor-name"] != "Right") | .["window-id"]' | while read -r id; do
#     /Users/david/.nix-profile/bin/aerospace move-node-to-monitor --window-id "$id" "Left"
# done

     # Move non-BetterDisplay windows from workspace BD to workspace 1
     echo "Checking for non-BetterDisplay windows in workspace BD..."
     /Users/david/.nix-profile/bin/aerospace list-windows --workspace BD --json 2>/dev/null | jq -r '.[] | select(.["app-name"] != "BetterDisplay") | .["window-id"]' | while read -r window_id; do
         echo "  Moving non-BetterDisplay window $window_id from workspace BD to workspace 1"
         /Users/david/.nix-profile/bin/aerospace move-node-to-workspace --window-id "$window_id" 1
     done

     # Restore saved window positions if they exist
     TEMP_FILE="/tmp/aerospace-window-positions.json"
     if [ -f "$TEMP_FILE" ]; then
         echo "Restoring saved window positions..."
         jq -c '.[]' "$TEMP_FILE" | while read -r entry; do
             window_id=$(echo "$entry" | jq -r '.window_id')
             workspace=$(echo "$entry" | jq -r '.workspace')
             echo "  Restoring window $window_id to workspace $workspace"
             /Users/david/.nix-profile/bin/aerospace move-node-to-workspace --window-id "$window_id" "$workspace" 2>/dev/null || true
         done
         echo "Deleting saved window positions file..."
         rm "$TEMP_FILE"
     else
         echo "No saved window positions found."
     fi

     # Move windows from workspaces > 10 to workspace 1
     echo "Checking for windows in workspaces > 10..."
     /Users/david/.nix-profile/bin/aerospace list-workspaces --all --json | jq -r '.[] | select(.workspace | tonumber? != null and tonumber > 10) | .workspace' | while read -r workspace; do
         echo "Found workspace: $workspace"
         /Users/david/.nix-profile/bin/aerospace list-windows --workspace "$workspace" --json | jq -r '.[]["window-id"]' | while read -r window_id; do
             echo "  Moving window $window_id from workspace $workspace to workspace 1"
             /Users/david/.nix-profile/bin/aerospace move-node-to-workspace --window-id "$window_id" 1
         done
     done

     # Ensure Left and Right monitors are on workspaces <= 10
     echo "Checking monitor workspace assignments..."
     left_workspace=$(/Users/david/.nix-profile/bin/aerospace list-workspaces --monitor "Left" --json 2>/dev/null | jq -r '.[0].workspace // empty')
     right_workspace=$(/Users/david/.nix-profile/bin/aerospace list-workspaces --monitor "Right" --json 2>/dev/null | jq -r '.[0].workspace // empty')
     
     if [ -n "$left_workspace" ] && [ "$left_workspace" -gt 10 ] 2>/dev/null; then
         echo "Left monitor is on workspace $left_workspace (> 10), moving workspace 1 to Left monitor..."
         /Users/david/.nix-profile/bin/aerospace move-workspace-to-monitor --workspace 1 "Left"
     else
         echo "Left monitor is on workspace $left_workspace (OK)"
     fi
     
     if [ -n "$right_workspace" ] && [ "$right_workspace" -gt 10 ] 2>/dev/null; then
         echo "Right monitor is on workspace $right_workspace (> 10), moving workspace 2 to Right monitor..."
         /Users/david/.nix-profile/bin/aerospace move-workspace-to-monitor --workspace 2 "Right"
     else
         echo "Right monitor is on workspace $right_workspace (OK)"
     fi
     
     # Also ensure both workspaces 1 and 2 are on the correct monitors
     echo "Ensuring workspace 1 is on Left and workspace 2 is on Right..."
     /Users/david/.nix-profile/bin/aerospace move-workspace-to-monitor --workspace 1 "Left" 2>/dev/null || true
     /Users/david/.nix-profile/bin/aerospace move-workspace-to-monitor --workspace 2 "Right" 2>/dev/null || true




else
    echo "Odyssey G93SC not connected. Disabling all PiP windows..."
    betterdisplaycli set -name=Left -pip=off
    betterdisplaycli set -name=Right -pip=off
fi
