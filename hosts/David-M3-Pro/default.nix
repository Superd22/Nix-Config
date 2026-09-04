# David's M3 Pro MacBook.
#
# The directory name is the flake attribute name and matches `hostname -s`,
# so `nix run .#build-switch` picks this host with no argument.
#
# hosts/common/darwin.nix is composed in by flake.nix; this file holds only
# what is specific to this machine: currently the identity that used to be
# duplicated as `let user = "david"` across five module files (#2). The enable
# flags (#3) and the package lists (#9) move here as those issues land.
{ ... }:

{
  mine.user = {
    name = "david";
    fullName = "David";
    email = "superd001@gmail.com";
  };
}
