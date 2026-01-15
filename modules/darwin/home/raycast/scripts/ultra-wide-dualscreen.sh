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
if echo "$displays" | betterdisplaycli get -identifiers | paste -sd '\0' - | sed 's/^/[/' | sed 's/$/]/' | jq 'map(select(.name == "Odyssey G93SC")) | length > 0'; then
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

     # Move windows from workspaces > 10 to workspace 1
     echo "Checking for windows in workspaces > 10..."
     /Users/david/.nix-profile/bin/aerospace list-workspaces --all --json | jq -r '.[] | select(.workspace | tonumber? != null and tonumber > 10) | .workspace' | while read -r workspace; do
         echo "Found workspace: $workspace"
         /Users/david/.nix-profile/bin/aerospace list-windows --workspace "$workspace" --json | jq -r '.[]["window-id"]' | while read -r window_id; do
             echo "  Moving window $window_id from workspace $workspace to workspace 1"
             /Users/david/.nix-profile/bin/aerospace move-node-to-workspace --window-id "$window_id" 1
         done
     done

     # Move non-BetterDisplay windows from workspace BD to workspace 1
     echo "Checking for non-BetterDisplay windows in workspace BD..."
     /Users/david/.nix-profile/bin/aerospace list-windows --workspace BD --json 2>/dev/null | jq -r '.[] | select(.["app-bundle-id"] != "pro.betterdisplay.BetterDisplay") | .["window-id"]' | while read -r window_id; do
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




else
    echo "Odyssey G93SC not connected. Disabling all PiP windows..."
    betterdisplaycli set -name=Left -pip=off
    betterdisplaycli set -name=Right -pip=off
fi
