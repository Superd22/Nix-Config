# Built by flake.nix into a writeShellApplication; run with
#   nix run github:Superd22/Nix-Config#init
# or, from a factory Mac, through bootstrap.sh which installs nix first.
#
# Two paths, picked by the first question.
#
# "I'm someone else" (#5) turns this Mac into its owner's own copy of the
# setup: their repo, their hostname, their identity, the WeMaintain toggle
# (on by default for colleagues), then what to switch off, their keys, and
# build-switch. It writes exactly one file, hosts/<name>/default.nix, starting
# from hosts/example, and a re-run reads that file back as the defaults. See
# the "Someone else" section further down.
#
# "I'm David" is the "carbon copy" path: this Mac becomes the same machine as
# the old one, secrets included. The steps, in the only order that works:
#
#   1. clone the (public) config over https, so hosts/ can be read;
#   2. settle the hostname: build-switch builds darwinConfigurations.$(hostname -s),
#      so the Mac's name and a directory under hosts/ have to agree;
#   3. import the key bundle from `keys export` (apps/keys.sh);
#   4. switch the clone to ssh, run `keys doctor`;
#   5. build-switch;
#   6. wm-login, the browser logins nix cannot do (when the host has the
#      WeMaintain module on, #29 / #32);
#   7. print what nix cannot do.
#
# Keys before doctor before build: without id_rsa the private `secrets` input
# cannot be fetched and the flake fails at evaluation with an error that
# explains nothing. Nothing here touches the old Mac, and nothing is wiped.
#
# Every answer can be pre-set, so the whole thing runs without a terminal:
#
#   INIT_YES=1 (or --yes)   accept every confirmation
#   INIT_WHO=david|other    which path; --yes alone means david
#   INIT_HOSTNAME=name      which host this Mac is (see ask_hostname)
#   INIT_BUNDLE=path        the keys-*.age bundle
#   INIT_DEST=dir           where to clone; default ~/.config/nixos-config
#   INIT_UPSTREAM=url       what to clone; default the public repo (CI: the checkout)
#   INIT_SKIP_BUILD=1       stop after doctor instead of running build-switch
#
# and for INIT_WHO=other:
#
#   INIT_WORK=0|1           works at WeMaintain; default 1
#   INIT_REPO=clone|private|fork   default clone
#   INIT_REPO_NAME=name     the GitHub repo to create; default nix-config
#   INIT_FULLNAME, INIT_EMAIL      mine.user.fullName and .email
#   INIT_GITHUB_KEY=name|none      file under ~/.ssh GitHub knows you by
#   INIT_SIGN=0|1           sign commits with GPG; default off
#   INIT_CLAUDE=0|1         ~/.claude into this repo; default off
#
# gum draws the prompts and needs /dev/tty; bootstrap.sh takes care of that
# when it is piped from curl. age asks for the bundle passphrase itself, on the
# terminal, so it is never in the environment or on a command line.

REPO_HTTPS="https://github.com/Superd22/Nix-Config.git"
REPO_SSH="git@github.com:Superd22/Nix-Config.git"
UPSTREAM="${INIT_UPSTREAM:-$REPO_HTTPS}"
UPSTREAM_SLUG="Superd22/Nix-Config"
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
  INIT_WHO=david|other    which path; --yes alone means david
  INIT_HOSTNAME=name      which host this Mac is
  INIT_BUNDLE=path        the keys-*.age bundle (david)
  INIT_DEST=dir           where to clone; default ~/.config/nixos-config
  INIT_UPSTREAM=url       what to clone; default the public repo
  INIT_SKIP_BUILD=1       stop after doctor instead of running build-switch

