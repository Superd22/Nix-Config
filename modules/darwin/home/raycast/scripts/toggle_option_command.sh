#!/bin/bash


# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title External keyboard layout swap
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName Raycast Scripts


# Script to toggle between normal and swapped states for Option and Command keys
# Usage: ./toggle_option_command.sh

# Define state file location
STATE_FILE="$HOME/.option_command_swapped"

# Check if state file exists, if not create it with default state (not swapped)
if [ ! -f "$STATE_FILE" ]; then
    echo "0" > "$STATE_FILE"
fi

# Read current state
CURRENT_STATE=$(cat "$STATE_FILE")

if [ "$CURRENT_STATE" == "0" ]; then
    # Keys are currently NOT swapped, swap them
    hidutil property --set '{"UserKeyMapping":[
        {"HIDKeyboardModifierMappingSrc":0x7000000E2,"HIDKeyboardModifierMappingDst":0x7000000E3},
        {"HIDKeyboardModifierMappingSrc":0x7000000E3,"HIDKeyboardModifierMappingDst":0x7000000E2}
    ]}'
    echo "1" > "$STATE_FILE"
    echo "Option and Command keys are now SWAPPED"
else
    # Keys are currently swapped, restore them
    hidutil property --set '{"UserKeyMapping":[]}'
    echo "0" > "$STATE_FILE"
    echo "Option and Command keys are now NORMAL"
fi

exit 0

