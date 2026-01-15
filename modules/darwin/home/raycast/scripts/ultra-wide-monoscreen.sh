#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Ultra-Wide Mono Screen
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 🎮
# @raycast.packageName KVM

# Get JSON info of all displays
displays=$(betterdisplaycli get -identifiers)

# Check if Odyssey G93SC is connected
if ! echo "$displays" | betterdisplaycli get -identifiers | paste -sd '\0' - | sed 's/^/[/' | sed 's/$/]/' | jq 'map(select(.name == "Odyssey G93SC")) | length > 0'; then
    echo "Odyssey G93SC not connected. Exiting..."
    exit 0
fi

echo "Odyssey G93SC is connected. Setting up mono screen mode..."

# 1. Save the position of every window in workspace 0 to 10
echo "Saving window positions..."
TEMP_FILE="/tmp/aerospace-window-positions.json"

# Get all windows from workspaces 0-10 and save their workspace assignments
/Users/david/.nix-profile/bin/aerospace list-windows --all --json | \
    jq '[.[] | select(.workspace | tonumber? != null and tonumber >= 0 and tonumber <= 10) | {window_id: ."window-id", workspace: .workspace}]' > "$TEMP_FILE"

echo "Saved $(jq 'length' "$TEMP_FILE") window positions to $TEMP_FILE"

# 2. Disable PiP for both monitors
echo "Disabling PiP for Left and Right monitors..."
betterdisplaycli set -name="Left" -pip=off
betterdisplaycli set -name="Right" -pip=off


# 3. Make Odyssey the primary screen
echo "Making Odyssey G93SC the main screen..."
betterdisplaycli set -name="Odyssey G93SC" -main=on

# 4. Move all windows to workspace BD
echo "Moving all windows to workspace BD..."
/Users/david/.nix-profile/bin/aerospace list-windows --all --json | jq -r '.[]["window-id"]' | while read -r window_id; do
    /Users/david/.nix-profile/bin/aerospace move-node-to-workspace --window-id "$window_id" BD 2>/dev/null
done

# 5. Disable aerospace
echo "Disabling aerospace..."
/Users/david/.nix-profile/bin/aerospace enable off

echo "Mono screen mode setup complete!"
