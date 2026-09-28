# Built by flake.nix into a writeShellApplication; run with `nix run .#keys -- <command>`.
#
# The three files this config cannot regenerate, and how to move them to
# another Mac without losing any of them. See docs/new-machine.md for the
# full story; the short version:
#
#   ~/.ssh/id_rsa        GitHub. The flake's `secrets` input is a private
#                        git+ssh:// repo, so without this key the flake does
#                        not even evaluate.
#   ~/.ssh/id_ed25519    The agenix identity. Its public half is listed in
#                        nix-secrets/secrets.nix; it decrypts every .age file
#                        at activation. Lose it and the secrets are gone.
#   GPG signing key      `commit.gpgsign = true`, so commits fail without it.
#
# None of them can live in the secrets repo, because they are what fetches,
# decrypts and commits to it. So they travel out of band, as ONE
# passphrase-encrypted bundle, and that bundle doubles as the backup.
#
# Usage:
#   keys export [OUT.age]    on the old Mac: bundle the three into one file
#   keys import BUNDLE.age   on the new Mac: put them back
#   keys doctor              before build-switch: prove every key is in place
#   keys new-ssh NAME EMAIL  from scratch: make (or reuse) ~/.ssh/NAME, add it to GitHub
#   keys new-gpg NAME EMAIL  from scratch: make a signing key, add it to GitHub
#
# `doctor` is the only step that has to pass before the old Mac is wiped.
#
# The three above are David's. Someone else's host (#5) may name a different
# GitHub key (`mine.user.githubKey`), not sign commits (`mine.user.signCommits`)
# and have no secrets (`mine.secrets.enable`); doctor reads all three from the
# host and checks only what it uses. `new-ssh` and `new-gpg` are the "From
# scratch" recipe of docs/new-machine.md, so the init wizard calls them rather
# than carrying a copy.

RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

SSH_DIR="${HOME}/.ssh"
GITHUB_KEY="${SSH_DIR}/id_rsa"
AGENIX_KEY="${SSH_DIR}/id_ed25519"
# The key `apps/create-keys` used to generate. It has the agenix name and is
# not the agenix identity; nothing reads it. It must never end up in a bundle.
DEAD_KEY="${SSH_DIR}/id_ed25519_agenix"

usage() {
  cat >&2 <<EOF
Usage:
  keys export [OUT.age]    on the old Mac: bundle the three into one file
  keys import BUNDLE.age   on the new Mac: put them back (--force to overwrite)
  keys doctor              before build-switch: prove every key is in place
  keys new-ssh NAME EMAIL  make (or reuse) ~/.ssh/NAME and add it to GitHub
  keys new-gpg NAME EMAIL  make a GPG signing key and add it to GitHub

See docs/new-machine.md.
EOF
  exit 64
}

