;; -*- mode: emacs-lisp -*-
;; This file is loaded by Spacemacs at startup.
;; It must be stored in your home directory.

(defun dotspacemacs/layers ()
  "Configuration Layers declaration.
You should not put any user code in this function besides modifying the variable
values."
  (setq-default
   ;; Base distribution to use. This is a layer contained in the directory
   ;; `+distribution'. For now available distributions are `spacemacs-base'
   ;; or `spacemacs'. (default 'spacemacs)
   dotspacemacs-distribution 'spacemacs
   ;; List of additional paths where to look for configuration layers.
   ;; Paths must have a trailing slash (i.e. `~/.mycontribs/')
   dotspacemacs-configuration-layer-path '()
   ;; List of configuration layers to load. If it is the symbol `all' instead
   ;; of a list then all discovered layers will be installed.
   dotspacemacs-configuration-layers
   '(
     better-defaults
     dash
     deft
     emoji
     osx
     emacs-lisp
     theming
     (c-c++ :variables
            c-c++-enable-clang-support t
            c-basic-offset 2
            evil-shift-width 2)
     (haskell :variables
              haskell-enable-ghc-mod-support t
              haskell-process-type 'stack-ghci
              haskell-process-suggest-remove-import-lines t
              haskell-process-auto-import-loaded-modules t
              haskell-process-log t)
     ruby
     ruby-on-rails
     javascript
     idris
     html
     purescript
     ruby-on-rails
     (git :variables git-magit-status-fullscreen t)
     github
     version-control
     markdown
     (ranger :variables ranger-cleanup-on-disable t)
     (auto-completion :variables
                      auto-completion-tab-key-behavior 'complete
                      auto-completion-complete-with-key-sequence nil
                      auto-completion-private-snippets-directory nil)
     org
     syntax-checking
     (shell :variables
            shell-default-height 30
            shell-default-position 'bottom)
     ;; spell-checking
     )
   ;; List of additional packages that will be installed without being
   ;; wrapped in a layer. If you need some configuration for these
   ;; packages then consider to create a layer, you can also put the
   ;; configuration in `dotspacemacs/config'.
   dotspacemacs-additional-packages '()
   ;; A list of packages and/or extensions that will not be install and loaded.
   dotspacemacs-excluded-packages '(
                                    ;; Disable evil search persistent highlight
                                    highlight-parentheses
                                    evil-search-highlight-persist)
   ;; If non-nil spacemacs will delete any orphan packages, i.e. packages that
   ;; are declared in a layer which is not a member of
   ;; the list `dotspacemacs-configuration-layers'. (default t)
   dotspacemacs-delete-orphan-packages t))

(defun dotspacemacs/init ()
  "Initialization function.
This function is called at the very startup of Spacemacs initialization
before layers configuration.
You should not put any user code in there besides modifying the variable
values."
  ;; This setq-default sexp is an exhaustive list of all the supported
  ;; spacemacs settings.
  (setq-default
   ;; One of `vim', `emacs' or `hybrid'. Evil is always enabled but if the
   ;; variable is `emacs' then the `holy-mode' is enabled at startup. `hybrid'
   ;; uses emacs key bindings for vim's insert mode, but otherwise leaves evil
   ;; unchanged. (default 'vim)
   dotspacemacs-editing-style 'hybrid
   ;; If non nil output loading progress in `*Messages*' buffer. (default nil)
   dotspacemacs-verbose-loading nil
   ;; Specify the startup banner. Default value is `official', it displays
   ;; the official spacemacs logo. An integer value is the index of text
   ;; banner, `random' chooses a random text banner in `core/banners'
   ;; directory. A string value must be a path to an image format supported
   ;; by your Emacs build.
   ;; If the value is nil then no banner is displayed. (default 'official)
   dotspacemacs-startup-banner 'official
   ;; List of items to show in the startup buffer. If nil it is disabled.
   ;; Possible values are: `recents' `bookmarks' `projects'.
   ;; (default '(recents projects))
   dotspacemacs-startup-lists '(recents projects)
   ;; List of themes, the first of the list is loaded when spacemacs starts.
   ;; Press <SPC> T n to cycle to the next theme in the list (works great
   ;; with 2 themes variants, one dark and one light)
   dotspacemacs-themes '(sanityinc-solarized-dark
                         solarized-dark
                         spacemacs-dark
                         spacemacs-light
                         solarized-light
                         leuven
                         monokai
                         zenburn)
   ;; If non nil the cursor color matches the state color.
   dotspacemacs-colorize-cursor-according-to-state t
   ;; Default font. `powerline-scale' allows to quickly tweak the mode-line
   ;; size to make separators look not too crappy.
   dotspacemacs-default-font '("Inconsolata"
                               :size 18
                               :weight normal
                               :width normal
                               :powerline-scale 1.0)
   ;; The leader key
   dotspacemacs-leader-key "SPC"
   ;; The leader key accessible in `emacs state' and `insert state'
   ;; (default "M-m")
   dotspacemacs-emacs-leader-key "M-m"
   ;; Major mode leader key is a shortcut key which is the equivalent of
   ;; pressing `<leader> m`. Set it to `nil` to disable it. (default ",")
   dotspacemacs-major-mode-leader-key ","
   ;; Major mode leader key accessible in `emacs state' and `insert state'.
   ;; (default "C-M-m)
   dotspacemacs-major-mode-emacs-leader-key "C-M-m"
   ;; The command key used for Evil commands (ex-commands) and
   ;; Emacs commands (M-x).
   ;; By default the command key is `:' so ex-commands are executed like in Vim
   ;; with `:' and Emacs commands are executed with `<leader> :'.
   dotspacemacs-command-key ":"
   ;; If non nil `Y' is remapped to `y$'. (default t)
   dotspacemacs-remap-Y-to-y$ t
   ;; Location where to auto-save files. Possible values are `original' to
   ;; auto-save the file in-place, `cache' to auto-save the file to another
   ;; file stored in the cache directory and `nil' to disable auto-saving.
   ;; (default 'cache)
   dotspacemacs-auto-save-file-location 'cache
   ;; If non nil then `ido' replaces `helm' for some commands. For now only
   ;; `find-files' (SPC f f), `find-spacemacs-file' (SPC f e s), and
   ;; `find-contrib-file' (SPC f e c) are replaced. (default nil)
   dotspacemacs-use-ido t
   ;; If non nil, `helm' will try to miminimize the space it uses. (default nil)
   dotspacemacs-helm-resize t
   ;; if non nil, the helm header is hidden when there is only one source.
   ;; (default nil)
   dotspacemacs-helm-no-header t
   ;; define the position to display `helm', options are `bottom', `top',
   ;; `left', or `right'. (default 'bottom)
   dotspacemacs-helm-position 'bottom
   ;; If non nil the paste micro-state is enabled. When enabled pressing `p`
   ;; several times cycle between the kill ring content. (default nil)
   dotspacemacs-enable-paste-micro-state t
   ;; Which-key delay in seconds. The which-key buffer is the popup listing
   ;; the commands bound to the current keystroke sequence. (default 0.4)
   dotspacemacs-which-key-delay 1.0
   ;; Which-key frame position. Possible values are `right', `bottom' and
   ;; `right-then-bottom'. right-then-bottom tries to display the frame to the
   ;; right; if there is insufficient space it displays it at the bottom.
   ;; (default 'bottom)
   dotspacemacs-which-key-position 'bottom
   ;; If non nil a progress bar is displayed when spacemacs is loading. This
   ;; may increase the boot time on some systems and emacs builds, set it to
   ;; nil to boost the loading time. (default t)
   dotspacemacs-loading-progress-bar t
   ;; If non nil the frame is fullscreen when Emacs starts up. (default nil)
   ;; (Emacs 24.4+ only)
   dotspacemacs-fullscreen-at-startup t
   ;; If non nil `spacemacs/toggle-fullscreen' will not use native fullscreen.
   ;; Use to disable fullscreen animations in OSX. (default nil)
   dotspacemacs-fullscreen-use-non-native t
   ;; If non nil the frame is maximized when Emacs starts up.
   ;; Takes effect only if `dotspacemacs-fullscreen-at-startup' is nil.
   ;; (default nil) (Emacs 24.4+ only)
   dotspacemacs-maximized-at-startup t
   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's active or selected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-active-transparency 90
   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's inactive or deselected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-inactive-transparency 90
   ;; If non nil unicode symbols are displayed in the mode line. (default t)
   dotspacemacs-mode-line-unicode-symbols t
   ;; If non nil smooth scrolling (native-scrolling) is enabled. Smooth
   ;; scrolling overrides the default behavior of Emacs which recenters the
   ;; point when it reaches the top or bottom of the screen. (default t)
   dotspacemacs-smooth-scrolling t
   ;; If non-nil smartparens-strict-mode will be enabled in programming modes.
   ;; (default nil)
   dotspacemacs-smartparens-strict-mode nil
   ;; Select a scope to highlight delimiters. Possible values are `any',
   ;; `current', `all' or `nil'. Default is `all' (highlight any scope and
   ;; emphasis the current one). (default 'all)
   dotspacemacs-highlight-delimiters 'all
   ;; If non nil advises quit functions to keep server open when quitting.
   ;; (default nil)
   dotspacemacs-persistent-server t
   ;; List of search tool executable names. Spacemacs uses the first installed
   ;; tool of the list. Supported tools are `ag', `pt', `ack' and `grep'.
   ;; (default '("ag" "pt" "ack" "grep"))
   dotspacemacs-search-tools '("ag" "pt" "ack" "grep")
   ;; The default package repository used if no explicit repository has been
   ;; specified with an installed package.
   ;; Not used for now. (default nil)
   dotspacemacs-default-package-repository nil
   ))

(defun dotspacemacs/user-init ()
  "Initialization function for user code.
It is called immediately after `dotspacemacs/init'.  You are free to put any
user code."
  (setq theming-modifications `((sanityinc-solarized-dark

                                 (powerline-active1 :foreground "#657b83" :background "#002b36")
                                 (powerline-active2 :foreground "#657b83" :background "#073642")
                                 (powerline-inactive1 :foreground "#586e75" :background "#073642")
                                 (powerline-inactive2 :foreground "#586e75" :background "#002b36"))))
  )

