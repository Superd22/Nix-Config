# Claude Code's configuration: skills, settings, and the MCP server list (#36).
#
# This is a *nix-darwin* module, not a home-manager one, for the same reason
# modules/programs/datagrip is: it owns files in the home directory and an
# option that modules/work/wemaintain contributes to, and both belong to the
# same "I use Claude Code" switch. It is imported by modules/home-manager.nix
# and deliberately not by modules/programs/default.nix.
#
#
# THIS MODULE GENERATES ALMOST NOTHING, WHICH IS THE POINT
#
# Everything else in this repo owns the content of the files it manages and
# renders them from nix. This module mostly does not: `~/.claude/settings.json`
# and `~/.claude/skills` are symlinks pointing *back into the working tree* at
# modules/config/claude, so the file Claude Code reads and the file git tracks
# are the same file.
#
# That is the "adopt in place" path in docs/two-paths.md, and it is chosen here
# because skills get written most days — often by Claude itself, mid-session.
# Any workflow with a per-skill step (declare it, rebuild, re-run) is a step
# that gets skipped, and then the drift this module exists to kill is back.
# Under the symlinks there is only ever one copy of the file, so a skill written
# tomorrow is an untracked file in this repo the moment it is saved, and an
# "always allow" is a `git diff`. Nothing to remember and no rebuild.
#
# Three things had to be true for this to work, and all three were tested
# rather than assumed (`CLAUDE_CONFIG_DIR` points Claude Code at a throwaway
# config directory, which is how):
#
#   - Claude Code writes settings.json *in place*, following the symlink rather
#     than replacing it, and merges its change instead of clobbering the file.
#   - Skill discovery follows symlinks.
#   - `mcpServers` in settings.json is ignored. It is read only from
#     ~/.claude.json, which is why that one is handled differently below.
#
# The costs, which are real:
#
#   - `git` now moves live configuration. Checking out an older commit rewrites
#     the skills of any Claude Code session running at that moment, and
#     `git clean -fdx` deletes them.
#   - nix cannot template these files per host. There is no way to give a fork
#     a different settings.json, so `enabledPlugins` and `extraKnownMarketplaces`
#     in there are simply David's, and a fork is expected to edit them.
#   - Anything typed into settings.json or a skill is in the working tree
#     immediately, with no prompt in between. See the secret scan below.
#
#
# MCP SERVERS TAKE THE OTHER PATH
#
# They live only in ~/.claude.json: 85 KB of mostly machine state — caches,
# telemetry, `oauthAccount`, per-project history. That file cannot be a symlink
# into a git repo, so its configuration gets generated and merged instead:
#
#   modules/config/claude/mcp-servers.json  the personal servers, hand-edited
#   mine.programs.claude-code.extraMcpServers  contributed by other modules,
#                                              which is how the WeMaintain ones
#                                              arrive behind their own flag
#
# The activation below merges both into ~/.claude.json, preserving every other
# key. And because `claude mcp add` still works and still writes only to
# ~/.claude.json, it also does the reverse: a server found on disk that nothing
# declares is appended to mcp-servers.json, so it turns up in `git status`
# rather than being lost on the next machine. Servers carrying `headers` or
# `env` are never written back — that is where `claude mcp add --header
# "Authorization: Bearer …"` would put a token.
{ config, lib, pkgs, ... }:

let
  cfg = config.mine.programs.claude-code;
  user = config.mine.user.name;
  home = config.users.users.${user}.home;

  claudeDir = "${cfg.repoPath}/modules/config/claude";

  # The nix-contributed half of the MCP list. Rendered to the store because it
  # is generated; the hand-edited half stays a file in the working tree and is
  # read at activation time, so editing it needs no rebuild.
  extraMcpFile =
    pkgs.writeText "claude-extra-mcp-servers.json" (builtins.toJSON cfg.extraMcpServers);
