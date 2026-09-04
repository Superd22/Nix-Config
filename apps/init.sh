# Built by flake.nix into a writeShellApplication; run with
#   nix run github:Superd22/Nix-Config#init
# or, from a factory Mac, through bootstrap.sh which installs nix first.
#
# The "carbon copy" path of #5: this Mac becomes the same machine as the old
# one, secrets included. The steps, in the only order that works:
#
#   1. clone the (public) config over https, so hosts/ can be read;
#   2. settle the hostname: build-switch builds darwinConfigurations.$(hostname -s),
#      so the Mac's name and a directory under hosts/ have to agree;
#   3. import the key bundle from `keys export` (apps/keys.sh);
#   4. switch the clone to ssh, run `keys doctor`;
#   5. build-switch;
#   6. print what nix cannot do.
#
# Keys before doctor before build: without id_rsa the private `secrets` input
# cannot be fetched and the flake fails at evaluation with an error that
# explains nothing. Nothing here touches the old Mac, and nothing is wiped.
#
# Every answer can be pre-set, so the whole thing runs without a terminal:
#
#   INIT_YES=1 (or --yes)   accept every confirmation
#   INIT_HOSTNAME=name      which host this Mac is (see ask_hostname)
#   INIT_BUNDLE=path        the keys-*.age bundle
#   INIT_DEST=dir           where to clone; default ~/.config/nixos-config
#   INIT_SKIP_BUILD=1       stop after doctor instead of running build-switch
#
# gum draws the prompts and needs /dev/tty; bootstrap.sh takes care of that
# when it is piped from curl. age asks for the bundle passphrase itself, on the
# terminal, so it is never in the environment or on a command line.

REPO_HTTPS="https://github.com/Superd22/Nix-Config.git"
REPO_SSH="git@github.com:Superd22/Nix-Config.git"
DEST="${INIT_DEST:-$HOME/.config/nixos-config}"
SSH_DIR="$HOME/.ssh"
DOCS="docs/new-machine.md"

# One accent everywhere. 212 is Charm's pink; the same on gum 0.17 and 2.x.
ACCENT=212
export GUM_CHOOSE_CURSOR_FOREGROUND=$ACCENT
export GUM_CHOOSE_SELECTED_FOREGROUND=$ACCENT
export GUM_CHOOSE_HEADER_FOREGROUND=$ACCENT
export GUM_CONFIRM_SELECTED_BACKGROUND=$ACCENT
export GUM_CONFIRM_PROMPT_FOREGROUND=$ACCENT
export GUM_INPUT_CURSOR_FOREGROUND=$ACCENT
export GUM_INPUT_HEADER_FOREGROUND=$ACCENT
export GUM_INPUT_PROMPT_FOREGROUND=$ACCENT
export GUM_FILE_CURSOR_FOREGROUND=$ACCENT
export GUM_FILE_HEADER_FOREGROUND=$ACCENT
export GUM_SPIN_SPINNER_FOREGROUND=$ACCENT
export GUM_SPIN_TITLE_FOREGROUND=$ACCENT

for arg in "$@"; do
  case "$arg" in
    --yes | -y) INIT_YES=1 ;;
    -h | --help)
      cat <<'EOF'
Usage: init [--yes]

Every answer can be pre-set, so the whole thing runs without a terminal:
  INIT_YES=1 (or --yes)   accept every confirmation
  INIT_HOSTNAME=name      which host this Mac is
  INIT_BUNDLE=path        the keys-*.age bundle
  INIT_DEST=dir           where to clone; default ~/.config/nixos-config
  INIT_SKIP_BUILD=1       stop after doctor instead of running build-switch
EOF
      exit 0
      ;;
    *) echo "init: unknown argument $arg" >&2; exit 64 ;;
  esac
done

# ---------------------------------------------------------------------------
# Look and feel
# ---------------------------------------------------------------------------

say()  { gum style --foreground "$ACCENT" "$*"; }
note() { gum style --faint "$*"; }
ok()   { gum log --level info "$*"; }
warn() { gum log --level warn "$*"; }
die()  { gum log --level error "$*"; exit 1; }

