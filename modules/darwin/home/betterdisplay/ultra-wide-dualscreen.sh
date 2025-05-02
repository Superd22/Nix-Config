#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Toggle Ultra-Wide Dual Screen
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName KVM
# Get JSON info of all displays
displays=$(betterdisplaycli get -identifiers)

# Check if Odyssey G93SC is connected
if echo "$displays" | betterdisplaycli get -identifiers | paste -sd '\0' - | sed 's/^/[/' | sed 's/$/]/' | jq 'map(select(.name == "Odyssey G93SC")) | length > 0'; then
    echo "Odyssey G93SC is connected. Setting up full-size PiP windows..."

    betterdisplaycli set -name="Left" -pip -targetName="Odyssey G93SC" -originX=0% -originY=0% -width=50% -height=100% -priority=absolute -showTitlebar=off -showShadow=off -unmovable=on -clickthrough=on

     # Right monitor PiP setup
     betterdisplaycli set -name="Right" -pip -targetName="Odyssey G93SC" -originX=50% -originY=0% -width=50% -height=100% -priority=absolute -showTitlebar=off -showShadow=off -unmovable=on -clickthrough=on

else
    echo "Odyssey G93SC not connected. Disabling all PiP windows..."
    betterdisplaycli set -name=Left -pip=off
    betterdisplaycli set -name=Right -pip=off
fi
