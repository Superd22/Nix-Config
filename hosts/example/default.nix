# A second host that is not David's machine.
#
# It exists so the repo has a non-personal host that still evaluates, which is
# what CI (#10) checks and what the setup wizard (#5) copies.
#
# It is deliberately empty rather than artificially rich: until the options
# schema (#2), the enable flags (#3) and the package lists (#9) exist, there is
# nothing a generic host can set that would differ from the real one. It is not
# derived from hosts/David-M3-Pro and is meant to diverge from it as those
# issues land.
{ ... }:

{
}