# A titled box for each step; the number is what the user matches against
# the plan printed at the start.
step() {
  echo
  gum style --border rounded --border-foreground "$ACCENT" --padding "0 2" \
    "$(gum style --bold --foreground "$ACCENT" "$1")" "$2"
}

confirm() {
  [ "${INIT_YES:-}" = 1 ] && return 0
  gum confirm --affirmative "Yes" --negative "No" "$@"
}

banner() {
  gum style --border double --border-foreground "$ACCENT" --align center \
    --padding "1 4" --margin "1 0" \
    "$(gum style --bold --foreground "$ACCENT" '✨  New Mac, same David  ✨')" \
    "" \
    "This Mac becomes a carbon copy of the old one, secrets included." \
    "The old Mac is not touched. Nothing here is wiped."
  gum format <<MD
1. Clone the config to \`$DEST\`
2. Settle the hostname
3. Import the key bundle from \`keys export\`
4. \`keys doctor\`
5. \`build-switch\` (long; asks for sudo)
6. The short list of things nix cannot do
MD
  echo
}

# ---------------------------------------------------------------------------
# 1. clone
# ---------------------------------------------------------------------------

clone_config() {
  step "1 · Clone" "$REPO_HTTPS → $DEST"
  if [ -d "$DEST/.git" ]; then
    ok "already cloned; reusing it"
    return
  fi
  [ -e "$DEST" ] && die "$DEST exists and is not a git checkout; move it aside"
  mkdir -p "$(dirname "$DEST")"
  # Over https: the config is public and there are no ssh keys yet. The
  # remote is switched to ssh once the keys are in (switch_remote_to_ssh).
  gum spin --spinner moon --title "Cloning..." -- \
    git clone --quiet "$REPO_HTTPS" "$DEST"
  ok "cloned"
}

# ---------------------------------------------------------------------------
# 2. hostname
#
# Every directory under hosts/ except common/ and example/ is a machine.
# build-switch builds the one named after `hostname -s`, so there are two
# ways to make a fresh Mac match: rename the Mac after an existing host (a
# true carbon copy), or keep the Mac's name and add hosts/<name> as a copy
# of an existing host. Either is offered; the second commits a new directory.
# ---------------------------------------------------------------------------

known_hosts_dirs() {
  find "$DEST/hosts" -mindepth 1 -maxdepth 1 -type d \
    ! -name common ! -name example -exec basename {} \; | sort
}

in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

# Sets HOST to the chosen name, and COPY_FROM when hosts/<name> has to be
# created from another host. Globals, not an echo: a $(...) would lose the
# second one.
HOST=""
COPY_FROM=""
ask_hostname() {
  local current
  current="$(hostname -s)"
  local known=()
  while IFS= read -r line; do known+=("$line"); done < <(known_hosts_dirs)
  [ "${#known[@]}" -gt 0 ] || die "no hosts under $DEST/hosts; the clone is not what I expected"

  local choice
  if [ -n "${INIT_HOSTNAME:-}" ]; then
    choice="$INIT_HOSTNAME"
    ok "INIT_HOSTNAME says this Mac is '$choice'"
  elif in_list "$current" "${known[@]}"; then
    ok "this Mac is '$current' and hosts/$current exists"
    choice="$current"
  else
    local options=()
    local h
    for h in "${known[@]}"; do
      options+=("Rename this Mac to '$h' (carbon copy of hosts/$h)")
    done
    options+=("Keep '$current' and add hosts/$current as a copy of another host")
    options+=("Another name…")
    local pick
    pick="$(printf '%s\n' "${options[@]}" \
      | gum choose --header "This Mac is called '$current' and no hosts/$current exists. What should it be?")"
    case "$pick" in
      "Rename this Mac to '"*) choice="${pick#Rename this Mac to \'}"; choice="${choice%%\'*}" ;;
      "Keep '"*) choice="$current" ;;
      *) choice="$(gum input --header "Hostname (letters, digits, dashes)" --placeholder "David-M5-Max")" ;;
    esac
  fi

  case "$choice" in
    "" | *[!A-Za-z0-9-]*) die "'$choice' is not a valid LocalHostName (letters, digits and dashes only)" ;;
  esac

  if ! in_list "$choice" "${known[@]}"; then
    if [ "${#known[@]}" -eq 1 ]; then
      COPY_FROM="${known[0]}"
    elif [ -n "${INIT_HOSTNAME:-}" ]; then
      COPY_FROM="${known[0]}"
    else
      COPY_FROM="$(printf '%s\n' "${known[@]}" | gum choose --header "hosts/$choice will be a copy of which host?")"
    fi
  fi
  HOST="$choice"
}

rename_mac() {
  local name="$1"
  say "Renaming this Mac to $name (sudo)."
  sudo -v
  sudo scutil --set LocalHostName "$name"
  sudo scutil --set ComputerName "$name"
  # The kernel hostname follows LocalHostName through configd, usually within
  # a second. build-switch reads it with `hostname -s`.
  local _try
  for _try in 1 2 3 4 5; do
    [ "$(hostname -s)" = "$name" ] && break
    sleep 1
  done
  [ "$(hostname -s)" = "$name" ] || die "hostname -s still says '$(hostname -s)'; open a new terminal and re-run"
  ok "hostname is now $name"
}

# hosts/<new> from hosts/<src>, committed. Signing is off for this one
# commit: home-manager has not written the git config yet, and the GPG key
# may not be imported yet either.
copy_host() {
  local src="$1" new="$2"
  cp -R "$DEST/hosts/$src" "$DEST/hosts/$new"
  # The first comment line names the machine; the rest of the file is the
  # configuration being copied verbatim, which is the point.
  local f="$DEST/hosts/$new/default.nix"
  sed "1s|.*|# $new. Copied from hosts/$src by init on $(date +%F).|" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  local email
  email="$(sed -n 's/^ *email = "\(.*\)";/\1/p' "$DEST/hosts/$new/default.nix" | head -1)"
  git -C "$DEST" add "hosts/$new"
  git -C "$DEST" -c commit.gpgsign=false -c user.name="init" -c user.email="${email:-init@localhost}" \
    commit --quiet -m "hosts: add $new as a copy of $src"
  ok "hosts/$new committed (push it once build-switch has run)"
}

settle_hostname() {
  step "2 · Hostname" "build-switch builds darwinConfigurations.\$(hostname -s)"
  ask_hostname
  [ "$HOST" = "$(hostname -s)" ] || rename_mac "$HOST"
  [ -z "$COPY_FROM" ] || copy_host "$COPY_FROM" "$HOST"
}

# ---------------------------------------------------------------------------
# 3. keys
# ---------------------------------------------------------------------------

import_keys() {
  step "3 · Keys" "id_rsa, id_ed25519 and the GPG key, from the bundle made by 'keys export'"
  if [ -f "$SSH_DIR/id_rsa" ] && [ -f "$SSH_DIR/id_ed25519" ] && [ -z "${INIT_BUNDLE:-}" ]; then
    ok "both ssh keys are already in $SSH_DIR"
    if ! confirm "Import a bundle anyway?"; then
      return
    fi
  fi

  local bundle="${INIT_BUNDLE:-}"
  if [ -z "$bundle" ]; then
    local start="$HOME/Downloads"
    [ -d "$start" ] || start="$HOME"
    note "Pick the keys-<host>-<date>.age file (AirDropped files land in Downloads)."
    bundle="$(gum file --header "Key bundle" --height 12 "$start")"
  fi
  [ -f "$bundle" ] || die "$bundle: no such file"

  say "age will ask for the bundle's passphrase now."
  # keys.sh refuses to overwrite a differing key; that is the right default
  # for a wizard too. --force is a manual decision, see the docs.
  keys import "$bundle"
}

# A fresh Mac has no known_hosts, and `keys doctor` talks to GitHub with
# BatchMode, which cannot answer the host-key question. Trust on first use,
# like the first `git clone` would.
trust_github_host_key() {
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  if ssh-keygen -F github.com -f "$SSH_DIR/known_hosts" >/dev/null 2>&1; then
    return
  fi
  gum spin --spinner moon --title "Adding github.com to known_hosts..." -- \
    sh -c "ssh-keyscan -t ed25519,ecdsa,rsa github.com >> '$SSH_DIR/known_hosts' 2>/dev/null"
  ok "github.com host key recorded"
}

switch_remote_to_ssh() {
  if [ "$(git -C "$DEST" remote get-url origin)" != "$REPO_SSH" ]; then
    git -C "$DEST" remote set-url origin "$REPO_SSH"
    ok "origin now $REPO_SSH"
  fi
}

# ---------------------------------------------------------------------------
# 4. doctor
# ---------------------------------------------------------------------------

run_doctor() {
  step "4 · Doctor" "proves every key is in place before anything is built"
  trust_github_host_key
  switch_remote_to_ssh
  # Not in a spinner: its lines are the report, and the agenix check may
  # fetch inputs for a while with nix's own progress output.
  if ! (cd "$DEST" && keys doctor); then
    echo
    die "doctor failed. Fix the line it names and re-run init. Do not wipe the old Mac."
  fi
}

# ---------------------------------------------------------------------------
# 5. build-switch
# ---------------------------------------------------------------------------

run_build_switch() {
  step "5 · Build and switch" "darwin-rebuild switch as root, then Homebrew and every cask"
  if [ "${INIT_SKIP_BUILD:-}" = 1 ]; then
    warn "INIT_SKIP_BUILD is set; stopping here. Later: cd $DEST && nix run .#build-switch"
    exit 0
  fi
  note "The first run builds the world. Its output streams below; sudo asks once."
  if ! confirm "Build and switch now?"; then
    say "Later, then:  cd $DEST && nix run .#build-switch"
    exit 0
  fi
  sudo -v
  (cd "$DEST" && build-switch "$HOST")
}

# ---------------------------------------------------------------------------
# 6. after
# ---------------------------------------------------------------------------

push_host_if_new() {
  [ -n "$COPY_FROM" ] || return 0
  if confirm "Push hosts/$HOST to GitHub?"; then
    git -C "$DEST" push --quiet origin HEAD
    ok "pushed"
  else
    note "Later:  git -C $DEST push"
  fi
}

checklist() {
  step "6 · Not nix's job" "see $DOCS, 'Things nix does not do for you'"
  gum format <<'MD'
- **Open a new terminal.** The one you are in predates the switch.
- **App logins**: Docker Desktop, Slack, Spotify, Steam, NordVPN, Pritunl, ZeroTier, Parsec, 1Password.
- **Raycast**: point it at `modules/config/raycast/`, import its settings export.
- **AWS SSO**: copy `~/.aws/` from the old Mac, then `aws sso login`.
- **Monitor names**: rename them `Left` and `Right` in BetterDisplay.
- **macOS permissions**: Accessibility for aerospace, Screen Recording for the lock monitor and OBS.
- **The old Mac**: only now, and only after the bundle has a second copy somewhere safe. Section 9 of the doc.
MD
  echo
  gum style --bold --foreground "$ACCENT" "Done. Welcome home. 🏡"
}

# ---------------------------------------------------------------------------

main() {
  banner
  local me="I'm David, moving to this Mac from my old one"
  local who="$me"
  if [ "${INIT_YES:-}" != 1 ]; then
    who="$(printf '%s\n' "$me" \
      "I'm someone else, and want my own copy of this setup" \
      | gum choose --header "Who is this for?")"
  fi
  case "$who" in
    "$me") ;;
    *)
      echo
      say "The fork-and-prune wizard is not written yet (issue #5 tracks it)."
      note "Until then: $DOCS, section 'From scratch', and hosts/example as the seed."
      exit 0
      ;;
  esac
  confirm "Start?" || exit 130

  clone_config
  settle_hostname
  import_keys
  run_doctor
  run_build_switch
  push_host_if_new
  checklist
}

main