Someone else (INIT_WHO=other):
  INIT_WORK=0|1           works at WeMaintain; default 1
  INIT_REPO=clone|private|fork   your own copy on GitHub; default clone
  INIT_REPO_NAME=name     the repo to create; default nix-config
  INIT_FULLNAME=...       commit author name
  INIT_EMAIL=...          commit author email
  INIT_GITHUB_KEY=name|none      file under ~/.ssh GitHub knows you by
  INIT_SIGN=0|1           sign commits with GPG; default 0
  INIT_CLAUDE=0|1         point ~/.claude into the repo; default 0
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
ok()   { gum style --foreground "$ACCENT" "  ✓ $*"; }
warn() { gum style --foreground 214 "  ! $*"; }
die()  { gum style --foreground 196 "  ✗ $*" >&2; exit 1; }

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
6. \`wm-login\`: AWS and the VPN profile, in the browser
7. The short list of things nix cannot do
MD
  echo
}

# Where a bundle plausibly is: AirDrop lands in Downloads, Finder copies land
# on the Desktop or in ~, and an external disk is a /Volumes child. Newest
# first, because the freshest export is the one you just made.
#
# Not `gum file`: its picker under-renders on gum 2.x (neither the header nor
# the first entry is drawn), so a Downloads holding only the bundle looks like
# an empty list. A `gum choose` over these paths shows every candidate.
find_bundles() {
  local list
  list="$(find "$HOME/Downloads" "$HOME/Desktop" "$HOME" "$DEST" /Volumes/*/ \
    -maxdepth 1 -name 'keys-*.age' 2>/dev/null | sort -u || true)"
  [ -n "$list" ] || return 0
  # `ls -t` and not `stat -f %m`: the devShell puts coreutils ahead of
  # /usr/bin, where -f means something else entirely.
  printf '%s\n' "$list" | tr '\n' '\0' | xargs -0 ls -td --
}

# What is already on this Mac, before anything is asked. A rerun after a
# failure should read as "picking up where it stopped", not as a fresh start.
situation() {
  local current
  current="$(hostname -s)"
  local clone="not yet"
  [ -d "$DEST/.git" ] && clone="already at $DEST"
  local host="no hosts/$current in the config yet, so step 2 will ask"
  if [ -d "$DEST/hosts/$current" ]; then
    host="hosts/$current exists"
  elif [ -n "${INIT_HOSTNAME:-}" ]; then
    host="INIT_HOSTNAME=$INIT_HOSTNAME"
  fi
  local keys="none, step 3 imports them"
  if [ -f "$SSH_DIR/id_rsa" ] && [ -f "$SSH_DIR/id_ed25519" ]; then
    keys="id_rsa and id_ed25519 already in $SSH_DIR"
  elif [ -f "$SSH_DIR/id_rsa" ] || [ -f "$SSH_DIR/id_ed25519" ]; then
    keys="only one of id_rsa / id_ed25519 is in $SSH_DIR; step 3 imports the bundle"
  fi
  local bundles
  bundles="$(find_bundles | head -3 | tr '\n' ' ')"
  gum style --border rounded --border-foreground "$ACCENT" --padding "0 2" \
    "$(gum style --bold --foreground "$ACCENT" 'Found on this Mac')" \
    "user       $USER" \
    "hostname   $current" \
    "host dir   $host" \
    "clone      $clone" \
    "keys       $keys" \
    "bundle     ${bundles:-none seen in Downloads, Desktop, ~ or /Volumes; have it AirDropped before step 3}"
  echo
}

# ---------------------------------------------------------------------------
# 1. clone
# ---------------------------------------------------------------------------

clone_config() {
  step "1 · Clone" "$UPSTREAM → $DEST"
  if [ -d "$DEST/.git" ]; then
    ok "already cloned; reusing it"
    return
  fi
  [ -e "$DEST" ] && die "$DEST exists and is not a git checkout; move it aside"
  mkdir -p "$(dirname "$DEST")"
  # Over https: the config is public and there are no ssh keys yet. The
  # remote is switched to ssh once the keys are in (switch_remote_to_ssh).
  gum spin --spinner moon --title "Cloning..." -- \
    git clone --quiet "$UPSTREAM" "$DEST"
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
    local found typed="Somewhere else — type the path"
    found="$(find_bundles)"
    if [ -n "$found" ]; then
      bundle="$(printf '%s\n%s\n' "$found" "$typed" \
        | gum choose --header "Which key bundle? (newest first)")"
    else
      note "No keys-<host>-<date>.age in Downloads, Desktop, ~ or /Volumes."
    fi
    if [ -z "$bundle" ] || [ "$bundle" = "$typed" ]; then
      note "Drag the file onto this window to fill in its path, then press enter."
      bundle="$(gum input --placeholder "$HOME/Downloads/keys-<host>-<date>.age")"
      # Finder's drag-and-drop escapes spaces and may quote the whole path.
      bundle="$(printf '%s' "$bundle" | sed -e 's/^ *//' -e 's/ *$//' -e "s/^['\"]//" -e "s/['\"]$//" -e 's/\\ / /g')"
      # shellcheck disable=SC2088  # matching a literal ~ the user typed, not expanding one
      case "$bundle" in "~/"*) bundle="$HOME/${bundle#\~/}" ;; esac
    fi
  fi
  [ -n "$bundle" ] || die "no bundle given; re-run with INIT_BUNDLE=/path/to/keys-....age"
  [ -f "$bundle" ] || die "$bundle: no such file"

  say "age asks for the bundle's passphrase next; that prompt is age's own, not mine."
  note "A wrong passphrase fails with 'incorrect passphrase'. Nothing is written; re-run init and try again."
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

# $1 is the step label, which differs between the two paths. With the
# WeMaintain toggle on (someone else's path only), the one build that
# fetches the private `wm` input is given gh as its git credential helper:
# modules/programs/git.nix installs that helper, but only once this build
# has switched (#5). GIT_CONFIG_* is the env form of `git -c`, so nothing is
# written to a gitconfig that would outlive the switch.
run_build_switch() {
  step "${1:-5} · Build and switch" "darwin-rebuild switch as root, then Homebrew and every cask"
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
  if [ "${WORK:-0}" = 1 ]; then
    (cd "$DEST" && GIT_CONFIG_COUNT=2 \
      GIT_CONFIG_KEY_0=credential.https://github.com.helper GIT_CONFIG_VALUE_0='' \
      GIT_CONFIG_KEY_1=credential.https://github.com.helper \
      GIT_CONFIG_VALUE_1='!gh auth git-credential' \
      build-switch "$HOST")
  else
    (cd "$DEST" && build-switch "$HOST")
  fi
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

# The browser logins nix cannot do (#29, #32): AWS SSO and minting
# the VPN profile. Only on hosts with the WeMaintain module on, which is what
# puts wm-login into the system profile. The shell running init predates the
# switch, so it is reached by absolute path.
WM_LOGIN=/run/current-system/sw/bin/wm-login
work_logins() {
  step "${1:-6} · Work logins" "AWS SSO and the VPN profile, each a browser consent screen"
  if [ ! -x "$WM_LOGIN" ]; then
    note "This host has no wm-login (mine.work.wemaintain.enable is off); nothing to do."
    return
  fi
  note "Each one opens the browser and waits. Later, 'wm-login' redoes any that expired."
  if ! confirm "Run wm-login now?"; then
    say "Later, then:  wm-login"
    return
  fi
  "$WM_LOGIN" || warn "wm-login did not finish; run it again from a new terminal."
}

checklist() {
  step "7 · Not nix's job" "see $DOCS, 'Things nix does not do for you'"
  gum format <<'MD'
- **Open a new terminal.** The one you are in predates the switch.
- **App logins**: Docker Desktop, Slack, Spotify, Steam, NordVPN, ZeroTier, Parsec, 1Password. Not Pritunl: `wm-login` minted its profile.
- **Raycast**: point it at `modules/config/raycast/`, import its settings export.
- **Cloud logins**: done by `wm-login` just now. Run it again whenever `withPg` fails with an SSO error. A hand-written `~/.aws/config` from before is at `~/.aws/config.before-nix`.
- **Monitor names**: rename them `Left` and `Right` in BetterDisplay.
- **macOS permissions**: Accessibility for aerospace, Screen Recording for the lock monitor and OBS.
- **The old Mac**: only now, and only after the bundle has a second copy somewhere safe. Section 9 of the doc.
MD
  echo
  gum style --bold --foreground "$ACCENT" "Done. Welcome home. 🏡"
}

# ---------------------------------------------------------------------------

# ===========================================================================
# Someone else (#5)
#
# A fresh Mac, or someone else's, to its owner's own copy of this setup. The
# main audience is WeMaintain colleagues, so the work module is a question
# asked early and on by default; a fork with no WeMaintain access answers no
# and never fetches the private `wm` input.
#
# Subtractive: the defaults are hosts/example (or, on a re-run, this Mac's
# own host file), and every question is what to keep. Pruning is flags, never
# deleted files. The one file written is hosts/<name>/default.nix, and it is
# shown as a diff before it is committed.
# ===========================================================================

WM_BOOTSTRAP_URL="https://wemaintain.github.io/devenv/bootstrap.sh"
WORK=0
FACTS=""
FACTS_FROM=""

other_banner() {
  gum style --border double --border-foreground "$ACCENT" --align center \
    --padding "1 4" --margin "1 0" \
    "$(gum style --bold --foreground "$ACCENT" '✨  Your own copy  ✨')" \
    "" \
    "Starts from hosts/example and asks what to keep." \
    "Writes one file, hosts/<this Mac>/default.nix, and shows it before committing."
  gum format <<MD
1. Who you are, and whether you work at WeMaintain
2. Your own repo on GitHub, or just a clone for now
3. The hostname
4. Name and email, for commits
5. The work environment (WeMaintain only): GitHub login and access check
6. What to keep: desktop, programs, apps
7. Keys: a GitHub SSH key, GPG if you sign commits
8. \`build-switch\`, then \`wm-login\` at work
9. The short list of things nix cannot do
MD
  echo
}

# INIT_<name> if set; otherwise the default under --yes; otherwise ask.
ask_bool() {
  local var="$1" default="$2" question="$3"
  local preset="${!var:-}"
  if [ -n "$preset" ]; then [ "$preset" = 1 ]; return; fi
  if [ "${INIT_YES:-}" = 1 ]; then [ "$default" = 1 ]; return; fi
  if [ "$default" = 1 ]; then
    gum confirm --affirmative "Yes" --negative "No" "$question"
  else
    gum confirm --default=false --affirmative "Yes" --negative "No" "$question"
  fi
}

ask_text() {
  local var="$1" default="$2" header="$3"
  local preset="${!var:-}"
  if [ -n "$preset" ]; then echo "$preset"; return; fi
  if [ "${INIT_YES:-}" = 1 ]; then echo "$default"; return; fi
  gum input --header "$header" --value "$default"
}

# git with gh as the credential for github.com over https, for this one
# command. Before the first switch nothing else would answer git's question.
ghgit() {
  git -c credential.https://github.com.helper= \
      -c 'credential.https://github.com.helper=!gh auth git-credential' "$@"
}

gh_login() {
  gh auth status -h github.com >/dev/null 2>&1 && return
  say "Logging in to GitHub (a browser consent screen)."
  gh auth login -h github.com -w -p https --skip-ssh-key
}

is_upstream() {
  local url
  url="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$url" in
    *superd22/nix-config | *superd22/nix-config.git) return 0 ;;
  esac
  [ "$1" = "$UPSTREAM" ]
}

# ---------------------------------------------------------------------------
# 1. who (asked by main) and whether at WeMaintain
# ---------------------------------------------------------------------------

other_who() {
  step "1 · Who" "a WeMaintain colleague, or anyone else"
  if ask_bool INIT_WORK 1 "Do you work at WeMaintain?"; then
    WORK=1
    ok "WeMaintain: the work environment is on (step 5 checks your access)"
  else
    WORK=0
    ok "not WeMaintain: nothing private is fetched"
  fi
}

# ---------------------------------------------------------------------------
# 2. their own repo
#
# GitHub has no private fork. A private copy is a bare clone pushed with
# --mirror to a new private repo, with upstream kept as a second remote for
# rebasing; a public fork is `gh repo fork`. Or neither for now: the clone
# works as it is, and step 2 is offered again on a re-run.
# ---------------------------------------------------------------------------

other_repo() {
  step "2 · Your repo" "a copy of this config on your GitHub, or just a clone for now"
  if [ ! -d "$DEST/.git" ]; then
    [ -e "$DEST" ] && die "$DEST exists and is not a git checkout; move it aside"
    mkdir -p "$(dirname "$DEST")"
    gum spin --spinner moon --title "Cloning $UPSTREAM..." -- \
      git clone --quiet "$UPSTREAM" "$DEST"
    ok "cloned to $DEST"
  fi

  local origin
  origin="$(git -C "$DEST" remote get-url origin)"
  if ! is_upstream "$origin"; then
    ok "origin is already your own: $origin"
    return
  fi

  local mode="${INIT_REPO:-}"
  if [ -z "$mode" ] && [ "${INIT_YES:-}" = 1 ]; then mode=clone; fi
  if [ -z "$mode" ]; then
    local private="A private copy on my GitHub (can still rebase on upstream)"
    local fork="A public fork (gh repo fork)"
    local later="Just the clone; I'll decide later"
    case "$(printf '%s\n' "$private" "$fork" "$later" \
      | gum choose --header "GitHub has no private fork. Where should your copy live?")" in
      "$private") mode=private ;;
      "$fork") mode=fork ;;
      *) mode=clone ;;
    esac
  fi
  [ "$mode" = clone ] && { note "Kept as a clone of $UPSTREAM_SLUG. Re-run init to make it yours."; return; }

  gh_login
  local login name
  login="$(gh api user -q .login)"
  name="$(ask_text INIT_REPO_NAME nix-config "Name of the new repo on github.com/$login")"
  local url="https://github.com/$login/$name.git"

  case "$mode" in
    private)
      if gh repo view "$login/$name" >/dev/null 2>&1; then
        confirm "github.com/$login/$name already exists. Use it as origin?" || exit 130
      else
        gh repo create "$login/$name" --private >/dev/null
        local tmp
        tmp="$(mktemp -d)"
        gum spin --spinner moon --title "Mirroring $UPSTREAM_SLUG into $login/$name..." -- \
          git clone --quiet --bare "$UPSTREAM" "$tmp/src.git"
        ghgit -C "$tmp/src.git" push --quiet --mirror "$url"
        rm -rf "$tmp"
      fi
      ;;
    fork)
      gh repo fork "$UPSTREAM_SLUG" --clone=false --fork-name "$name" >/dev/null
      # The fork is made asynchronously; wait until it can be read.
      local _try
      for _try in 1 2 3 4 5 6 7 8 9 10; do
        gh repo view "$login/$name" >/dev/null 2>&1 && break
        sleep 2
      done
      ;;
    *) die "INIT_REPO is '$mode'; want clone, private or fork" ;;
  esac

  git -C "$DEST" remote rename origin upstream
  git -C "$DEST" remote add origin "$url"
  ghgit -C "$DEST" fetch --quiet origin
  git -C "$DEST" branch --quiet --set-upstream-to=origin/main 2>/dev/null || true
  ok "origin is $url; upstream is $UPSTREAM_SLUG (git fetch upstream && git rebase upstream/main)"
}

# ---------------------------------------------------------------------------
# 3. hostname
#
# Unlike David's path, a new hosts/<name> always starts from hosts/example,
# never from one of David's hosts. An existing hosts/<name> is this Mac's
# from an earlier run, and its answers become the defaults.
# ---------------------------------------------------------------------------

other_hostname() {
  step "3 · Hostname" "build-switch builds darwinConfigurations.\$(hostname -s)"
  local current choice
  current="$(hostname -s)"
  choice="${INIT_HOSTNAME:-}"
  if [ -z "$choice" ] && [ "${INIT_YES:-}" = 1 ]; then choice="$current"; fi
  if [ -z "$choice" ]; then
    local keep="Keep '$current'"
    local pick
    pick="$(printf '%s\n' "$keep" "Another name…" | gum choose --header "This Mac is called '$current'. Its host file will be hosts/<name>.")"
    if [ "$pick" = "$keep" ]; then
      choice="$current"
    else
      choice="$(gum input --header "Hostname (letters, digits, dashes)" --placeholder "Ada-MacBook")"
    fi
  fi
  case "$choice" in
    "" | *[!A-Za-z0-9-]*) die "'$choice' is not a valid LocalHostName (letters, digits and dashes only)" ;;
    common | example) die "'$choice' is reserved under hosts/" ;;
  esac
  HOST="$choice"
  [ "$HOST" = "$(hostname -s)" ] || rename_mac "$HOST"

  if [ -f "$DEST/hosts/$HOST/default.nix" ]; then
    ok "hosts/$HOST exists; its answers are the defaults below"
    FACTS_FROM="$HOST"
  else
    ok "hosts/$HOST will be written from hosts/example"
    FACTS_FROM=example
  fi
  read_facts
}

# Everything the questions below default to, read out of a host through the
# module system: its identity, every enable flag under mine.desktop,
# mine.services and mine.programs with the option's own description, and its
# Homebrew lists. `options.mine` is the schema; adding a flag to
# modules/options.nix adds a prompt here with no change to this script.
# Nothing read forces the private inputs.
read_facts() {
  # shellcheck disable=SC2016  # nix's ${...}, not the shell's
  local expr='h:
    let
      o = h.options.mine;
      c = h.config.mine;
      flags = g: builtins.listToAttrs (builtins.concatMap
        (n: if o.${g}.${n} ? enable then [{
          name = n;
          value = { on = c.${g}.${n}.enable; desc = o.${g}.${n}.enable.description; };
        }] else [ ])
        (builtins.attrNames o.${g}));
    in {
      user = { inherit (c.user) fullName email githubKey signCommits; };
      desktop = flags "desktop";
      services = flags "services";
      programs = flags "programs";
      work = c.work.wemaintain.enable;
      secrets = c.secrets.enable;
      inherit (c.homebrew) brews casks;
    }'
  note "Reading hosts/$FACTS_FROM. The first evaluation fetches nixpkgs, which takes a while."
  if ! FACTS="$(nix --extra-experimental-features 'nix-command flakes' eval --json \
        "$DEST#darwinConfigurations.$FACTS_FROM" --apply "$expr")"; then
    [ "$FACTS_FROM" != example ] || die "could not evaluate hosts/example; the clone is not what I expected"
    warn "could not evaluate hosts/$FACTS_FROM; starting from hosts/example instead"
    FACTS_FROM=example
    read_facts
  fi
}

fact() { printf '%s' "$FACTS" | jq -r "$1"; }

# ---------------------------------------------------------------------------
# 4. identity
# ---------------------------------------------------------------------------

USER_NAME=""
FULLNAME=""
EMAIL=""
other_identity() {
  step "4 · Identity" "mine.user: who commits, and whose home directory this is"
  # Not a question: nix-darwin, home-manager and Homebrew all key off it, so
  # it has to be the account you are logged in as.
  USER_NAME="$(id -un)"
  ok "account: $USER_NAME"

  local d_name d_email
  d_name="$(fact '.user.fullName')"
  d_email="$(fact '.user.email')"
  if [ "$FACTS_FROM" = example ]; then
    d_name="$(id -F 2>/dev/null || true)"
    d_email="$(git config --global user.email 2>/dev/null || true)"
    if [ -z "$d_email" ] && gh auth status -h github.com >/dev/null 2>&1; then
      d_email="$(gh api user -q '.email // empty' 2>/dev/null || true)"
    fi
  fi
  FULLNAME="$(ask_text INIT_FULLNAME "$d_name" "Full name, as it appears on commits")"
  EMAIL="$(ask_text INIT_EMAIL "$d_email" "Email, for commits")"
  [ -n "$FULLNAME" ] || die "no full name; set INIT_FULLNAME"
  case "$EMAIL" in *@*) ;; *) die "'$EMAIL' is not an email address; set INIT_EMAIL" ;; esac
  ok "$FULLNAME <$EMAIL>"
}

# ---------------------------------------------------------------------------
# 5. work (WeMaintain only)
#
# `wm` is git+https and authenticates through the gh credential helper that
# only exists after the first switch. wm's own bootstrap, in --nix-config
# mode, does the GitHub login and proves this account can see
# wemaintain/devenv, and writes nothing that would outlive the switch
# (wemaintain/devenv#12). run_build_switch then lends gh to that one build.
# ---------------------------------------------------------------------------

DATAGRIP_DEFAULT=0
other_work() {
  if [ "$WORK" != 1 ]; then
    return
  fi
  step "5 · Work" "GitHub login and access to wemaintain/devenv, via its own bootstrap"
  note "It installs nothing permanent: the login lands in ~/.config/gh, and the config takes over from there."
  if curl -fsSL "$WM_BOOTSTRAP_URL" | sh -s -- --nix-config; then
    ok "this account can see wemaintain/devenv"
  else
    warn "wm's bootstrap did not finish; usually a missing invite to the wemaintain GitHub org."
    if confirm "Carry on with the work environment off? (Re-run init to turn it on later.)"; then
      WORK=0
      return
    fi
    exit 1
  fi
  note "With work on you get ~/.aws/config, withPg and friends, the Pritunl VPN, wm-login, and the work MCP servers in Claude Code."
  DATAGRIP_DEFAULT=1
}

# ---------------------------------------------------------------------------
# 6. prune
# ---------------------------------------------------------------------------

# Globals, one word per enabled flag, filled by prune_group.
ON_desktop=""
ON_services=""
ON_programs=""
CASKS=""

# One `gum choose --no-limit` per group of `mine.<group>.*.enable` flags,
# with what is on in the defaults preselected. $2 lists names that are asked
# about separately and left out here.
prune_group() {
  local group="$1" skip="${2:-}" title="$3"
  local names selected=""
  names="$(fact ".$group | keys[]")"
  local n
  for n in $names; do
    case " $skip " in *" $n "*) continue ;; esac
    [ "$(fact ".${group}[\"$n\"].on")" = true ] && selected="$selected,$n"
  done
  selected="${selected#,}"

  local picked
  if [ "${INIT_YES:-}" = 1 ]; then
    picked="$(printf '%s' "$selected" | tr ',' '\n')"
  else
    echo
    say "$title"
    for n in $names; do
      case " $skip " in *" $n "*) continue ;; esac
      # Option descriptions are "Whether to enable <what>." over several
      # lines; the first sentence is enough to choose by.
      printf '  %s  %s\n' "$(gum style --bold "$n")" \
        "$(fact ".${group}[\"$n\"].desc" | tr '\n' ' ' | sed -e 's/  */ /g' -e 's/^Whether to enable //' | cut -c1-110)"
    done
    local list=()
    for n in $names; do
      case " $skip " in *" $n "*) continue ;; esac
      list+=("$n")
    done
    picked="$(printf '%s\n' "${list[@]}" \
      | gum choose --no-limit --selected="$selected" --header "Space toggles, enter confirms. Keep:")" || exit 130
  fi
  printf -v "ON_$group" '%s' "$(printf '%s' "$picked" | tr '\n' ' ')"
}

is_on() {
  local v="ON_$1"
  case " ${!v} " in *" $2 "*) return 0 ;; esac
  return 1
}

# The casks a module needs come with its flag; these are the ones that are
# pure preference. hosts/example's (or this host's) are preselected, and the
# ones on David's hosts are offered unselected, as a menu rather than a
# default.
known_casks() {
  nix --extra-experimental-features 'nix-command flakes' eval --json --impure --expr "
    let
      dir = $DEST/hosts;
      hosts = builtins.attrNames (builtins.readDir dir);
      casks = n:
        let f = dir + \"/\${n}/default.nix\"; in
        if !(builtins.pathExists f) then [ ]
        else let m = import f; in
          if builtins.functionArgs m != { } then [ ]
          else (m { }).mine.homebrew.casks or [ ];
    in builtins.concatMap casks hosts" 2>/dev/null | jq -r '.[]' | sort -u
}

prune_casks() {
  local defaults
  defaults="$(fact '.casks[]')"
  if [ "${INIT_YES:-}" = 1 ]; then
    CASKS="$defaults"
    return
  fi
  local all
  all="$(printf '%s\n%s\n' "$defaults" "$(known_casks)" | sed '/^$/d' | sort -u)"
  echo
  say "Apps from Homebrew. Yours are selected; the rest are what other hosts here install."
  CASKS="$(printf '%s\n' "$all" \
    | gum choose --no-limit --height 20 --selected="$(printf '%s' "$defaults" | tr '\n' ',')" \
        --header "Space toggles, enter confirms. Add anything else to the host file later.")" || exit 130
}

CLAUDE=0
other_prune() {
  step "6 · What to keep" "flags in hosts/<name>, never deleted files; change them any time"
  prune_group desktop "" "Desktop"
  prune_group services "" "Background services"

  # Two programs are asked about on their own. DataGrip defaults on at work,
  # where it arrives with every database configured. Claude Code needs
  # explaining before anyone says yes to it.
  if [ "$DATAGRIP_DEFAULT" = 1 ]; then
    FACTS="$(printf '%s' "$FACTS" | jq '.programs.datagrip.on = true')"
  fi
  prune_group programs "claude-code" "Programs"

  local claude_default=0
  [ "$(fact '.programs["claude-code"].on')" = true ] && claude_default=1
  if [ "${INIT_YES:-}" != 1 ] && [ -z "${INIT_CLAUDE:-}" ]; then
    echo
    gum format <<'MD'
**Claude Code's configuration** is not generated like everything else here.
With it on, `~/.claude/settings.json`, `skills/` and `CLAUDE.md` become symlinks
into *this repo*, `modules/config/claude`: the settings, skills and plugins
there are David's until you change them, and anything Claude Code saves lands
in your working tree as a git change. Right if you own your copy and want your
Claude setup versioned; surprising otherwise. See `docs/two-paths.md`.
MD
  fi
  if ask_bool INIT_CLAUDE "$claude_default" "Point ~/.claude into this repo?"; then
    CLAUDE=1
  else
    CLAUDE=0
  fi

  # The one assertion in modules/: the lock monitor is built on
  # betterdisplaycli.
  if is_on services screen-lock-monitor && ! is_on desktop betterdisplay; then
    ON_desktop="$ON_desktop betterdisplay"
    note "BetterDisplay turned on too: screen-lock-monitor needs it."
  fi

  prune_casks
  ok "kept: ${ON_desktop:-no desktop units}${ON_services:+, $ON_services}${ON_programs:+, $ON_programs}"
}

# ---------------------------------------------------------------------------
# 7. keys
#
# The "From scratch" recipe of docs/new-machine.md, through `keys new-ssh`
# and `keys new-gpg` rather than a copy of it. No agenix identity and no
# secrets repo: nothing in this config needs a secret today, so
# mine.secrets.enable stays as it was (off for a new host).
# ---------------------------------------------------------------------------

GITHUB_KEY=""
SIGN=0
other_keys() {
  step "7 · Keys" "an SSH key GitHub knows, and GPG only if you sign commits"

  local choice="${INIT_GITHUB_KEY:-}"
  local current
  current="$(fact '.user.githubKey // empty')"
  if [ -z "$choice" ] && [ "${INIT_YES:-}" = 1 ]; then choice="${current:-none}"; fi
  if [ -z "$choice" ]; then
    local existing=() f
    for f in "$SSH_DIR"/*.pub; do
      [ -f "$f" ] && [ -f "${f%.pub}" ] || continue
      existing+=("$(basename "${f%.pub}")")
    done
    local options=() k
    [ -n "$current" ] && options+=("Keep $current")
    for k in "${existing[@]}"; do [ "$k" = "$current" ] || options+=("Use ~/.ssh/$k"); done
    if ! in_list id_ed25519 "${existing[@]}"; then options+=("Make ~/.ssh/id_ed25519"); fi
    options+=("None: I use git over https through gh")
    local pick
    pick="$(printf '%s\n' "${options[@]}" | gum choose --header "Which SSH key does GitHub know you by? It is pinned for github.com.")"
    case "$pick" in
      "Keep "*) choice="${pick#Keep }" ;;
      "Use ~/.ssh/"*) choice="${pick#Use ~/.ssh/}" ;;
      "Make ~/.ssh/"*) choice="${pick#Make ~/.ssh/}" ;;
      *) choice=none ;;
    esac
  fi
  if [ "$choice" = none ]; then
    GITHUB_KEY=""
    ok "no ssh key pinned for github.com"
  else
    case "$choice" in */* | "" ) die "'$choice' should be a file name under ~/.ssh" ;; esac
    GITHUB_KEY="$choice"
    # Makes it if missing, and adds it to GitHub if GitHub does not know it.
    keys new-ssh "$GITHUB_KEY" "$EMAIL"
  fi

  local sign_default=0
  [ "$(fact '.user.signCommits')" = true ] && sign_default=1
  if ask_bool INIT_SIGN "$sign_default" "Sign your commits with GPG?"; then
    SIGN=1
    keys new-gpg "$FULLNAME" "$EMAIL"
  else
    SIGN=0
  fi

  if [ "$(fact '.secrets')" != true ]; then
    note "Secrets: off. Nothing here needs one today; docs/new-machine.md, 'From scratch', has the recipe for your own nix-secrets repo when something does."
  fi
}

# ---------------------------------------------------------------------------
# The host file
# ---------------------------------------------------------------------------

nix_str() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//\$\{/\\\$\{}"
  printf '"%s"' "$v"
}

nix_bool() { if [ "$1" = 1 ]; then echo true; else echo false; fi; }

flag_lines() {
  local group="$1" skip="${2:-}" n
  for n in $(fact ".$group | keys[]"); do
    case " $skip " in *" $n "*) continue ;; esac
    if is_on "$group" "$n"; then echo "    $n.enable = true;"; else echo "    $n.enable = false;"; fi
  done
}

# A nix list from stdin, one string per line, at $1's indentation.
nix_list() {
  local indent="$1" item items=()
  while IFS= read -r item; do
    [ -z "$item" ] || items+=("$item")
  done
  if [ "${#items[@]}" -eq 0 ]; then echo "[ ]"; return; fi
  echo "["
  for item in "${items[@]}"; do echo "$indent  $(nix_str "$item")"; done
  echo "$indent]"
}

write_host() {
  local dir="$DEST/hosts/$HOST"
  local f="$dir/default.nix"
  mkdir -p "$dir"
  local github_nix=null secrets=0
  [ -z "$GITHUB_KEY" ] || github_nix="$(nix_str "$GITHUB_KEY")"
  [ "$(fact '.secrets')" != true ] || secrets=1
  {
    cat <<NIX
# $HOST. Written by \`nix run .#init\`, starting from hosts/example.
#
# Every unit in modules/ is off unless it is turned on here, so this file is
# the whole answer to "what does this Mac run". Edit it freely: re-running
# init reads it back as its defaults and shows a diff before rewriting it.
{ ... }:

{
  mine.user = {
    name = $(nix_str "$USER_NAME");
    fullName = $(nix_str "$FULLNAME");
    email = $(nix_str "$EMAIL");
    # File under ~/.ssh that github.com is pinned to; null for https via gh.
    githubKey = $github_nix;
    # Needs a GPG secret key for the email above; \`keys doctor\` checks.
    signCommits = $(nix_bool "$SIGN");
  };

  mine.desktop = {
$(flag_lines desktop)
  };

  mine.services = {
$(flag_lines services)
  };

  mine.programs = {
$(flag_lines programs claude-code)
    # Symlinks ~/.claude into modules/config/claude; see docs/two-paths.md.
    claude-code.enable = $(nix_bool "$CLAUDE");
  };

  # WeMaintain: ~/.aws/config, withPg and friends, the Pritunl VPN, wm-login
  # and the work MCP servers. Fetches the private wemaintain/devenv input.
  mine.work.wemaintain.enable = $(nix_bool "$WORK");

  mine.homebrew = {
    brews = $(fact '.brews[]' | nix_list "    ");
    casks = $(printf '%s\n' "$CASKS" | nix_list "    ");
  };

  # Needs a private nix-secrets repo of your own as the \`secrets\` input;
  # see docs/new-machine.md, "From scratch".
  mine.secrets.enable = $(nix_bool "$secrets");
}
NIX
  } > "$f"
}

other_write_host() {
  step "Host file" "hosts/$HOST/default.nix"
  write_host
  git -C "$DEST" add -N "hosts/$HOST"
  if git -C "$DEST" diff --quiet -- "hosts/$HOST"; then
    ok "hosts/$HOST is unchanged"
    return
  fi
  git -C "$DEST" --no-pager diff --color -- "hosts/$HOST"
  if ! confirm "Commit this?"; then
    git -C "$DEST" reset --quiet -- "hosts/$HOST"
    if git -C "$DEST" ls-files --error-unmatch "hosts/$HOST/default.nix" >/dev/null 2>&1; then
      git -C "$DEST" checkout -- "hosts/$HOST"
    else
      rm -rf "${DEST:?}/hosts/$HOST"
    fi
    die "left hosts/$HOST as it was"
  fi
  git -C "$DEST" add "hosts/$HOST"
  # Signing off for this one commit: git's config is not written until the
  # switch, and a GPG key made a minute ago may not be trusted yet.
  git -C "$DEST" -c commit.gpgsign=false -c user.name="$FULLNAME" -c user.email="$EMAIL" \
    commit --quiet -m "hosts: $HOST, from init"
  ok "committed"
}

# ---------------------------------------------------------------------------
# 8. doctor, build-switch, wm-login; 9. checklist
# ---------------------------------------------------------------------------

other_doctor() {
  step "8 · Doctor" "checks the keys this host uses, before anything is built"
  [ -z "$GITHUB_KEY" ] || trust_github_host_key
  if ! (cd "$DEST" && keys doctor); then
    echo
    die "doctor failed. Fix the line it names and re-run init; your answers are kept in hosts/$HOST."
  fi
}

other_push() {
  local origin
  origin="$(git -C "$DEST" remote get-url origin)"
  if is_upstream "$origin"; then
    note "hosts/$HOST is committed locally. Re-run init to put it on your own GitHub repo."
    return
  fi
  if confirm "Push hosts/$HOST to $origin?"; then
    ghgit -C "$DEST" push --quiet origin HEAD
    ok "pushed"
  else
    note "Later:  git -C $DEST push"
  fi
}

other_checklist() {
  step "9 · Not nix's job" "see $DOCS, 'Things nix does not do for you'"
  {
    echo "- **Open a new terminal.** The one you are in predates the switch."
    echo "- **App logins** for whatever you kept in step 6."
    if [ "$WORK" = 1 ]; then
      echo "- **Cloud logins**: \`wm-login\` again whenever \`withPg\` fails with an SSO error. Repo toolchains come from each repo's devenv shell, not from here."
    fi
    if is_on desktop raycast && is_on desktop betterdisplay; then
      echo "- **Raycast**: add \`~/.config/raycast/scripts\` as a script directory in its settings."
    fi
    echo "- **macOS permissions**: Accessibility and Screen Recording, granted per app on first run."
    echo "- **Changing your mind**: edit \`hosts/$HOST/default.nix\` and \`nix run .#build-switch\`, or re-run init."
    echo "- **\`nix flake update\`** fetches every input, including private ones you may not see. Update the ones you can by name: \`nix flake update nixpkgs home-manager\`."
  } | gum format
  echo
  gum style --bold --foreground "$ACCENT" "Done. Welcome. 🏡"
}

other_main() {
  other_banner
  other_who
  other_repo
  other_hostname
  other_identity
  other_work
  other_prune
  other_keys
  other_write_host
  other_doctor
  run_build_switch 8
  work_logins 8
  other_push
  other_checklist
}

david_main() {
  banner
  situation
  confirm "Start?" || exit 130

  clone_config
  settle_hostname
  import_keys
  run_doctor
  run_build_switch
  work_logins
  push_host_if_new
  checklist
}

main() {
  local me="I'm David, moving to this Mac from my old one"
  local them="I'm someone else, and want my own copy of this setup"
  local who="${INIT_WHO:-}"
  if [ -z "$who" ] && [ "${INIT_YES:-}" = 1 ]; then
    who=david
  elif [ -z "$who" ]; then
    echo
    case "$(printf '%s\n' "$me" "$them" | gum choose --header "Who is this for?")" in
      "$me") who=david ;;
      *) who=other ;;
    esac
  fi
  case "$who" in
    david) david_main ;;
    other) other_main ;;
    *) die "INIT_WHO is '$who'; want david or other" ;;
  esac
}

main