(defun dotspacemacs/user-config ()
  "Configuration function for user code.
 This function is called at the very end of Spacemacs initialization after
layers configuration. You are free to put any user code."
  (defvar vera-evil-cursors '(("normal" "#d33682" box)
                              ("insert" "#2aa198" (bar . 2))
                              ("emacs" "#268bd2" box)
                              ("hybrid" "#268bd2" (bar . 2))
                              ("replace" "#cb4b16" (hbar . 2))
                              ("evilified" "#b58900" box)
                              ("visual" "#eee8d5" (hbar . 2))
                              ("motion" "#e279ac" box)
                              ("lisp" "#6c71c4" box)
                              ("iedit" "#dc322f" box)
                              ("iedit-insert" "#dc322f" (bar . 2)))
    "Colors assigned to evil states with cursor definitions.")

  (loop for (state color cursor) in vera-evil-cursors
        do
        (let ((face (intern (format "spacemacs-%s-face" state)))
              (evil-cursor (intern (format "evil-%s-state-cursor" state))))

          (set-face-attribute face nil :background color)
          (set evil-cursor (list color cursor))))

  ;; Enable company everywhere
  ;; (global-company-mode)

  (add-to-list 'exec-path "~/.local/bin/")
  (setq multi-term-program "/usr/local/bin/zsh")

  ;; Disable powerline separators
  (setq powerline-default-separator nil)

  ;; Increase term buffer size
  (add-hook 'term-mode-hook
            (lambda ()
              (setq term-buffer-maximum-size 10000)))

  ;; Add interactive-haskell-mode to haskell-mode
  (add-hook 'haskell-mode-hook 'interactive-haskell-mode)

  ;; Set evil keybindings once evil is defined
  (define-key evil-motion-state-map (kbd "<left>") 'evil-window-left)
  (define-key evil-motion-state-map (kbd "<down>") 'evil-window-down)
  (define-key evil-motion-state-map (kbd "<up>") 'evil-window-up)
  (define-key evil-motion-state-map (kbd "<right>") 'evil-window-right)

  (define-key evil-motion-state-map (kbd "C-y") nil)
  (define-key evil-motion-state-map (kbd "C-e") 'end-of-line)
  ;; Add file and project keybindings
  (define-key evil-normal-state-map (kbd "S-s-f") 'spacemacs/helm-project-do-ag)
  (define-key evil-normal-state-map (kbd "s-f") 'helm-swoop)

  ;; Switch between header/implementation
  ;; TODO figure out why projectile-find-other-file doesn't work with
  ;; some C projects
  (define-key evil-normal-state-map (kbd "C-6") 'ff-find-other-file)
  (define-key evil-normal-state-map "gb" 'pop-global-mark)

  ;; Ruby bindings
  (evil-define-key 'normal ruby-mode-map
    "}" 'ruby-end-of-block
    "{" 'ruby-beginning-of-block)
  (evil-define-key 'insert ruby-mode-map
    (kbd "RET") 'ruby-reindent-then-newline-and-indent)

  ;; So COMMIT_EDITMSG starts in hybrid-mode
  (evil-set-initial-state 'text-mode 'hybrid)
  (evil-set-initial-state 'Custom-mode 'evilified)

  (setq deft-directory "~/Notes")
  (spacemacs/set-leader-keys "aN" 'deft-new-file)
)

;; Do not write anything past this comment. This is where Emacs will
;; auto-generate custom variable definitions.
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   (quote
    ("4aee8551b53a43a883cb0b7f3255d6859d766b6c5e14bcb01bed572fcbef4328" "bffa9739ce0752a37d9b1eee78fc00ba159748f50dc328af4be661484848e476" "8aebf25556399b58091e533e455dd50a6a9cba958cc4ebb0aab175863c25b9a4" default)))
 '(haskell-compile-cabal-build-alt-command
   "cd %s && stack clean && stack build --ghc-options -ferror-spans")
 '(haskell-compile-cabal-build-command "cd %s && stack build --ghc-options -ferror-spans")
 '(haskell-process-args-stack-ghci (quote ("--ghc-options=-ferror-spans --test")))
 '(haskell-process-suggest-overloaded-strings nil)
 '(paradox-github-token t)
 '(safe-local-variable-values
   (quote
    ((whitespace-style face lines indentation:space)
     (eval unless
           (featurep
            (quote swift-project-settings))
           (add-to-list
            (quote load-path)
            (concat
             (let
                 ((dlff
                   (dir-locals-find-file default-directory)))
               (if
                   (listp dlff)
                   (car dlff)
                 (file-name-directory dlff)))
             "utils")
            :append)
           (require
            (quote swift-project-settings))))))
 '(show-smartparens-global-mode nil)
 '(sp-highlight-pair-overlay nil)
 '(sp-highlight-wrap-overlay nil)
 '(sp-highlight-wrap-tag-overlay nil)
 '(vc-follow-symlinks t))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(company-tooltip-common ((t (:inherit company-tooltip :weight bold :underline nil))))
 '(company-tooltip-common-selection ((t (:inherit company-tooltip-selection :weight bold :underline nil))))
 '(powerline-active1 ((t (:foreground "#657b83" :background "#002b36"))))
 '(powerline-active2 ((t (:foreground "#657b83" :background "#073642"))))
 '(powerline-inactive1 ((t (:foreground "#586e75" :background "#073642"))))
 '(powerline-inactive2 ((t (:foreground "#586e75" :background "#002b36")))))
