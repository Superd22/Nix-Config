# Built by flake.nix into a writeShellApplication; run with `nix run .#rollback`.
#
# Usage: rollback [HOST]
# HOST defaults to this machine's short hostname, which is also the name of the
# directory under hosts/ that configures it.

GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
NC=$'\033[0m'

# Default to this machine; an explicit first argument names another host.
HOST="${1:-$(hostname -s)}"

echo "${YELLOW}Available generations:${NC}"
/run/current-system/sw/bin/darwin-rebuild --list-generations

echo "${YELLOW}Enter the generation number for rollback:${NC}"
read -r GEN_NUM

if [ -z "$GEN_NUM" ]; then
  echo "${RED}No generation number entered. Aborting rollback.${NC}"
  exit 1
fi

echo "${YELLOW}Rolling back ${HOST} to generation ${GEN_NUM}...${NC}"
# --switch-generation moves the profile and activates what it points at, with
# no evaluation, so it needs no --flake. It does need root: darwin-rebuild
# refuses to activate without it.
sudo /run/current-system/sw/bin/darwin-rebuild --switch-generation "$GEN_NUM"

echo "${GREEN}Rollback to generation $GEN_NUM complete!${NC}"