die() {
  echo "${RED}error:${NC} $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# GPG: which key signs commits.
#
# git.nix sets no `user.signingKey`, so gpg picks the secret key whose uid
# matches the commit email. Do the same here, so what is exported is exactly
# what git would have used.
# ---------------------------------------------------------------------------

git_email() {
  git config --get user.email 2>/dev/null || true
}

signing_fingerprint() {
  local email
  email="$(git_email)"
  [ -n "$email" ] || die "cannot tell which GPG key signs commits: 'git config user.email' is empty"
  signing_fingerprint_for "$email"
}

signing_fingerprint_for() {
  local email="$1"
  # --with-colons: 'fpr' records carry the fingerprint in field 10. The first
  # one after a 'sec' record is the primary key's.
  # gpg exits 2 when nothing matches; with pipefail that would abort the script
  # before the caller can say why, hence the `|| true`.
  gpg --batch --with-colons --list-secret-keys "<${email}>" 2>/dev/null \
    | awk -F: '$1 == "sec" { want = 1 } $1 == "fpr" && want { print $10; exit }' \
    || true
}

# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------

cmd_export() {
  local out="${1:-keys-$(hostname -s)-$(date +%F).age}"
  [ -e "$out" ] && die "$out already exists; pick another name"

  local f
  for f in "$GITHUB_KEY" "$GITHUB_KEY.pub" "$AGENIX_KEY" "$AGENIX_KEY.pub"; do
    [ -f "$f" ] || die "$f is missing. Nothing to export; this is not the machine the keys live on."
  done

  local fpr
  fpr="$(signing_fingerprint)"
  [ -n "$fpr" ] || die "no GPG secret key for $(git_email). Commits are signed with it; export cannot proceed without it."

  if [ -e "$DEAD_KEY" ]; then
    echo "${YELLOW}note:${NC} $DEAD_KEY exists and is NOT included. It is not the agenix identity" >&2
    echo "      (its pubkey is not in nix-secrets/secrets.nix); delete it." >&2
  fi

  # Decrypted keys sit here for the duration of the command. Not `local`: the
  # EXIT trap runs after the function has returned.
  tmp="$(mktemp -d)"
  chmod 700 "$tmp"
  trap 'rm -rf "$tmp"' EXIT

  mkdir -p "$tmp/keys/ssh" "$tmp/keys/gpg"
  cp "$GITHUB_KEY" "$GITHUB_KEY.pub" "$AGENIX_KEY" "$AGENIX_KEY.pub" "$tmp/keys/ssh/"

  # gpg may prompt for the key's passphrase here, through pinentry.
  gpg --batch --armor --export-secret-keys "$fpr" > "$tmp/keys/gpg/secret.asc"
  [ -s "$tmp/keys/gpg/secret.asc" ] || die "gpg exported nothing for $fpr"
  gpg --export-ownertrust > "$tmp/keys/gpg/ownertrust.txt"

  {
    echo "exported-from: $(hostname -s)"
    echo "exported-on: $(date -u +%FT%TZ)"
    echo "github-key: $(ssh-keygen -lf "$GITHUB_KEY.pub")"
    echo "agenix-key: $(ssh-keygen -lf "$AGENIX_KEY.pub")"
    echo "gpg-key: $fpr ($(git_email))"
  } > "$tmp/keys/MANIFEST"

  # age reads the passphrase from the terminal, so stdin is free for the tar.
  echo "${YELLOW}Choose a passphrase. It is the only thing that opens this bundle.${NC}"
  tar -C "$tmp" -cz keys | age -p -o "$out"
  chmod 600 "$out"

  echo
  cat "$tmp/keys/MANIFEST"
  echo
  echo "${GREEN}Written $out${NC}"
  echo "Next:"
  echo "  1. Move it to the new Mac (AirDrop is fine; the file is encrypted)."
  echo "  2. Put a copy somewhere that survives both laptops dying: your password"
  echo "     manager, or an external disk. With this file and its passphrase you"
  echo "     can rebuild from nothing; without it the secrets in nix-secrets are"
  echo "     gone for good."
  echo "  3. On the new Mac: nix run github:Superd22/nixos-config#keys -- import $out"
}

# ---------------------------------------------------------------------------
# import
# ---------------------------------------------------------------------------

cmd_import() {
  local bundle="${1:-}"
  local force="${2:-}"
  [ -n "$bundle" ] || usage
  [ -f "$bundle" ] || die "$bundle: no such file"

  # Decrypted keys sit here for the duration of the command. Not `local`: the
  # EXIT trap runs after the function has returned.
  tmp="$(mktemp -d)"
  chmod 700 "$tmp"
  trap 'rm -rf "$tmp"' EXIT

  age -d "$bundle" | tar -xz -C "$tmp"
  [ -f "$tmp/keys/MANIFEST" ] || die "$bundle does not look like a 'keys export' bundle (no MANIFEST)"

  echo "Bundle contents:"
  sed 's/^/  /' "$tmp/keys/MANIFEST"
  echo

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  # Refuse to overwrite a different key silently. A fresh Mac has none of
  # these; a re-run on the same Mac finds identical ones and is a no-op.
  local name src dst mode
  for name in id_rsa id_rsa.pub id_ed25519 id_ed25519.pub; do
    src="$tmp/keys/ssh/$name"
    dst="$SSH_DIR/$name"
    case "$name" in
      *.pub) mode=644 ;;
      *) mode=600 ;;
    esac
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
      if [ "$force" != "--force" ]; then
        die "$dst exists and differs from the bundle. Re-run with --force to replace it, or move it aside first."
      fi
      echo "${YELLOW}replacing${NC} $dst"
    fi
    install -m "$mode" "$src" "$dst"
  done

  gpg --batch --import "$tmp/keys/gpg/secret.asc"
  gpg --import-ownertrust "$tmp/keys/gpg/ownertrust.txt"

  if [ -e "$DEAD_KEY" ]; then
    echo "${YELLOW}note:${NC} $DEAD_KEY exists on this machine. Nothing reads it; delete it." >&2
  fi

  echo
  echo "${GREEN}Keys in place.${NC}"
  echo "Next, from the config checkout:  nix run .#keys -- doctor"
}

# ---------------------------------------------------------------------------
# doctor
#
# Every check answers "will build-switch work, and will the old Mac still be
# needed afterwards". Fails loudly before activation instead of during it.
# ---------------------------------------------------------------------------

FAILS=0
pass() { echo "${GREEN}  ok${NC}    $*"; }
warn() { echo "${YELLOW}  warn${NC}  $*"; }
fail() { echo "${RED}  FAIL${NC}  $*"; FAILS=$((FAILS + 1)); }

