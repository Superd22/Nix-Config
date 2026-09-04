# Built by flake.nix into a writeShellApplication; run with `nix run .#build`.
#
# Usage: build [HOST] [nix build args...]
# HOST defaults to this machine's short hostname, which is also the name of the
# directory under hosts/ that configures it.

GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

# Default to this machine; an explicit first argument names another host.
HOST="${1:-$(hostname -s)}"
if [ "$#" -gt 0 ]; then shift; fi

FLAKE_SYSTEM="darwinConfigurations.${HOST}.system"

export NIXPKGS_ALLOW_UNFREE=1

echo "${YELLOW}Starting build for ${HOST}...${NC}"
nix --extra-experimental-features 'nix-command flakes' build ".#${FLAKE_SYSTEM}" "$@"

echo "${YELLOW}Cleaning up...${NC}"
unlink ./result

echo "${GREEN}Build complete!${NC}"
