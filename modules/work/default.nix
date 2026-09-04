# Work environments (#8). One directory per employer, each a nix-darwin module
# gated on its own `mine.work.<name>.enable`, off by default: a fork that does
# not work there flips nothing and gets nothing.
#
# This is deliberately not a generic "profile" mechanism (see hosts/example for
# why profiles were rejected). A team standardising a dev environment is the
# one case where "everyone should get the improvements" holds, and it is built
# concretely, as `mine.work.wemaintain.*`, rather than as machinery.
{ ... }:

{
  imports = [
    ./wemaintain
  ];
}
