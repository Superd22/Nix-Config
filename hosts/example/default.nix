# A second host that is not David's machine.
#
# It exists so the repo has a non-personal host that still evaluates, which is
# what CI (#10) checks and what the setup wizard (#5) copies.
#
# The identity below is a deliberate placeholder rather than a default on the
# options themselves: `mine.user.*` has no defaults, so a fork that forgets to
# set them fails with an error naming the option instead of silently building
# as david. This host sets obvious junk so `.#example` keeps evaluating —
# `nix flake show`, `nix flake check` and CI all need it to — while being
# visibly wrong to anyone who actually tries to build it.
#
# It is not derived from hosts/David-M3-Pro and is meant to diverge from it as
# the enable flags (#3) and the package lists (#9) land.
{ ... }:

{
  mine.user = {
    name = "changeme";
    fullName = "Change Me";
    email = "you@example.com";
  };
}
