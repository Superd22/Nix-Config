{ lib, ... }:

{
  programs.zsh = {
    enable = true;
    # autocd = false;
    # cdpath = [ "~/.local/share/src" ];
    # plugins = [];
    enableCompletion = false;
    # enableGlobalCompInit = false;

    # Set the keymap explicitly. Left unset, zsh infers it from $EDITOR — we
    # export EDITOR="vim" below, so it was silently landing in `viins` while
    # /etc/zshrc (skipped via NOSYSZSHRC) was no longer there to `bindkey -e`.
    # That gave the worst of both: no vi motions (they live in vicmd, behind
    # Esc) and no emacs conveniences either. Deliberate vi mode now, with the
    # useful emacs bindings grafted into insert mode — see initContent below.
    defaultKeymap = "viins";
    # Skip /etc/zshrc entirely — its `autoload -U compinit && compinit` races
    # on stale ~/.zcompdump.* files and stalls interactive shell startup by 60s+,
    # which causes VS Code's extension host to time out. We reimplement the
    # essentials (brew shellenv, fast compinit) in initContent below.
    envExtra = ''
      export NOSYSZSHRC=1
    '';
    initContent = lib.mkMerge [
    (lib.mkBefore ''
      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      # Replacements for /etc/zshrc (skipped via NOSYSZSHRC in envExtra).
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
      autoload -Uz compinit && compinit -C
      autoload -Uz bashcompinit && bashcompinit

      # Define variables for directories
      export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH
      export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
      export PATH=$HOME/.local/bin:$PATH

      # Remove history data we don't want to see
      export HISTIGNORE="pwd:ls:cd"

      # Ripgrep alias
      alias search=rg -p --glob '!node_modules/*'  $@

      # Emacs is my editor
      export ALTERNATE_EDITOR=""
      export EDITOR="vim"
      export VISUAL="vim"

      # nix shortcuts
      shell() {
          nix-shell '<nixpkgs>' -A "$1"
      }

      # pnpm is a javascript package manager
      alias pn=pnpm
      alias px=pnpx

      # Use difftastic, syntax-aware diffing
      alias diff=difft

      # Always color ls and group directories
      alias ls='ls --color=auto'

      # mise version manager — shims-only PATH (no `activate` precmd hook,
      # which blocked interactive prompts and stalled zsh -ic startup).
      export PATH="$HOME/.local/share/mise/shims:$PATH"

      # Pick up & export secrets
      for file in ~/.secrets/*; do
        [[ -f "$file" ]] && export "''${file##*/}=$(<"$file")"
      done

      # WeMaintain staging DB helper
      withPg() {
        local host=wemaintain-pgsql-staging.cdtgkxemrw9j.eu-west-1.rds.amazonaws.com
        local user=backend_dev
        local password
        password=$(aws rds --profile prod:back generate-db-auth-token --hostname "$host" --port 5432 --region eu-west-1 --username "$user")
        DB_HOST=$host \
        POSTGRES_HOST=$host \
        DB_USER=$user \
        POSTGRES_USERNAME=$user \
        DB_PASSWORD=$password \
        POSTGRES_PASSWORD=$password \
        DB_SSL_CA=~/.aws/rds-ca-cert.pem \
        "$@"
      }

      # WeMaintain production DB helper
      withPgProd() {
        local host=wemaintain-pgsql-prod.cdtgkxemrw9j.eu-west-1.rds.amazonaws.com
        local user=backend_dev
        local password
        password=$(aws rds --profile prod:sudo generate-db-auth-token --hostname "$host" --port 5432 --region eu-west-1 --username "$user")
        DB_HOST=$host \
        POSTGRES_HOST=$host \
        DB_USER=$user \
        POSTGRES_USERNAME=$user \
        DB_PASSWORD=$password \
        POSTGRES_PASSWORD=$password \
        DB_SSL_CA=~/.aws/rds-ca-cert.pem \
        "$@"
      }
    '')

    # Line editing. `defaultKeymap = "viins"` above emits `bindkey -v` at order
    # 530; this block runs last so nothing can clobber it.
    #
    # Esc gives you the full vi command keymap (w/b/e, 0/^/$, dw, ciw, /search
    # + n/N). Insert mode keeps the emacs conveniences so day-to-day typing is
    # never worse than before — everything below is bound with `-M viins` so it
    # only applies while inserting and leaves vicmd's vi grammar untouched.
    (lib.mkAfter ''
      # Esc is a prefix for the arrow escape sequences, so zsh waits KEYTIMEOUT
      # hundredths of a second after Esc to disambiguate. Default 40 = a 0.4s
      # lag every time you leave insert mode. 1 makes mode switching instant.
      KEYTIMEOUT=1

      # --- Mode indicator -----------------------------------------------------
      # vi mode is unusable when you can't see which mode you're in. Beam cursor
      # = insert, block = command.
      function _vi-cursor-beam  { print -n '\e[6 q' }
      function _vi-cursor-block { print -n '\e[2 q' }

      function zle-keymap-select {
        case $KEYMAP in
          vicmd)      _vi-cursor-block ;;
          viins|main) _vi-cursor-beam  ;;
        esac
      }
      zle -N zle-keymap-select

      # Every new prompt starts in insert mode; reset the cursor before running
      # a command too, so full-screen programs don't inherit a beam.
      function zle-line-init { _vi-cursor-beam }
      zle -N zle-line-init
      autoload -Uz add-zsh-hook
      add-zsh-hook preexec _vi-cursor-beam

      # --- Insert-mode conveniences (emacs bindings, viins only) --------------
      # Word motion: Option/Alt + Left/Right. Terminals disagree on what these
      # emit, so bind every common sequence.
      bindkey -M viins '^[[1;3D' backward-word   # alt-left  (xterm)
      bindkey -M viins '^[[1;3C' forward-word    # alt-right (xterm)
      bindkey -M viins '^[[1;5D' backward-word   # ctrl-left (VS Code, Warp)
      bindkey -M viins '^[[1;5C' forward-word    # ctrl-right
      bindkey -M viins '^[^[[D'  backward-word   # esc-prefixed (Terminal.app)
      bindkey -M viins '^[^[[C'  forward-word
      bindkey -M viins '^[b'     backward-word
      bindkey -M viins '^[f'     forward-word

      # Line motion: Cmd + Left/Right, Home/End, and ^A/^E.
      bindkey -M viins '^[[H'  beginning-of-line
      bindkey -M viins '^[[F'  end-of-line
      bindkey -M viins '^[OH'  beginning-of-line
      bindkey -M viins '^[OF'  end-of-line
      bindkey -M viins '^[[1~' beginning-of-line
      bindkey -M viins '^[[4~' end-of-line
      bindkey -M viins '^A'    beginning-of-line
      bindkey -M viins '^E'    end-of-line

      # Deletion. vi-backward-delete-char refuses to delete past the point where
      # insert mode began — the single most confusing viins default. Use the
      # emacs variants instead.
      bindkey -M viins '^?'     backward-delete-char   # backspace
      bindkey -M viins '^H'     backward-delete-char
      bindkey -M viins '^W'     backward-kill-word
      bindkey -M viins '^U'     backward-kill-line
      bindkey -M viins '^K'     kill-line
      bindkey -M viins '^[[3~'  delete-char            # fn-delete / Del
      bindkey -M viins '^[^?'   backward-kill-word     # alt-backspace
      bindkey -M viins '^[[3;3~' kill-word             # alt-del

      # History search. In vicmd you also get vi's native `/pattern` + n/N.
      bindkey -M viins '^R' history-incremental-search-backward
      bindkey -M viins '^S' history-incremental-search-forward
      bindkey -M vicmd '^R' history-incremental-search-backward

      # Prefix-aware history on Up/Down and on vi's k/j: type `git ` then Up
      # cycles only past git commands.
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      for _km in viins vicmd; do
        bindkey -M $_km '^[[A' up-line-or-beginning-search
        bindkey -M $_km '^[[B' down-line-or-beginning-search
        bindkey -M $_km '^[OA' up-line-or-beginning-search
        bindkey -M $_km '^[OB' down-line-or-beginning-search
      done
      unset _km
      bindkey -M vicmd 'k' up-line-or-beginning-search
      bindkey -M vicmd 'j' down-line-or-beginning-search

      # --- vi extras ----------------------------------------------------------
      # `vv` in command mode opens the current line in $EDITOR; :wq runs it.
      autoload -Uz edit-command-line
      zle -N edit-command-line
      bindkey -M vicmd 'vv' edit-command-line

      # Text objects: ci" di( ca' etc. work on quotes and brackets like in vim.
      autoload -Uz select-quoted select-bracketed
      zle -N select-quoted
      zle -N select-bracketed
      for _km in viopp visual; do
        for _c in {a,i}''${(s..)^:-\'\"\`\|,./:;=+@}; do
          bindkey -M $_km $_c select-quoted
        done
        for _c in {a,i}''${(s..)^:-'()[]{}<>bB'}; do
          bindkey -M $_km $_c select-bracketed
        done
      done
      unset _km _c
    '')
    ];
  };
}
