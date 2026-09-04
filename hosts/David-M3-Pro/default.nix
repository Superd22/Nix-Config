# David's M3 Pro MacBook.
#
# The directory name is the flake attribute name and matches `hostname -s`,
# so `nix run .#build-switch` picks this host with no argument.
#
# hosts/common/darwin.nix is composed in by flake.nix; this file holds only
# what is specific to this machine. That is currently nothing: the user name,
# the package lists and the work-specific bits are still hardcoded in modules/,
# and move here as the options schema (#2), the enable flags (#3) and the
# package lists (#9) land.
{ ... }:

{
}
