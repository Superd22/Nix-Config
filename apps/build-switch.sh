# Built by flake.nix into a writeShellApplication; run with `nix run .#build-switch`.

GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

SYSTEM_TYPE="aarch64-darwin"
FLAKE_SYSTEM="darwinConfigurations.${SYSTEM_TYPE}.system"

export NIXPKGS_ALLOW_UNFREE=1

echo "${YELLOW}Starting build...${NC}"
nix --extra-experimental-features 'nix-command flakes' build ".#$FLAKE_SYSTEM" "$@"

echo "${YELLOW}Switching to new generation...${NC}"
sudo ./result/sw/bin/darwin-rebuild switch --flake ".#${SYSTEM_TYPE}" "$@"

echo "${YELLOW}Cleaning up...${NC}"
unlink ./result

echo "${GREEN}Switch to new generation complete!${NC}"