check_private_key() {
  local path="$1" role="$2"
  if [ ! -f "$path" ]; then
    fail "$path is missing ($role)"
    return 1
  fi
  local mode
  mode="$(stat -c %a "$path")"
  if [ "$mode" != "600" ]; then
    fail "$path has mode $mode, wants 600 (ssh refuses to use it)"
    return 1
  fi
  pass "$path present, mode 600 ($role)"
}

check_github() {
  local key="$1"
  # -i and IdentitiesOnly rather than relying on ~/.ssh/config: on a fresh Mac
  # home-manager has not written that file yet.
  local reply
  reply="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o IdentitiesOnly=yes \
              -i "$key" -T git@github.com 2>&1 || true)"
  if echo "$reply" | grep -q "successfully authenticated"; then
    pass "$(basename "$key") is accepted by GitHub"
  else
    fail "GitHub does not accept $(basename "$key"). git over ssh fails without it, and so does fetching a private git+ssh:// input like 'secrets'."
    echo "        ssh said: $(echo "$reply" | head -1)"
  fi
}

check_agenix_recipient() {
  local flake="$1"
  # The public key as derived from the private one, so a stale or swapped .pub
  # cannot make this pass. Only the type and key material are compared: the
  # comment after them is free text and differs between copies.
  local material
  material="$(ssh-keygen -y -f "$AGENIX_KEY" | awk '{ print $1 " " $2 }')"

  # Reads nix-secrets/secrets.nix out of the locked `secrets` input and asks
  # whether any secret is encrypted to this key. This is the check that would
  # have caught id_ed25519_agenix.
  local listed
  listed="$(nix --extra-experimental-features 'nix-command flakes' eval --impure --expr "
    let
      flake = builtins.getFlake \"${flake}\";
      rules = import (flake.inputs.secrets + \"/secrets.nix\");
      keys = builtins.concatLists (map (s: s.publicKeys) (builtins.attrValues rules));
      material = k: builtins.head (builtins.match \"([^ ]+ [^ ]+).*\" k);
    in builtins.any (k: material k == \"${material}\") keys
  " 2>/dev/null || echo "error")"

  case "$listed" in
    true) pass "id_ed25519's public key is a recipient in nix-secrets/secrets.nix" ;;
    false) fail "id_ed25519 is NOT a recipient in nix-secrets/secrets.nix. Activation would fail to decrypt. Either this is the wrong key, or the secrets were re-keyed to another one." ;;
    *) fail "could not read nix-secrets/secrets.nix through the flake (is id_rsa working, and is $flake the config checkout?)" ;;
  esac
}

check_gpg() {
  local email="$1"
  if [ -z "$email" ]; then
    warn "cannot tell the commit email yet, skipping the GPG check"
    return
  fi
  local fpr
  fpr="$(signing_fingerprint_for "$email")"
  if [ -n "$fpr" ]; then
    pass "GPG secret key $fpr signs as $email"
  else
    fail "no GPG secret key for $email; commit.gpgsign is on, so every commit would be rejected"
  fi
}

