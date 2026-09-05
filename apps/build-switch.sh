# Built by flake.nix into a writeShellApplication; run with `nix run .#build-switch`.
#
# Usage: build-switch [HOST] [nix build args...]
# HOST defaults to this machine's short hostname, which is also the name of the
# directory under hosts/ that configures it.

GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

# Default to this machine; an explicit first argument names another host.
HOST="${1:-$(hostname -s)}"
if [ "$#" -gt 0 ]; then shift; fi

# macOS does not promise a stable case for the short hostname — configd can
# rewrite it from DHCP, and this machine has been seen reporting both
# `david-m4-max` and `David-M4-Max` on the same day. The flake attribute is the
# directory name under hosts/ and is case-sensitive, so a flip turns a working
# `build-switch` into "flake does not provide attribute". Match the directory
# case-insensitively and use the directory's real name.
#
# Done unconditionally rather than behind a `[ -d "hosts/$HOST" ]` guard: the
# filesystem is case-insensitive, so that test passes for `hosts/david-m4-max`
# when the directory is really `David-M4-Max` and would skip the fix-up in
# exactly the case it exists for. Falls through unchanged when nothing matches
# — an unknown host, or being run from outside the repo — so nix still reports
# the error it would have.
host_lower="$(echo "$HOST" | tr '[:upper:]' '[:lower:]')"
for candidate in hosts/*/; do
  candidate="$(basename "$candidate")"
  if [ "$(echo "$candidate" | tr '[:upper:]' '[:lower:]')" = "$host_lower" ]; then
    HOST="$candidate"
    break
  fi
done

FLAKE_SYSTEM="darwinConfigurations.${HOST}.system"

export NIXPKGS_ALLOW_UNFREE=1

echo "${YELLOW}Starting build for ${HOST}...${NC}"
nix --extra-experimental-features 'nix-command flakes' build ".#${FLAKE_SYSTEM}" "$@"

echo "${YELLOW}Switching to new generation...${NC}"
sudo ./result/sw/bin/darwin-rebuild switch --flake ".#${HOST}" "$@"

echo "${YELLOW}Cleaning up...${NC}"
unlink ./result

echo "${GREEN}Switch to new generation complete!${NC}"