in
{
  # `mine.programs.claude-code.enable` is declared in modules/options.nix with
  # the other feature flags. These two are declared here, where they are used.
  options.mine.programs.claude-code = {
    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.config/nixos-config";
      description = ''
        Absolute path to this repo's working tree on this machine.

        Unavoidably a path and not a store reference: the whole point is that
        `~/.claude` points at files you can edit without rebuilding, which a
        store path cannot be. Move or rename the checkout and `~/.claude` is
        left pointing at nothing — the activation checks for that and says so.
      '';
    };

    extraMcpServers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      example = {
        sentry = { type = "http"; url = "https://mcp.sentry.dev/mcp"; };
      };
      description = ''
        MCP servers contributed by other modules, merged into `~/.claude.json`
        on top of modules/config/claude/mcp-servers.json.

        This is the seam for servers that belong to a flag rather than to the
        person: `mine.work.wemaintain` puts its gateways here so a fork does not
        inherit endpoints it has no account for. Servers declared this way are
        never written back to mcp-servers.json, since nix already owns them.

        Nothing secret goes here — it is rendered into the world-readable nix
        store. Auth is Claude Code's own OAuth, kept in the macOS keychain.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = { config, lib, ... }: {
      # Out-of-store symlinks: the target is the working tree, not the store,
      # so Claude Code can write through them and the writes land in git.
      #
      # home-manager moves anything already at these paths aside as
      # `.before-nix` (backupFileExtension in modules/home-manager.nix), so the
      # first build-switch on a machine that already had a ~/.claude keeps a
      # copy of what was there.
      home.file = {
        ".claude/settings.json".source =
          config.lib.file.mkOutOfStoreSymlink "${claudeDir}/settings.json";

        # Global instructions, prepended to every session. Shipped empty; it is
        # a seam rather than a suggestion.
        ".claude/CLAUDE.md".source =
          config.lib.file.mkOutOfStoreSymlink "${claudeDir}/CLAUDE.md";

        # The whole directory, not one entry per skill: a new skill has to be
        # able to appear here without nix knowing its name in advance, which is
        # the entire reason this module is shaped this way.
        ".claude/skills".source =
          config.lib.file.mkOutOfStoreSymlink "${claudeDir}/skills";
      };

      home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        jq=${pkgs.jq}/bin/jq
        claudeDir="${claudeDir}"
        repoMcp="$claudeDir/mcp-servers.json"
        target="$HOME/.claude.json"

        if [ ! -d "$claudeDir" ]; then
          # The symlinks above have already been made and are now dangling, so
          # Claude Code will come up with no settings and no skills. Say so
          # loudly: the failure is otherwise silent and looks like data loss.
          echo "claude-code: ${claudeDir} does not exist." >&2
          echo "claude-code: ~/.claude/{settings.json,skills} are dangling symlinks and Claude Code" >&2
          echo "claude-code: will start with no configuration. Either move the checkout back, or set" >&2
          echo "claude-code: mine.programs.claude-code.repoPath to where it actually is." >&2
        else
          # ~/.claude.json is Claude Code's own state file and is created on
          # first run. Seeding an empty object is enough for the merge below;
          # Claude Code fills in the rest.
          if [ ! -e "$target" ]; then
            $DRY_RUN_CMD install -m 0600 /dev/null "$target"
            echo '{}' | $DRY_RUN_CMD tee "$target" > /dev/null
          fi

          # Everything nix and the repo file declare between them.
          declared=$($jq -s '(.[0].mcpServers // {}) * (.[1] // {})' \
            "$repoMcp" ${extraMcpFile})

          # Merge into ~/.claude.json. Declared servers win; every other key in
          # that file, and every server nobody declares, is left alone.
          merged=$(mktemp)
          $jq --argjson declared "$declared" \
            '.mcpServers = ((.mcpServers // {}) * $declared)' "$target" > "$merged"
          if ! ${pkgs.diffutils}/bin/diff -q "$merged" "$target" > /dev/null 2>&1; then
            $DRY_RUN_CMD install -m 0600 "$merged" "$target"
          fi
          rm -f "$merged"

          # The reverse direction: anything `claude mcp add` put on disk that
          # nothing declares. Written back into the working tree so it shows up
          # in `git status` instead of being lost with the machine.
          undeclared=$($jq --argjson declared "$declared" \
            '(.mcpServers // {}) | with_entries(select(.key as $k | ($declared | has($k)) | not))' \
            "$target")

          # `claude mcp add --header "Authorization: Bearer …"` and `-e KEY=…`
          # both land in the server entry. Never copy those into a git repo.
          withSecrets=$($jq -r 'to_entries | map(select(.value.headers or .value.env)) | .[].key' \
            <<< "$undeclared")
          if [ -n "$withSecrets" ]; then
            echo "claude-code: not adopting MCP servers that carry headers or env, which is where" >&2
            echo "claude-code: credentials live. Declare them by hand without the secret if you want" >&2
            echo "claude-code: them versioned:" >&2
            echo "$withSecrets" | sed 's/^/claude-code:   /' >&2
          fi

          adoptable=$($jq 'with_entries(select((.value.headers or .value.env) | not))' <<< "$undeclared")
          if [ "$(${pkgs.jq}/bin/jq -r 'length' <<< "$adoptable")" != "0" ]; then
            adopted=$(mktemp)
            $jq --argjson new "$adoptable" \
              '.mcpServers = ((.mcpServers // {}) * $new)' "$repoMcp" > "$adopted"
            $DRY_RUN_CMD install -m 0644 "$adopted" "$repoMcp"
            rm -f "$adopted"
            echo "claude-code: adopted into $repoMcp (unstaged, commit when you are ready):"
            ${pkgs.jq}/bin/jq -r 'keys[]' <<< "$adoptable" | sed 's/^/claude-code:   /'
          fi

          # settings.json is live-symlinked into the repo, so a credential typed
          # into it is in the working tree with nothing in between. These three
          # keys are the ones that hold or fetch one.
          secretKeys=$($jq -r '[paths(scalars) as $p | $p[0]] | unique
            | map(select(. == "env" or . == "apiKeyHelper" or . == "awsAuthRefresh")) | .[]' \
            "$claudeDir/settings.json" 2>/dev/null || true)
          if [ -n "$secretKeys" ]; then
            echo "claude-code: settings.json sets $(echo "$secretKeys" | tr '\n' ' ')— check no" >&2
            echo "claude-code: credential is about to be committed. This file is versioned." >&2
          fi
        fi
      '';
    };
  };
}
