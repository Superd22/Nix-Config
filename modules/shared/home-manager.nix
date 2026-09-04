{ config, pkgs, lib, ... }:

let name = "David";
    user = "david";
    email = "superd001@gmail.com"; in
{
  # Shared shell configuration
  zsh = {
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

  starship = {
    enable = true;
    settings = {
      add_newline = false;
      command_timeout = 300;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        truncation_length = 5;
        truncate_to_repo = false;
      };

      git_branch = {
        symbol = " ";
        disabled = true;
      };

      git_status = {
        ahead = ''⇡''${count}'';
        diverged = ''⇕⇡''${ahead_count}⇣''${behind_count}'';
        behind = ''⇣''${count}'';
        disabled = true;
      };

      nodejs = {
        symbol = " ";
        disabled = true;
      };
      python = {
        symbol = " ";
        disabled = true;
      };
      rust = {
        symbol = " ";
        disabled = true;
      };
      nix_shell = {
        symbol = " ";
        impure_msg = "[impure](bold red)";
        pure_msg = "[pure](bold green)";
        unknown_msg = "[unknown shell](bold yellow)";
        format = "via [$symbol$state( \\($name\\))](bold blue) ";
        disabled = true;
      };
    };
  };

  git = {
    enable = true;
    ignores = [ "*.swp" ];
    signing.format = "openpgp";
    lfs = {
      enable = true;
    };
    settings = {
      user = {
        name = name;
        email = email;
      };
      init.defaultBranch = "main";
      core = {
	    editor = "vim";
        autocrlf = "input";
      };
      commit.gpgsign = true;
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [ vim-airline vim-airline-themes vim-startify vim-tmux-navigator ];
    settings = { ignorecase = true; };
    extraConfig = ''
      "" General
      set number
      set history=1000
      set nocompatible
      set modelines=0
      set encoding=utf-8
      set scrolloff=3
      set showmode
      set showcmd
      set hidden
      set wildmenu
      set wildmode=list:longest
      set cursorline
      set ttyfast
      set nowrap
      set ruler
      set backspace=indent,eol,start
      set laststatus=2
      set clipboard=autoselect

      " Dir stuff
      set nobackup
      set nowritebackup
      set noswapfile
      set backupdir=~/.config/vim/backups
      set directory=~/.config/vim/swap

      " Relative line numbers for easy movement
      set relativenumber
      set rnu

      "" Whitespace rules
      set tabstop=8
      set shiftwidth=2
      set softtabstop=2
      set expandtab

      "" Searching
      set incsearch
      set gdefault

      "" Statusbar
      set nocompatible " Disable vi-compatibility
      set laststatus=2 " Always show the statusline
      let g:airline_theme='bubblegum'
      let g:airline_powerline_fonts = 1

      "" Local keys and such
      let mapleader=","
      let maplocalleader=" "

      "" Change cursor on mode
      :autocmd InsertEnter * set cul
      :autocmd InsertLeave * set nocul

      "" File-type highlighting and configuration
      syntax on
      filetype on
      filetype plugin on
      filetype indent on

      "" Paste from clipboard
      nnoremap <Leader>, "+gP

      "" Copy from clipboard
      xnoremap <Leader>. "+y

      "" Move cursor by display lines when wrapping
      nnoremap j gj
      nnoremap k gk

      "" Map leader-q to quit out of window
      nnoremap <leader>q :q<cr>

      "" Move around split
      nnoremap <C-h> <C-w>h
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-l> <C-w>l

      "" Easier to yank entire line
      nnoremap Y y$

      "" Move buffers
      nnoremap <tab> :bnext<cr>
      nnoremap <S-tab> :bprev<cr>

      "" Like a boss, sudo AFTER opening the file to write
      cmap w!! w !sudo tee % >/dev/null

      let g:startify_lists = [
        \ { 'type': 'dir',       'header': ['   Current Directory '. getcwd()] },
        \ { 'type': 'sessions',  'header': ['   Sessions']       },
        \ { 'type': 'bookmarks', 'header': ['   Bookmarks']      }
        \ ]

      let g:startify_bookmarks = [
        \ '~/.local/share/src',
        \ ]

      let g:airline_theme='bubblegum'
      let g:airline_powerline_fonts = 1
      '';
     };

  alacritty = {
    enable = true;
    settings = {
      cursor = {
        style = "Block";
      };

      window = {
        opacity = 1.0;
        padding = {
          x = 24;
          y = 24;
        };
      };

      font = {
        normal = {
          family = "MesloLGS NF";
          style = "Regular";
        };
        size = 14;
      };

      dynamic_padding = true;
      decorations = "full";
      title = "Terminal";
      class = {
        instance = "Alacritty";
        general = "Alacritty";
      };

      colors = {
        primary = {
          background = "0x1f2528";
          foreground = "0xc0c5ce";
        };

        normal = {
          black = "0x1f2528";
          red = "0xec5f67";
          green = "0x99c794";
          yellow = "0xfac863";
          blue = "0x6699cc";
          magenta = "0xc594c5";
          cyan = "0x5fb3b3";
          white = "0xc0c5ce";
        };

        bright = {
          black = "0x65737e";
          red = "0xec5f67";
          green = "0x99c794";
          yellow = "0xfac863";
          blue = "0x6699cc";
          magenta = "0xc594c5";
          cyan = "0x5fb3b3";
          white = "0xd8dee9";
        };
      };
    };
  };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [
      "/Users/${user}/.ssh/config_external"
    ];
    # Upstream OpenSSH directive names — `matchBlocks` (and its camelCase
    # aliases / `extraOptions` escape hatch) is deprecated.
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      "github.com" = {
        IdentitiesOnly = true;
        IdentityFile = [
          "/Users/${user}/.ssh/id_rsa"
        ];
      };
    };
  };

  tmux = {
    enable = false;
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      sensible
      yank
      prefix-highlight
      {
        plugin = power-theme;
        extraConfig = ''
           set -g @tmux_power_theme 'gold'
        '';
      }
      {
        plugin = resurrect; # Used by tmux-continuum

        # Use XDG data directory
        # https://github.com/tmux-plugins/tmux-resurrect/issues/348
        extraConfig = ''
          set -g @resurrect-dir '$HOME/.cache/tmux/resurrect'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-pane-contents-area 'visible'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5' # minutes
        '';
      }
    ];
    terminal = "screen-256color";
    prefix = "C-x";
    escapeTime = 10;
    historyLimit = 50000;
    extraConfig = ''
      # Remove Vim mode delays
      set -g focus-events on

      # Enable full mouse support
      set -g mouse on

      # -----------------------------------------------------------------------------
      # Key bindings
      # -----------------------------------------------------------------------------

      # Unbind default keys
      unbind C-b
      unbind '"'
      unbind %

      # Split panes, vertical or horizontal
      bind-key x split-window -v
      bind-key v split-window -h

      # Move around panes with vim-like bindings (h,j,k,l)
      bind-key -n M-k select-pane -U
      bind-key -n M-h select-pane -L
      bind-key -n M-j select-pane -D
      bind-key -n M-l select-pane -R

      # Smart pane switching with awareness of Vim splits.
      # This is copy paste from https://github.com/christoomey/vim-tmux-navigator
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
        | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
      bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
      bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
      bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
      bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
      tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
      if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
      if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

      bind-key -T copy-mode-vi 'C-h' select-pane -L
      bind-key -T copy-mode-vi 'C-j' select-pane -D
      bind-key -T copy-mode-vi 'C-k' select-pane -U
      bind-key -T copy-mode-vi 'C-l' select-pane -R
      bind-key -T copy-mode-vi 'C-\' select-pane -l
      '';
    };

}
