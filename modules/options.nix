# The `mine.*` namespace: everything about this repo that is a property of the
# person or the machine rather than of the software being configured.
#
# It is declared with the module system rather than passed around as
# `specialArgs` on purpose: options get types, error messages that name the
# option that is missing, and a schema that the setup wizard (#5) can read back
# and render as prompts.
#
# Identity has no defaults. A fork that forgets to set `mine.user.name` gets a
# loud "option ... is used but not defined" naming the option, instead of a
# machine quietly configured as david.
{ lib, ... }:

{
  options.mine.user = {
    name = lib.mkOption {
      type = lib.types.str;
      example = "ada";
      description = ''
        Unix account name. Used for the macOS user, the home directory, the
        home-manager user, `system.primaryUser` and the Homebrew owner, so it
        must match the account you actually log in as.
      '';
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      example = "Ada Lovelace";
      description = ''
        Human-readable name, as it should appear in commit authorship.
      '';
    };

    email = lib.mkOption {
      type = lib.types.str;
      example = "ada@example.com";
      description = ''
        Email address used for commit authorship.
      '';
    };
  };
}