cmd_doctor() {
  local flake="$PWD"
  local host
  host="$(hostname -s)"

  echo "Checking keys for ${host} (config: ${flake})"

  # What this host uses, read from its declaration in this config (which works
  # before the first build-switch): one line each of email, GitHub key file
  # name ("" for none), sign commits and secrets on ("1" or ""). None of these
  # force the private inputs. When the host cannot be read, assume David's
  # full set, which is the strict answer.
  local email="" github="id_rsa" sign=1 secrets=1
  if [ -f "$flake/flake.nix" ]; then
    if [ -d "$flake/hosts/$host" ]; then
      pass "hosts/$host exists, so build-switch knows this machine"
      local facts
      if facts="$(nix --extra-experimental-features 'nix-command flakes' eval --raw \
                   "${flake}#darwinConfigurations.${host}.config.mine" --apply '
                     m: builtins.concatStringsSep "\n" [
                       m.user.email
                       (if m.user.githubKey == null then "" else m.user.githubKey)
                       (if m.user.signCommits then "1" else "")
                       (if m.secrets.enable then "1" else "")
                     ]' 2>/dev/null)"; then
        { IFS= read -r email; IFS= read -r github; IFS= read -r sign; IFS= read -r secrets; } <<<"$facts" || true
      else
        warn "could not evaluate hosts/$host; checking every key"
      fi
    else
      fail "hosts/$host does not exist; build-switch defaults to \$(hostname -s). Create it (copy hosts/example) or rename the Mac."
    fi
  else
    warn "no flake.nix in $flake; run doctor from the config checkout to also check nix-secrets"
  fi
  [ -n "$email" ] || email="$(git_email)"

  if [ -n "$github" ]; then
    check_private_key "$SSH_DIR/$github" "GitHub" && check_github "$SSH_DIR/$github"
  else
    pass "no GitHub ssh key pinned (mine.user.githubKey is null); git to GitHub goes over https through gh"
  fi

  if [ -n "$secrets" ]; then
    if check_private_key "$AGENIX_KEY" "agenix identity" && [ -f "$flake/flake.nix" ]; then
      check_agenix_recipient "$flake"
    fi
  else
    pass "no secrets (mine.secrets.enable is off), so no agenix identity is needed"
  fi

  if [ -n "$sign" ]; then
    check_gpg "$email"
  else
    pass "commits are not signed (mine.user.signCommits is off), so no GPG key is needed"
  fi

  if [ -e "$DEAD_KEY" ]; then
    warn "$DEAD_KEY exists. It has the agenix name and is not the agenix identity; nothing reads it. Delete it so it cannot be mistaken for the real one."
  fi

  echo
  if [ "$FAILS" -eq 0 ]; then
    echo "${GREEN}All keys in place.${NC} nix run .#build-switch can go ahead, and once it has, the old Mac is no longer needed."
  else
    echo "${RED}${FAILS} check(s) failed.${NC} Do not wipe the old Mac until this passes."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# new-ssh / new-gpg: the "From scratch" recipe, for a person with no bundle.
#
# Both end by registering the public half with GitHub through gh, which needs
# a scope a plain `gh auth login` does not grant; gh asks for it in the
# browser. If that fails the key is still made, and the manual command is
# printed instead.
# ---------------------------------------------------------------------------

gh_scope() {
  local scope="$1"
  if ! gh auth status -h github.com >/dev/null 2>&1; then
    gh auth login -h github.com -w -p https --skip-ssh-key -s "$scope"
  elif ! gh auth status -h github.com 2>&1 | grep -q "$scope"; then
    gh auth refresh -h github.com -s "$scope"
  fi
}

cmd_new_ssh() {
  local name="${1:-}" email="${2:-}"
  [ -n "$name" ] && [ -n "$email" ] || usage
  local key="$SSH_DIR/$name"
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  if [ -f "$key" ]; then
    echo "$key exists; reusing it."
  else
    ssh-keygen -q -t ed25519 -f "$key" -C "$email"
    echo "${GREEN}Made $key${NC}"
  fi
  [ -f "$key.pub" ] || ssh-keygen -y -f "$key" > "$key.pub"

  local material
  material="$(awk '{ print $2 }' "$key.pub")"
  if gh ssh-key list 2>/dev/null | grep -qF "$material"; then
    echo "GitHub already knows $name."
    return
  fi
  if gh_scope admin:public_key && gh ssh-key add "$key.pub" --title "$(hostname -s)"; then
    echo "${GREEN}Added $name to GitHub.${NC}"
  else
    echo "${YELLOW}Could not add it to GitHub.${NC} By hand:  gh ssh-key add $key.pub --title $(hostname -s)" >&2
  fi
}

cmd_new_gpg() {
  local name="${1:-}" email="${2:-}"
  [ -n "$name" ] && [ -n "$email" ] || usage
  local fpr
  fpr="$(signing_fingerprint_for "$email")"
  if [ -n "$fpr" ]; then
    echo "GPG key $fpr already signs as $email; reusing it."
  else
    # gpg asks for a passphrase for the new key through pinentry.
    gpg --quick-generate-key "$name <$email>" ed25519 sign 0
    fpr="$(signing_fingerprint_for "$email")"
    [ -n "$fpr" ] || die "gpg made no key for $email"
    echo "${GREEN}Made GPG key $fpr${NC}"
  fi
  if gh gpg-key list 2>/dev/null | grep -qF "${fpr: -16}"; then
    echo "GitHub already knows $fpr."
    return
  fi
  if gh_scope write:gpg_key && gpg --armor --export "$fpr" | gh gpg-key add -; then
    echo "${GREEN}Added $fpr to GitHub.${NC}"
  else
    echo "${YELLOW}Could not add it to GitHub.${NC} By hand:  gpg --armor --export $fpr | gh gpg-key add -" >&2
  fi
}

case "${1:-}" in
  export) shift; cmd_export "$@" ;;
  import) shift; cmd_import "$@" ;;
  doctor) shift; cmd_doctor "$@" ;;
  new-ssh) shift; cmd_new_ssh "$@" ;;
  new-gpg) shift; cmd_new_gpg "$@" ;;
  *) usage ;;
esac
