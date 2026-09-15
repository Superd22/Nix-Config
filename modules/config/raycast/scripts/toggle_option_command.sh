# Built by modules/desktop/raycast into ~/.config/raycast/scripts, which is
# where the shebang and the PATH for `aerospace` / `betterdisplaycli` are
# added; this file is not meant to run straight out of the working tree.


# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title External keyboard layout swap
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon ⌨️
# @raycast.packageName KVM


# Script to toggle between normal and swapped states for Option and Command keys
# Usage: ./toggle_option_command.sh

# Define state file location
STATE_FILE="$HOME/.option_command_swapped"

# Selects a keyboard layout system-wide via the Carbon TIS API. GUI scripting
# (System Events "keyboard layout" menu) needs the target already added in
# System Settings and Accessibility access; TISSelectInputSource needs neither
# -- it enables the layout if needed and switches to it directly.
select_layout() {
    swift - "$1" <<'EOF'
import Carbon
import Foundation
let target = CommandLine.arguments[1]
let props: [CFString: Any] = [kTISPropertyInputSourceID: target]
guard let list = TISCreateInputSourceList(props as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource],
      let src = list.first else {
    print("keyboard layout not found: \(target)")
    exit(1)
}
_ = TISEnableInputSource(src)
let status = TISSelectInputSource(src)
if status != noErr {
    print("failed to select \(target): \(status)")
    exit(1)
}
EOF
}

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
    select_layout com.apple.keylayout.French-PC
    echo "1" > "$STATE_FILE"
    echo "Option and Command keys are now SWAPPED, layout set to French - PC (AZERTY)"
else
    # Keys are currently swapped, restore them
    hidutil property --set '{"UserKeyMapping":[]}'
    select_layout com.apple.keylayout.French
    echo "0" > "$STATE_FILE"
    echo "Option and Command keys are now NORMAL, layout restored to French (AZERTY)"
fi

exit 0

