# SketchyBar. This used to read `services.sketchybar.enable = false;` right
# here, which is the anti-pattern #3 exists to remove: the only way to turn it
# on was to edit a file upstream also maintains. The switch now lives on the
# host as `mine.desktop.sketchybar.enable`, and this module only ever turns the
# service on.
{ config, lib, ... }:

{
  config = lib.mkIf config.mine.desktop.sketchybar.enable {
    services.sketchybar.enable = true;
  };
}
