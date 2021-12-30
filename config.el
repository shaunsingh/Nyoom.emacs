;;; config.el -*- lexical-binding: t; -*-

(setq user-full-name "Shaurya Singh"
      user-mail-address "shaunsingh0207@gmail.com")

(setq explicit-shell-file-name (executable-find "fish"))

(setq vterm-always-compile-module t)

(setq vterm-kill-buffer-on-exit t)

(after! vterm
  (setf (alist-get "magit-status" vterm-eval-cmds nil nil #'equal)
        '((lambda (path)
            (magit-status path)))))

(setq +ligatures-in-modes t)
(setq +ligatures-extras-in-modes '(org-mode emacs-lisp-mode))

;;fonts
(setq doom-font (font-spec :family "Liga SFMono Nerd Font" :size 15)
      doom-big-font (font-spec :family "Liga SFMono Nerd Font" :size 20)
      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 16)
      doom-unicode-font (font-spec :family "Liga SFMono Nerd Font")
      doom-serif-font (font-spec :family "Fira Sans" :size 16 :weight 'medium))

;;mixed pitch modes
(defvar mixed-pitch-modes '(org-mode LaTeX-mode markdown-mode gfm-mode Info-mode)
  "Modes that `mixed-pitch-mode' should be enabled in, but only after UI initialisation.")
(defun init-mixed-pitch-h ()
  "Hook `mixed-pitch-mode' into each mode in `mixed-pitch-modes'.
Also immediately enables `mixed-pitch-modes' if currently in one of the modes."
  (when (memq major-mode mixed-pitch-modes)
    (mixed-pitch-mode 1))
  (dolist (hook mixed-pitch-modes)
    (add-hook (intern (concat (symbol-name hook) "-hook")) #'mixed-pitch-mode)))
(add-hook 'doom-init-ui-hook #'init-mixed-pitch-h)
(add-hook! 'org-mode-hook #'+org-pretty-mode) ;enter mixed pitch mode in org mode

;;set mixed pitch font
(after! mixed-pitch
  (defface variable-pitch-serif
    '((t (:family "serif")))
    "A variable-pitch face with serifs."
    :group 'basic-faces)
  (setq mixed-pitch-set-height t)
  (setq variable-pitch-serif-font (font-spec :family "Fira Sans" :size 16))
  (set-face-attribute 'variable-pitch-serif nil :font variable-pitch-serif-font)
  (defun mixed-pitch-serif-mode (&optional arg)
    "Change the default face of the current buffer to a serifed variable pitch, while keeping some faces fixed pitch."
    (interactive)
    (let ((mixed-pitch-face 'variable-pitch-serif))
      (mixed-pitch-mode (or arg 'toggle)))))

(after! company
  (setq company-idle-delay 0.1
        company-minimum-prefix-length 1
        company-selection-wrap-around t
        company-require-match 'never
        company-dabbrev-downcase nil
        company-dabbrev-ignore-case t
        company-dabbrev-other-buffers nil
        company-tooltip-limit 5
        company-tooltip-minimum-width 40))
(set-company-backend!
  '(text-mode
    markdown-mode
    gfm-mode)
  '(:seperate
    company-yasnippet
    company-files))

(setq yas-triggers-in-field t)

(use-package! aas
  :commands aas-mode)

(use-package! laas
  :hook (LaTeX-mode . laas-mode)
  :config
  (defun laas-tex-fold-maybe ()
    (unless (equal "/" aas-transient-snippet-key)
      (+latex-fold-last-macro-a)))
  (add-hook 'org-mode #'laas-mode)
  (add-hook 'aas-post-snippet-expand-hook #'laas-tex-fold-maybe))

(defadvice! fixed-org-yas-expand-maybe-h ()
  "Expand a yasnippet snippet, if trigger exists at point or region is active.
Made for `org-tab-first-hook'."
  :override #'+org-yas-expand-maybe-h
  (when (and (featurep! :editor snippets)
             (require 'yasnippet nil t)
             (bound-and-true-p yas-minor-mode))
    (and (let ((major-mode (cond ((org-in-src-block-p t)
                                  (org-src-get-lang-mode (org-eldoc-get-src-lang)))
                                 ((org-inside-LaTeX-fragment-p)
                                  'latex-mode)
                                 (major-mode)))
               (org-src-tab-acts-natively nil) ; causes breakages
               ;; Smart indentation doesn't work with yasnippet, and painfully slow
               ;; in the few cases where it does.
               (yas-indent-line 'fixed))
           (cond ((and (or (not (bound-and-true-p evil-local-mode))
                           (evil-insert-state-p)
                           (evil-emacs-state-p))
                       (or (and (bound-and-true-p yas--tables)
                                (gethash major-mode yas--tables))
                           (progn (yas-reload-all) t))
                       (yas--templates-for-key-at-point))
                  (yas-expand)
                  t)
                 ((use-region-p)
                  (yas-insert-snippet)
                  t)))
         ;; HACK Yasnippet breaks org-superstar-mode because yasnippets is
         ;;      overzealous about cleaning up overlays.
         (when (bound-and-true-p org-superstar-mode)
           (org-superstar-restart)))))

(defun +yas/org-src-header-p ()
  "Determine whether `point' is within a src-block header or header-args."
  (pcase (org-element-type (org-element-context))
    ('src-block (< (point) ; before code part of the src-block
                   (save-excursion (goto-char (org-element-property :begin (org-element-context)))
                                   (forward-line 1)
                                   (point))))
    ('inline-src-block (< (point) ; before code part of the inline-src-block
                          (save-excursion (goto-char (org-element-property :begin (org-element-context)))
                                          (search-forward "]{")
                                          (point))))
    ('keyword (string-match-p "^header-args" (org-element-property :value (org-element-context))))))

(defun +yas/org-prompt-header-arg (arg question values)
  "Prompt the user to set ARG header property to one of VALUES with QUESTION.
The default value is identified and indicated. If either default is selected,
or no selection is made: nil is returned."
  (let* ((src-block-p (not (looking-back "^#\\+property:[ \t]+header-args:.*" (line-beginning-position))))
         (default
           (or
            (cdr (assoc arg
                        (if src-block-p
                            (nth 2 (org-babel-get-src-block-info t))
                          (org-babel-merge-params
                           org-babel-default-header-args
                           (let ((lang-headers
                                  (intern (concat "org-babel-default-header-args:"
                                                  (+yas/org-src-lang)))))
                             (when (boundp lang-headers) (eval lang-headers t)))))))
            ""))
         default-value)
    (setq values (mapcar
                  (lambda (value)
                    (if (string-match-p (regexp-quote value) default)
                        (setq default-value
                              (concat value " "
                                      (propertize "(default)" 'face 'font-lock-doc-face)))
                      value))
                  values))
    (let ((selection (consult--read question values :default default-value)))
      (unless (or (string-match-p "(default)$" selection)
                  (string= "" selection))
        selection))))

(defun +yas/org-src-lang ()
  "Try to find the current language of the src/header at `point'.
Return nil otherwise."
  (let ((context (org-element-context)))
    (pcase (org-element-type context)
      ('src-block (org-element-property :language context))
      ('inline-src-block (org-element-property :language context))
      ('keyword (when (string-match "^header-args:\\([^ ]+\\)" (org-element-property :value context))
                  (match-string 1 (org-element-property :value context)))))))

(defun +yas/org-last-src-lang ()
  "Return the language of the last src-block, if it exists."
  (save-excursion
    (beginning-of-line)
    (when (re-search-backward "^[ \t]*#\\+begin_src" nil t)
      (org-element-property :language (org-element-context)))))

(defun +yas/org-most-common-no-property-lang ()
  "Find the lang with the most source blocks that has no global header-args, else nil."
  (let (src-langs header-langs)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*#\\+begin_src" nil t)
        (push (+yas/org-src-lang) src-langs))
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]*#\\+property: +header-args" nil t)
        (push (+yas/org-src-lang) header-langs)))

    (setq src-langs
          (mapcar #'car
                  ;; sort alist by frequency (desc.)
                  (sort
                   ;; generate alist with form (value . frequency)
                   (cl-loop for (n . m) in (seq-group-by #'identity src-langs)
                            collect (cons n (length m)))
                   (lambda (a b) (> (cdr a) (cdr b))))))

    (car (cl-set-difference src-langs header-langs :test #'string=))))

(sp-local-pair
 '(org-mode)
 "<<" ">>"
 :actions '(insert))

(set-file-template! "\\.org$" :trigger "__" :mode 'org-mode)

(use-package! lsp-ui
  :hook (lsp-mode . lsp-ui-mode)
  :config
  (setq lsp-lens-enable t
        lsp-ui-doc-enable t
        lsp-ui-sideline-enable nil
        lsp-enable-symbol-highlighting t
        lsp-enable-semantic-tokens-enable t
        lsp-headerline-breadcrumb-enable nil))

(after! lsp-rust
  (setq lsp-rust-server 'rust-analyzer
        lsp-rust-analyzer-display-chaining-hints t
        lsp-rust-analyzer-display-parameter-hints t
        lsp-rust-analyzer-server-display-inlay-hints t
        lsp-rust-analyzer-cargo-watch-command "clippy"))

(setq scroll-margin 2
      auto-save-default t
      display-line-numbers-type nil
      delete-by-moving-to-trash t
      truncate-string-ellipsis "…"
      browse-url-browser-function 'xwidget-webkit-browse-url)

(fringe-mode 0)
(global-subword-mode 1)

(add-to-list 'default-frame-alist '(inhibit-double-buffering . t))

(map! :leader
      :desc "hop to word" "w w" #'avy-goto-word-or-subword-1)
(map! :leader
      :desc "hop to word" "w W" #'avy-goto-char-2)
(map! :leader
      :desc "hop to line"
      "l" #'avy-goto-line)

(after! evil
  (map! :nmv ";" #'evil-ex))

(after! evil
  (setq evil-ex-substitute-global t     ; I like my s/../.. to by global by default
        evil-move-cursor-back nil       ; Don't move the block cursor when toggling insert mode
        evil-kill-on-visual-paste nil)) ; Don't put overwritten text in the kill ring

(after! mu4e
  (setq mu4e-update-interval 300) ;5 minutes is a reasonable update time
  (set-email-account! "shaunsingh0207"
                      '((mu4e-sent-folder       . "/Sent Mail")
                        (mu4e-drafts-folder     . "/Drafts")
                        (mu4e-trash-folder      . "/Trash")
                        (mu4e-refile-folder     . "/All Mail")
                        (smtpmail-smtp-user     . "shaunsingh0207@gmail.com")))

  ;; don't need to run cleanup after indexing for gmail
  (setq mu4e-index-cleanup nil
        mu4e-index-lazy-check t)

  (setq mu4e-headers-fields
        '((:flags . 6)
          (:account-stripe . 2)
          (:from-or-to . 25)
          (:folder . 10)
          (:recipnum . 2)
          (:subject . 80)
          (:human-date . 8))
        +mu4e-min-header-frame-width 142
        mu4e-headers-date-format "%d/%m/%y"
        mu4e-headers-time-format "⧖ %H:%M"
        mu4e-headers-results-limit 1000
        mu4e-index-cleanup t)

  (add-to-list 'mu4e-bookmarks
               '(:name "Yesterday's messages" :query "date:2d..1d" :key ?y) t)

  (defvar +mu4e-header--folder-colors nil)
  (appendq! mu4e-header-info-custom
            '((:folder .
               (:name "Folder" :shortname "Folder" :help "Lowest level folder" :function
                (lambda (msg)
                  (+mu4e-colorize-str
                   (replace-regexp-in-string "\\`.*/" "" (mu4e-message-field msg :maildir))
                   '+mu4e-header--folder-colors)))))))

(after! mu4e
  (setq sendmail-program "msmtp"
        send-mail-function #'smtpmail-send-it
        message-sendmail-f-is-evil t
        message-sendmail-extra-arguments '("--read-envelope-from")
        message-send-mail-function #'message-send-mail-with-sendmail))

(use-package! selectric-mode
  :commands selectric-mode)

(use-package! monkeytype
  :commands (monkeytype-region monkeytype-buffer monkeytype-region-as-words)
  :init
  (evil-escape-mode -1)
  (evil-insert -1)
  :config
  (setq monkeytype-directory "~/.config/monkeytype"
        monkeytype-file-name "%a-%d-%b-%Y-%H-%M-%S"
        monkeytype-randomize t
        monkeytype-delete-trailing-whitespace t
        monkeytype-excluded-chars-regexp "[^[:alnum:]']"))

(use-package! emacs-everywhere
  :if (daemonp)
  :config
  (require 'spell-fu)
  (setq emacs-everywhere-major-mode-function #'org-mode
        emacs-everywhere-frame-name-format "Edit ∷ %s — %s"))

(defun greedily-do-daemon-setup ()
  (require 'org)
  (require 'vertico)
  (require 'consult)
  (require 'embark)
  (require 'marginalia)
  (when (require 'mu4e nil t)
    (setq mu4e-confirm-quit t)
    (setq +mu4e-lock-greedy t)
    (setq +mu4e-lock-relaxed t)
    (+mu4e-lock-add-watcher)
    (when (+mu4e-lock-available t)
      (mu4e~start)))
  (when (require 'elfeed nil t)
    (run-at-time nil (* 8 60 60) #'elfeed-update)))

(when (daemonp)
  (add-hook 'emacs-startup-hook #'greedily-do-daemon-setup)
  (add-hook! 'server-after-make-frame-hook
    (unless (string-match-p "\\*draft" (buffer-name))
      (switch-to-buffer +doom-dashboard-name))))

(setq-default line-spacing 0.24)

(cond
 ((string-equal system-type "darwin")
  (setq frame-resize-pixelwise  t
        window-resize-pixelwise t)
  (menu-bar-mode t)))

(after! frame
  (setq window-divider-default-bottom-width 0
        window-divider-default-right-width 0))

(remove-hook 'doom-first-buffer-hook #'global-hl-line-mode)

(setq inhibit-compacting-font-caches t)

(if (boundp 'mac-mouse-wheel-smooth-scroll)
    (setq  mac-mouse-wheel-smooth-scroll t))
(if (> emacs-major-version 28)
    (pixel-scroll-precision-mode))

;; (use-package! tree-sitter
;;   :defer t ;; loading is handled by individual modes
;;   :hook (tree-sitter-after-on . tree-sitter-hl-mode)
;;   :config
;;   (cl-pushnew (expand-file-name "~/.config/tree-sitter") tree-sitter-load-path)
;;   (defvar +tree-sitter-enabled-mode-maps (seq-map (lambda (mode)
;;                                                     (intern (concat
;;                                                              (symbol-name (car mode)) "-map")))
;;                                                   tree-sitter-major-mode-language-alist)
;;     "List of mode hooks for tree sitter enabled modes.")
;;   ;; This makes every node a link to a section of code
;;   (setq tree-sitter-debug-jump-buttons t
;;         ;; and this highlights the entire sub tree in your code
;;         tree-sitter-debug-highlight-jump-region t))

(setq default-frame-alist
      (append (list
               '(min-height . 1)
               '(height . 45)
               '(min-width . 1)
               '(width . 81)
               '(vertical-scroll-bars . nil)
               '(internal-border-width . 24)
               '(left-fringe . 1)
               '(right-fringe . 1)
               '(tool-bar-lines . 0)
               '(menu-bar-lines . 0))))

(setq doom-theme 'nil)

;; Dim inactive windows
(use-package dimmer
  :hook (after-init . dimmer-mode)
  :config
  (setq dimmer-fraction 0.5
        dimmer-adjustment-mode :foreground
        dimmer-use-colorspace :rgb
        dimmer-watch-frame-focus-events nil)
  (dimmer-configure-which-key)
  (dimmer-configure-magit)
  (dimmer-configure-posframe))

(use-package! nano-theme
  :hook (after-init . nano-light))

(use-package! nano-modeline
  :hook (after-init . nano-modeline-mode)
  :config
  (setq no-mode-line t
        nano-modeline-position 'top))

(use-package! nano-agenda
  :commands nano-agenda)

(use-package svg-tag-mode
  :commands global-svg-tag-mode
  :config
  (defconst date-re "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}")
  (defconst time-re "[0-9]\\{2\\}:[0-9]\\{2\\}")
  (defconst day-re "[A-Za-z]\\{3\\}")

  (defun svg-progress-percent (value)
    (svg-image (svg-lib-concat
                (svg-lib-progress-bar (/ (string-to-number value) 100.0)
                                  nil :margin 0 :stroke 2 :radius 3 :padding 2 :width 11)
                (svg-lib-tag (concat value "%")
                             nil :stroke 0 :margin 0)) :ascent 'center))

  (defun svg-progress-count (value)
    (let* ((seq (mapcar #'string-to-number (split-string value "/")))
           (count (float (car seq)))
           (total (float (cadr seq))))
    (svg-image (svg-lib-concat
                (svg-lib-progress-bar (/ count total) nil
                                      :margin 0 :stroke 2 :radius 3 :padding 2 :width 11)
                (svg-lib-tag value nil
                             :stroke 0 :margin 0)) :ascent 'center)))

  (setq svg-tag-tags
        `((":\\([A-Za-z0-9]+\\)" . ((lambda (tag) (svg-tag-make tag))))
          (":\\([A-Za-z0-9]+[ \-]\\)" . ((lambda (tag) tag)))

          ;; Task priority
          ("\\[#[A-Z]\\]" . ( (lambda (tag)
                                (svg-tag-make tag :face 'org-priority
                                              :beg 2 :end -1 :margin 0))))

          ;; Progress
          ("\\(\\[[0-9]\\{1,3\\}%\\]\\)" . ((lambda (tag)
                                              (svg-progress-percent (substring tag 1 -2)))))
          ("\\(\\[[0-9]+/[0-9]+\\]\\)" . ((lambda (tag)
                                            (svg-progress-count (substring tag 1 -1)))))

          ;; TODO / DONE, etc.
          ("XXX" . ((lambda (tag) (svg-tag-make "XXX" :face 'org-done :margin 0))))
          ("NOTE" . ((lambda (tag) (svg-tag-make "NOTE" :face 'org-done :margin 0))))
          ("DONE" . ((lambda (tag) (svg-tag-make "DONE" :face 'org-done :margin 0))))
          ("TODO" . ((lambda (tag) (svg-tag-make "TODO" :face 'org-todo :inverse t :margin 0))))
          ("HACK" . ((lambda (tag) (svg-tag-make "HACK" :face 'org-todo :inverse t :margin 0))))
          ("OPTIMIZE" . ((lambda (tag) (svg-tag-make "OPTIMIZE" :face 'org-todo :inverse t :margin 0))))
          ("DEPRECATED" . ((lambda (tag) (svg-tag-make "DEPRECATED" :face 'org-todo :inverse t :margin 0))))

          ;; Citation of the form [cite:@Knuth:1984]
          ("\\(\\[cite:@[A-Za-z]+:\\)" . ((lambda (tag)
                                            (svg-tag-make tag
                                                          :inverse t
                                                          :beg 7 :end -1
                                                          :crop-right t))))
          ("\\[cite:@[A-Za-z]+:\\([0-9]+\\]\\)" . ((lambda (tag)
                                                  (svg-tag-make tag
                                                                :end -1
                                                                :crop-left t))))


          ;; Active date (without day name, with or without time)
          (,(format "\\(<%s>\\)" date-re) .
           ((lambda (tag)
              (svg-tag-make tag :beg 1 :end -1 :margin 0))))
          (,(format "\\(<%s *\\)%s>" date-re time-re) .
           ((lambda (tag)
              (svg-tag-make tag :beg 1 :inverse nil :crop-right t :margin 0))))
          (,(format "\\(<%s *\\)%s>" date-re time-re) .
           ((lambda (tag)
              (svg-tag-make tag :beg 1 :inverse nil :crop-right t :margin 0))))
          (,(format "<%s *\\(%s>\\)" date-re time-re) .
           ((lambda (tag)
              (svg-tag-make tag :end -1 :inverse t :crop-left t :margin 0))))

          ;; Inactive date  (without day name, with or without time)
           (,(format "\\(\\[%s\\]\\)" date-re) .
            ((lambda (tag)
               (svg-tag-make tag :beg 1 :end -1 :margin 0 :face 'org-date))))
           (,(format "\\(\\[%s *\\)%s\\]" date-re time-re) .
            ((lambda (tag)
               (svg-tag-make tag :beg 1 :inverse nil :crop-right t :margin 0 :face 'org-date))))
           (,(format "\\(\\[%s *\\)%s\\]" date-re time-re) .
            ((lambda (tag)
               (svg-tag-make tag :beg 1 :inverse nil :crop-right t :margin 0 :face 'org-date))))
           (,(format "\\[%s *\\(%s\\]\\)" date-re time-re) .
            ((lambda (tag)
               (svg-tag-make tag :end -1 :inverse t :crop-left t :margin 0 :face 'org-date)))))))

(setq fancy-splash-image "~/.config/doom/misc/gura.png")
(setq +doom-dashboard-banner-padding '(0 . 0))

(defvar splash-phrase-source-folder
  (expand-file-name "misc/splash-phrases" doom-private-dir)
  "A folder of text files with a fun phrase on each line.")

(defvar splash-phrase-sources
  (let* ((files (directory-files splash-phrase-source-folder nil "\\.txt\\'"))
         (sets (delete-dups (mapcar
                             (lambda (file)
                               (replace-regexp-in-string "\\(?:-[0-9]+-\\w+\\)?\\.txt" "" file))
                             files))))
    (mapcar (lambda (sset)
              (cons sset
                    (delq nil (mapcar
                               (lambda (file)
                                 (when (string-match-p (regexp-quote sset) file)
                                   file))
                               files))))
            sets))
  "A list of cons giving the phrase set name, and a list of files which contain phrase components.")

(defvar splash-phrase-set
  (nth (random (length splash-phrase-sources)) (mapcar #'car splash-phrase-sources))
  "The default phrase set. See `splash-phrase-sources'.")

(defun splase-phrase-set-random-set ()
  "Set a new random splash phrase set."
  (interactive)
  (setq splash-phrase-set
        (nth (random (1- (length splash-phrase-sources)))
             (cl-set-difference (mapcar #'car splash-phrase-sources) (list splash-phrase-set))))
  (+doom-dashboard-reload t))

(defvar splase-phrase--cache nil)

(defun splash-phrase-get-from-file (file)
  "Fetch a random line from FILE."
  (let ((lines (or (cdr (assoc file splase-phrase--cache))
                   (cdar (push (cons file
                                     (with-temp-buffer
                                       (insert-file-contents (expand-file-name file splash-phrase-source-folder))
                                       (split-string (string-trim (buffer-string)) "\n")))
                               splase-phrase--cache)))))
    (nth (random (length lines)) lines)))

(defun splash-phrase (&optional set)
  "Construct a splash phrase from SET. See `splash-phrase-sources'."
  (mapconcat
   #'splash-phrase-get-from-file
   (cdr (assoc (or set splash-phrase-set) splash-phrase-sources))
   " "))

(defun doom-dashboard-phrase ()
  "Get a splash phrase, flow it over multiple lines as needed, and make fontify it."
  (mapconcat
   (lambda (line)
     (+doom-dashboard--center
      +doom-dashboard--width
      (with-temp-buffer
        (insert-text-button
         line
         'action
         (lambda (_) (+doom-dashboard-reload t))
         'face 'doom-dashboard-menu-title
         'mouse-face 'doom-dashboard-menu-title
         'help-echo "Random phrase"
         'follow-link t)
        (buffer-string))))
   (split-string
    (with-temp-buffer
      (insert (splash-phrase))
      (setq fill-column (min 70 (/ (* 2 (window-width)) 3)))
      (fill-region (point-min) (point-max))
      (buffer-string))
    "\n")
   "\n"))

(defadvice! doom-dashboard-widget-loaded-with-phrase ()
  :override #'doom-dashboard-widget-loaded
  (insert
   "\n\n"
   (propertize
    (+doom-dashboard--center
     +doom-dashboard--width
     (doom-display-benchmark-h 'return))
    'face 'doom-dashboard-loaded)
   "\n"
   (doom-dashboard-phrase)
   "\n"))

(remove-hook '+doom-dashboard-functions #'doom-dashboard-widget-shortmenu)
(add-hook! '+doom-dashboard-mode-hook (hide-mode-line-mode 1) (hl-line-mode -1))
(setq-hook! '+doom-dashboard-mode-hook evil-normal-state-cursor (list nil))

(defun doom-dashboard-draw-ascii-emacs-banner-fn ()
  (let* ((banner
          '("            :h-                                  Nhy`               "
            "           -mh.                           h.    `Ndho               "
            "           hmh+                          oNm.   oNdhh               "
            "          `Nmhd`                        /NNmd  /NNhhd               "
            "          -NNhhy                      `hMNmmm`+NNdhhh               "
            "          .NNmhhs              ```....`..-:/./mNdhhh+               "
            "           mNNdhhh-     `.-::///+++////++//:--.`-/sd`               "
            "           oNNNdhhdo..://++//++++++/+++//++///++/-.`                "
            "      y.   `mNNNmhhhdy+/++++//+/////++//+++///++////-` `/oos:       "
            " .    Nmy:  :NNNNmhhhhdy+/++/+++///:.....--:////+++///:.`:s+        "
            " h-   dNmNmy oNNNNNdhhhhy:/+/+++/-         ---:/+++//++//.`         "
            " hd+` -NNNy`./dNNNNNhhhh+-://///    -+oo:`  ::-:+////++///:`        "
            " /Nmhs+oss-:++/dNNNmhho:--::///    /mmmmmo  ../-///++///////.       "
            "  oNNdhhhhhhhs//osso/:---:::///    /yyyyso  ..o+-//////////:/.      "
            "   /mNNNmdhhhh/://+///::://////     -:::- ..+sy+:////////::/:/.     "
            "     /hNNNdhhs--:/+++////++/////.      ..-/yhhs-/////////::/::/`    "
            "       .ooo+/-::::/+///////++++//-/ossyyhhhhs/:///////:::/::::/:    "
            "       -///:::::::////++///+++/////:/+ooo+/::///////.::://::---+`   "
            "       /////+//++++/////+////-..//////////::-:::--`.:///:---:::/:   "
            "       //+++//++++++////+++///::--                 .::::-------::   "
            "       :/++++///////////++++//////.                -:/:----::../-   "
            "       -/++++//++///+//////////////               .::::---:::-.+`   "
            "       `////////////////////////////:.            --::-----...-/    "
            "        -///://////////////////////::::-..      :-:-:-..-::.`.+`    "
            "         :/://///:///::://::://::::::/:::::::-:---::-.-....``/- -   "
            "           ::::://::://::::::::::::::----------..-:....`.../- -+oo/ "
            "            -/:::-:::::---://:-::-::::----::---.-.......`-/.      ``"
            "           s-`::--:::------:////----:---.-:::...-.....`./:          "
            "          yMNy.`::-.--::..-dmmhhhs-..-.-.......`.....-/:`           "
            "         oMNNNh. `-::--...:NNNdhhh/.--.`..``.......:/-              "
            "        :dy+:`      .-::-..NNNhhd+``..`...````.-::-`                "
            "                        .-:mNdhh:.......--::::-`                    "
            "                           yNh/..------..`                          "
            "                                                                    "
            "                               E M A C S                            "))
         (longest-line (apply #'max (mapcar #'length banner))))
    (put-text-property
     (point)
     (dolist (line banner (point))
       (insert (+doom-dashboard--center
                +doom-dashboard--width
                (concat
                 line (make-string (max 0 (- longest-line (length line)))
                                   32)))
               "\n"))
     'face 'doom-dashboard-banner)))

(unless (display-graphic-p) ; for some reason this messes up the graphical splash screen atm
  (setq +doom-dashboard-ascii-banner-fn #'doom-dashboard-draw-ascii-emacs-banner-fn))

(setq +doom-quit-messages '(;;from doom 1
                            "Don't leave yet -- There's a daemon around that corner!"
                            "Go ahead and leave. See if I care."
                            ;;from doom 2
                            "Get outta here and go back to your boring programs."
                            ;;from Portal
                            "Thank you for participating in this Aperture Science computer-aided enrichment activity."
                            "You can't fire me, I quit!"
                            "I'm the man who's going to burn your house down! With the lemons!"
                            ;;custom
                            "It's not like I'll miss you or anything, b-baka!"
                            "Please don't go. The drones need you. They look up to you."))

(after! marginalia
  (setq marginalia-censor-variables nil)

  (defadvice! +marginalia--anotate-local-file-colorful (cand)
    "Just a more colourful version of `marginalia--anotate-local-file'."
    :override #'marginalia--annotate-local-file
    (when-let (attrs (file-attributes (substitute-in-file-name
                                       (marginalia--full-candidate cand))
                                      'integer))
      (marginalia--fields
       ((marginalia--file-owner attrs)
        :width 12 :face 'marginalia-file-owner)
       ((marginalia--file-modes attrs))
       ((+marginalia-file-size-colorful (file-attribute-size attrs))
        :width 7)
       ((+marginalia--time-colorful (file-attribute-modification-time attrs))
        :width 12))))

  (defun +marginalia--time-colorful (time)
    (let* ((seconds (float-time (time-subtract (current-time) time)))
           (color (doom-blend
                   (face-attribute 'marginalia-date :foreground nil t)
                   (face-attribute 'marginalia-documentation :foreground nil t)
                   (/ 1.0 (log (+ 3 (/ (+ 1 seconds) 345600.0)))))))
      ;; 1 - log(3 + 1/(days + 1)) % grey
      (propertize (marginalia--time time) 'face (list :foreground color))))

  (defun +marginalia-file-size-colorful (size)
    (let* ((size-index (/ (log10 (+ 1 size)) 7.0))
           (color (if (< size-index 10000000) ; 10m
                      (doom-blend 'orange 'green size-index)
                    (doom-blend 'red 'orange (- size-index 1)))))
      (propertize (file-size-human-readable size) 'face (list :foreground color)))))

(setq +zen-text-scale 0.8)

(defvar +zen-serif-p t
  "Whether to use a serifed font with `mixed-pitch-mode'.")
(after! writeroom-mode
  (defvar-local +zen--original-org-indent-mode-p nil)
  (defvar-local +zen--original-mixed-pitch-mode-p nil)
  (defun +zen-enable-mixed-pitch-mode-h ()
    "Enable `mixed-pitch-mode' when in `+zen-mixed-pitch-modes'."
    (when (apply #'derived-mode-p +zen-mixed-pitch-modes)
      (if writeroom-mode
          (progn
            (setq +zen--original-mixed-pitch-mode-p mixed-pitch-mode)
            (funcall (if +zen-serif-p #'mixed-pitch-serif-mode #'mixed-pitch-mode) 1))
        (funcall #'mixed-pitch-mode (if +zen--original-mixed-pitch-mode-p 1 -1)))))
  (pushnew! writeroom--local-variables
            'display-line-numbers
            'visual-fill-column-width
            'org-adapt-indentation)
  (add-hook 'writeroom-mode-enable-hook
            (defun +zen-prose-org-h ()
              "Reformat the current Org buffer appearance for prose."
              (when (eq major-mode 'org-mode)
                (setq display-line-numbers nil
                      visual-fill-column-width 60
                      org-adapt-indentation nil
                      +zen--original-org-indent-mode-p org-indent-mode)
                (org-indent-mode -1))))
  (add-hook! 'writeroom-mode-hook
    (if writeroom-mode
        (add-hook 'post-command-hook #'recenter nil t)
      (remove-hook 'post-command-hook #'recenter t)))
  (add-hook 'writeroom-mode-enable-hook #'doom-disable-line-numbers-h)
  (add-hook 'writeroom-mode-disable-hook #'doom-enable-line-numbers-h)
  (add-hook 'writeroom-mode-disable-hook
            (defun +zen-nonprose-org-h ()
              "Reverse the effect of `+zen-prose-org'."
              (when (eq major-mode 'org-mode)
                (when +zen--original-org-indent-mode-p (org-indent-mode 1))))))

(map! :map elfeed-search-mode-map
      :after elfeed-search
      [remap kill-this-buffer] "q"
      [remap kill-buffer] "q"
      :n doom-leader-key nil
      :n "q" #'+rss/quit
      :n "e" #'elfeed-update
      :n "r" #'elfeed-search-untag-all-unread
      :n "u" #'elfeed-search-tag-all-unread
      :n "s" #'elfeed-search-live-filter
      :n "RET" #'elfeed-search-show-entry
      :n "p" #'elfeed-show-pdf
      :n "+" #'elfeed-search-tag-all
      :n "-" #'elfeed-search-untag-all
      :n "S" #'elfeed-search-set-filter
      :n "b" #'elfeed-search-browse-url
      :n "y" #'elfeed-search-yank)
(map! :map elfeed-show-mode-map
      :after elfeed-show
      [remap kill-this-buffer] "q"
      [remap kill-buffer] "q"
      :n doom-leader-key nil
      :nm "q" #'+rss/delete-pane
      :nm "o" #'ace-link-elfeed
      :nm "RET" #'org-ref-elfeed-add
      :nm "n" #'elfeed-show-next
      :nm "N" #'elfeed-show-prev
      :nm "p" #'elfeed-show-pdf
      :nm "+" #'elfeed-show-tag
      :nm "-" #'elfeed-show-untag
      :nm "s" #'elfeed-show-new-live-search
      :nm "y" #'elfeed-show-yank)

(after! elfeed-search
  (set-evil-initial-state! 'elfeed-search-mode 'normal))
(after! elfeed-show-mode
  (set-evil-initial-state! 'elfeed-show-mode   'normal))

(after! evil-snipe
  (push 'elfeed-show-mode   evil-snipe-disabled-modes)
  (push 'elfeed-search-mode evil-snipe-disabled-modes))

(after! elfeed
  (elfeed-org)
  (use-package! elfeed-link)

  (setq elfeed-search-filter "@1-week-ago +unread"
        elfeed-search-print-entry-function '+rss/elfeed-search-print-entry
        elfeed-search-title-min-width 80
        elfeed-show-entry-switch #'pop-to-buffer
        elfeed-show-entry-delete #'+rss/delete-pane
        elfeed-show-refresh-function #'+rss/elfeed-show-refresh--better-style
        shr-max-image-proportion 0.6)

  (add-hook! 'elfeed-show-mode-hook (hide-mode-line-mode 1))
  (add-hook! 'elfeed-search-update-hook #'hide-mode-line-mode)

  (defface elfeed-show-title-face '((t (:weight ultrabold :slant italic :height 1.5)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  (defface elfeed-show-author-face `((t (:weight light)))
    "title face in elfeed show buffer"
    :group 'elfeed)
  (set-face-attribute 'elfeed-search-title-face nil
                      :foreground 'nil
                      :weight 'light)

  (defadvice! +rss-elfeed-wrap-h-nicer ()
    "Enhances an elfeed entry's readability by wrapping it to a width of
`fill-column' and centering it with `visual-fill-column-mode'."
    :override #'+rss-elfeed-wrap-h
    (setq-local truncate-lines nil
                shr-width 120
                visual-fill-column-center-text t
                default-text-properties '(line-height 1.1))
    (let ((inhibit-read-only t)
          (inhibit-modification-hooks t))
      (visual-fill-column-mode)
      ;; (setq-local shr-current-font '(:family "Merriweather" :height 1.2))
      (set-buffer-modified-p nil)))

  (defun +rss/elfeed-search-print-entry (entry)
    "Print ENTRY to the buffer."
    (let* ((elfeed-goodies/tag-column-width 40)
           (elfeed-goodies/feed-source-column-width 30)
           (title (or (elfeed-meta entry :title) (elfeed-entry-title entry) ""))
           (title-faces (elfeed-search--faces (elfeed-entry-tags entry)))
           (feed (elfeed-entry-feed entry))
           (feed-title
            (when feed
              (or (elfeed-meta feed :title) (elfeed-feed-title feed))))
           (tags (mapcar #'symbol-name (elfeed-entry-tags entry)))
           (tags-str (concat (mapconcat 'identity tags ",")))
           (title-width (- (window-width) elfeed-goodies/feed-source-column-width
                           elfeed-goodies/tag-column-width 4))

           (tag-column (elfeed-format-column
                        tags-str (elfeed-clamp (length tags-str)
                                               elfeed-goodies/tag-column-width
                                               elfeed-goodies/tag-column-width)
                        :left))
           (feed-column (elfeed-format-column
                         feed-title (elfeed-clamp elfeed-goodies/feed-source-column-width
                                                  elfeed-goodies/feed-source-column-width
                                                  elfeed-goodies/feed-source-column-width)
                         :left)))

      (insert (propertize feed-column 'face 'elfeed-search-feed-face) " ")
      (insert (propertize tag-column 'face 'elfeed-search-tag-face) " ")
      (insert (propertize title 'face title-faces 'kbd-help title))))

  (defun +rss/elfeed-show-refresh--better-style ()
    "Update the buffer to match the selected entry, using a mail-style."
    (interactive)
    (let* ((inhibit-read-only t)
           (title (elfeed-entry-title elfeed-show-entry))
           (date (seconds-to-time (elfeed-entry-date elfeed-show-entry)))
           (author (elfeed-meta elfeed-show-entry :author))
           (link (elfeed-entry-link elfeed-show-entry))
           (tags (elfeed-entry-tags elfeed-show-entry))
           (tagsstr (mapconcat #'symbol-name tags ", "))
           (nicedate (format-time-string "%a, %e %b %Y %T %Z" date))
           (content (elfeed-deref (elfeed-entry-content elfeed-show-entry)))
           (type (elfeed-entry-content-type elfeed-show-entry))
           (feed (elfeed-entry-feed elfeed-show-entry))
           (feed-title (elfeed-feed-title feed))
           (base (and feed (elfeed-compute-base (elfeed-feed-url feed)))))
      (erase-buffer)
      (insert "\n")
      (insert (format "%s\n\n" (propertize title 'face 'elfeed-show-title-face)))
      (insert (format "%s\t" (propertize feed-title 'face 'elfeed-search-feed-face)))
      (when (and author elfeed-show-entry-author)
        (insert (format "%s\n" (propertize author 'face 'elfeed-show-author-face))))
      (insert (format "%s\n\n" (propertize nicedate 'face 'elfeed-log-date-face)))
      (when tags
        (insert (format "%s\n"
                        (propertize tagsstr 'face 'elfeed-search-tag-face))))
      ;; (insert (propertize "Link: " 'face 'message-header-name))
      ;; (elfeed-insert-link link link)
      ;; (insert "\n")
      (cl-loop for enclosure in (elfeed-entry-enclosures elfeed-show-entry)
               do (insert (propertize "Enclosure: " 'face 'message-header-name))
               do (elfeed-insert-link (car enclosure))
               do (insert "\n"))
      (insert "\n")
      (if content
          (if (eq type 'html)
              (elfeed-insert-html content base)
            (insert content))
        (insert (propertize "(empty)\n" 'face 'italic)))
      (goto-char (point-min)))))

(after! elfeed-show
  (require 'url)

  (defvar elfeed-pdf-dir
    (expand-file-name "pdfs/"
                      (file-name-directory (directory-file-name elfeed-enclosure-default-dir))))

  (defvar elfeed-link-pdfs
    '(("https://www.jstatsoft.org/index.php/jss/article/view/v0\\([^/]+\\)" . "https://www.jstatsoft.org/index.php/jss/article/view/v0\\1/v\\1.pdf")
      ("http://arxiv.org/abs/\\([^/]+\\)" . "https://arxiv.org/pdf/\\1.pdf"))
    "List of alists of the form (REGEX-FOR-LINK . FORM-FOR-PDF)")

  (defun elfeed-show-pdf (entry)
    (interactive
     (list (or elfeed-show-entry (elfeed-search-selected :ignore-region))))
    (let ((link (elfeed-entry-link entry))
          (feed-name (plist-get (elfeed-feed-meta (elfeed-entry-feed entry)) :title))
          (title (elfeed-entry-title entry))
          (file-view-function
           (lambda (f)
             (when elfeed-show-entry
               (elfeed-kill-buffer))
             (pop-to-buffer (find-file-noselect f))))
          pdf)

      (let ((file (expand-file-name
                   (concat (subst-char-in-string ?/ ?, title) ".pdf")
                   (expand-file-name (subst-char-in-string ?/ ?, feed-name)
                                     elfeed-pdf-dir))))
        (if (file-exists-p file)
            (funcall file-view-function file)
          (dolist (link-pdf elfeed-link-pdfs)
            (when (and (string-match-p (car link-pdf) link)
                       (not pdf))
              (setq pdf (replace-regexp-in-string (car link-pdf) (cdr link-pdf) link))))
          (if (not pdf)
              (message "No associated PDF for entry")
            (message "Fetching %s" pdf)
            (unless (file-exists-p (file-name-directory file))
              (make-directory (file-name-directory file) t))
            (url-copy-file pdf file)
            (funcall file-view-function file)))))))

(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :config
  (map! :map nov-mode-map
        :n "RET" #'nov-scroll-up)

  (advice-add 'nov-render-title :override #'ignore)
  (defun +nov-mode-setup ()
    (face-remap-add-relative 'variable-pitch
                             :family "Overpass"
                             :height 1.4
                             :width 'semi-expanded)
    (face-remap-add-relative 'default :height 1.3)
    (setq-local next-screen-context-lines 4
                shr-use-colors nil)
    (require 'visual-fill-column nil t)
    (setq-local visual-fill-column-center-text t
                visual-fill-column-width 81
                nov-text-width 80)
    (visual-fill-column-mode 1)
    (add-to-list '+lookup-definition-functions #'+lookup/dictionary-definition)
    (add-hook 'nov-mode-hook #'+nov-mode-setup)))

(use-package! org-pandoc-import
  :after org)

(after! org
  (setq org-directory "~/org"                       ; let's put files here
        org-roam-directory "~/org/roam/"            ; same thing, for roam
        org-use-property-inheritance t              ; it's convenient to have properties inherited
        org-log-done 'time                          ; having the time a item is done sounds convenient
        org-list-allow-alphabetical t               ; have a. A. a) A) list bullets
        org-export-in-background t                  ; run export processes in external emacs process
        org-catch-invisible-edits 'smart))          ; try not to accidently do weird stuff in invisible regions

(after! org
  (setq org-babel-default-header-args
        '((:session . "none")
          (:results . "replace")
          (:exports . "code")
          (:cache . "no")
          (:noweb . "no")
          (:hlines . "no")
          (:tangle . "no")
          (:comments . "link"))))

(after! org
  (setq org-list-demote-modify-bullet '(("+" . "-") ("-" . "+") ("*" . "+") ("1." . "a."))))

(after! org-superstar
  (setq org-superstar-headline-bullets-list '("一" "二" "三" "五" "六" "七" "八" )
        org-superstar-prettify-item-bullets t))

(use-package! org-ol-tree
  :commands org-ol-tree)

(map! :map org-mode-map
      :after org
      :localleader
      :desc "Outline" "O" #'org-ol-tree)

(after! ox
  (org-link-set-parameters "yt" :export #'+org-export-yt)
  (defun +org-export-yt (path desc backend _com)
    (cond ((org-export-derived-backend-p backend 'html)
           (format "<iframe width='440' \
height='335' \
src='https://www.youtube.com/embed/%s' \
frameborder='0' \
allowfullscreen>%s</iframe>" path (or "" desc)))
          ((org-export-derived-backend-p backend 'latex)
           (format "\\href{https://youtu.be/%s}{%s}" path (or desc "youtube")))
          (t (format "https://youtu.be/%s" path)))))

(setq org-startup-with-inline-images t)

(defun edit-src-block (src fn language)
  "Replace SRC org-element's value property with the result of FN.
FN is a function that operates on org-element's value and returns a string.
LANGUAGE is a string referring to one of orb-babel's supported languages.
(https://orgmode.org/manual/Languages.html#Languages)"
  (let ((src-language (org-element-property :language src))
        (value (org-element-property :value src)))
    (when (string= src-language language)
      (let ((copy (org-element-copy src)))
        (org-element-put-property copy :value
                                  (funcall fn value))
        (org-element-set-element src copy)))))

(defun format-elisp-string (string)
  "Indents elisp buffer string and reformats dangling parens."
  (with-temp-buffer
    (let ((inhibit-message t))
      (emacs-lisp-mode)
      (insert
       (replace-regexp-in-string "[[:space:]]*
[[:space:]]*)" ")" string))
      (indent-region (point-min) (point-max))
      (buffer-substring (point-min) (point-max)))))

(defun format-elisp-src-blocks ()
  "Format Elisp src blocks in the current org buffer"
  (interactive)
  (save-mark-and-excursion
    (let ((AST (org-element-parse-buffer)))
      (org-element-map AST 'src-block
        (lambda (element)
          (edit-src-block element #'format-elisp-string "emacs-lisp")))
      (delete-region (point-min) (point-max))
      (insert (org-element-interpret-data AST)))))

(add-hook 'org-mode-hook
          (lambda ()
            (add-hook 'after-save-hook #'format-elisp-src-blocks)))

(use-package! ox-gfm
  :after org)

(after! ox-html
  (define-minor-mode org-fancy-html-export-mode
    "Toggle my fabulous org export tweaks. While this mode itself does a little bit,
the vast majority of the change in behaviour comes from switch statements in:
 - `org-html-template-fancier'
 - `org-html--build-meta-info-extended'
 - `org-html-src-block-collapsable'
 - `org-html-block-collapsable'
 - `org-html-table-wrapped'
 - `org-html--format-toc-headline-colapseable'
 - `org-html--toc-text-stripped-leaves'
 - `org-export-html-headline-anchor'"
    :global t
    :init-value t
    (if org-fancy-html-export-mode
        (setq org-html-style-default org-html-style-fancy
              org-html-meta-tags #'org-html-meta-tags-fancy
              org-html-checkbox-type 'html-span)
      (setq org-html-style-default org-html-style-plain
            org-html-meta-tags #'org-html-meta-tags-default
            org-html-checkbox-type 'html)))

  (defadvice! org-html-template-fancier (orig-fn contents info)
    "Return complete document string after HTML conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options. Adds a few extra things to the body
compared to the default implementation."
    :around #'org-html-template
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn contents info)
      (concat
       (when (and (not (org-html-html5-p info)) (org-html-xhtml-p info))
         (let* ((xml-declaration (plist-get info :html-xml-declaration))
                (decl (or (and (stringp xml-declaration) xml-declaration)
                          (cdr (assoc (plist-get info :html-extension)
                                      xml-declaration))
                          (cdr (assoc "html" xml-declaration))
                          "")))
           (when (not (or (not decl) (string= "" decl)))
             (format "%s\n"
                     (format decl
                             (or (and org-html-coding-system
                                      (fboundp 'coding-system-get)
                                      (coding-system-get org-html-coding-system 'mime-charset))
                                 "iso-8859-1"))))))
       (org-html-doctype info)
       "\n"
       (concat "<html"
               (cond ((org-html-xhtml-p info)
                      (format
                       " xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"%s\" xml:lang=\"%s\""
                       (plist-get info :language) (plist-get info :language)))
                     ((org-html-html5-p info)
                      (format " lang=\"%s\"" (plist-get info :language))))
               ">\n")
       "<head>\n"
       (org-html--build-meta-info info)
       (org-html--build-head info)
       (org-html--build-mathjax-config info)
       "</head>\n"
       "<body>\n<input type='checkbox' id='theme-switch'><div id='page'><label id='switch-label' for='theme-switch'></label>"
       (let ((link-up (org-trim (plist-get info :html-link-up)))
             (link-home (org-trim (plist-get info :html-link-home))))
         (unless (and (string= link-up "") (string= link-home ""))
           (format (plist-get info :html-home/up-format)
                   (or link-up link-home)
                   (or link-home link-up))))
       ;; Preamble.
       (org-html--build-pre/postamble 'preamble info)
       ;; Document contents.
       (let ((div (assq 'content (plist-get info :html-divs))))
         (format "<%s id=\"%s\">\n" (nth 1 div) (nth 2 div)))
       ;; Document title.
       (when (plist-get info :with-title)
         (let ((title (and (plist-get info :with-title)
                           (plist-get info :title)))
               (subtitle (plist-get info :subtitle))
               (html5-fancy (org-html--html5-fancy-p info)))
           (when title
             (format
              (if html5-fancy
                  "<header class=\"page-header\">%s\n<h1 class=\"title\">%s</h1>\n%s</header>"
                "<h1 class=\"title\">%s%s</h1>\n")
              (if (or (plist-get info :with-date)
                      (plist-get info :with-author))
                  (concat "<div class=\"page-meta\">"
                          (when (plist-get info :with-date)
                            (org-export-data (plist-get info :date) info))
                          (when (and (plist-get info :with-date) (plist-get info :with-author)) ", ")
                          (when (plist-get info :with-author)
                            (org-export-data (plist-get info :author) info))
                          "</div>\n")
                "")
              (org-export-data title info)
              (if subtitle
                  (format
                   (if html5-fancy
                       "<p class=\"subtitle\" role=\"doc-subtitle\">%s</p>\n"
                     (concat "\n" (org-html-close-tag "br" nil info) "\n"
                             "<span class=\"subtitle\">%s</span>\n"))
                   (org-export-data subtitle info))
                "")))))
       contents
       (format "</%s>\n" (nth 1 (assq 'content (plist-get info :html-divs))))
       ;; Postamble.
       (org-html--build-pre/postamble 'postamble info)
       ;; Possibly use the Klipse library live code blocks.
       (when (plist-get info :html-klipsify-src)
         (concat "<script>" (plist-get info :html-klipse-selection-script)
                 "</script><script src=\""
                 org-html-klipse-js
                 "\"></script><link rel=\"stylesheet\" type=\"text/css\" href=\""
                 org-html-klipse-css "\"/>"))
       ;; Closing document.
       "</div>\n</body>\n</html>")))

  (defadvice! org-html-toc-linked (depth info &optional scope)
    "Build a table of contents.

Just like `org-html-toc', except the header is a link to \"#\".

DEPTH is an integer specifying the depth of the table.  INFO is
a plist used as a communication channel.  Optional argument SCOPE
is an element defining the scope of the table.  Return the table
of contents as a string, or nil if it is empty."
    :override #'org-html-toc
    (let ((toc-entries
           (mapcar (lambda (headline)
                     (cons (org-html--format-toc-headline headline info)
                           (org-export-get-relative-level headline info)))
                   (org-export-collect-headlines info depth scope))))
      (when toc-entries
        (let ((toc (concat "<div id=\"text-table-of-contents\">"
                           (org-html--toc-text toc-entries)
                           "</div>\n")))
          (if scope toc
            (let ((outer-tag (if (org-html--html5-fancy-p info)
                                 "nav"
                               "div")))
              (concat (format "<%s id=\"table-of-contents\">\n" outer-tag)
                      (let ((top-level (plist-get info :html-toplevel-hlevel)))
                        (format "<h%d><a href=\"#\" style=\"color:inherit; text-decoration: none;\">%s</a></h%d>\n"
                                top-level
                                (org-html--translate "Table of Contents" info)
                                top-level))
                      toc
                      (format "</%s>\n" outer-tag))))))))

  (defvar org-html-meta-tags-opengraph-image
    '(:image "https://tecosaur.com/resources/org/nib.png"
      :type "image/png"
      :width "200"
      :height "200"
      :alt "Green fountain pen nib")
    "Plist of og:image:PROP properties and their value, for use in `org-html-meta-tags-fancy'.")

  (defun org-html-meta-tags-fancy (info)
    "Use the INFO plist to construct the meta tags, as described in `org-html-meta-tags'."
    (let ((title (org-html-plain-text
                  (org-element-interpret-data (plist-get info :title)) info))
          (author (and (plist-get info :with-author)
                       (let ((auth (plist-get info :author)))
                         ;; Return raw Org syntax.
                         (and auth (org-html-plain-text
                                    (org-element-interpret-data auth) info))))))
      (append
       (list
        (when (org-string-nw-p author)
          (list "name" "author" author))
        (when (org-string-nw-p (plist-get info :description))
          (list "name" "description"
                (plist-get info :description)))
        '("name" "generator" "org mode")
        '("name" "theme-color" "#77aa99")
        '("property" "og:type" "article")
        (list "property" "og:title" title)
        (let ((subtitle (org-export-data (plist-get info :subtitle) info)))
          (when (org-string-nw-p subtitle)
            (list "property" "og:description" subtitle))))
       (when org-html-meta-tags-opengraph-image
         (list (list "property" "og:image" (plist-get org-html-meta-tags-opengraph-image :image))
               (list "property" "og:image:type" (plist-get org-html-meta-tags-opengraph-image :type))
               (list "property" "og:image:width" (plist-get org-html-meta-tags-opengraph-image :width))
               (list "property" "og:image:height" (plist-get org-html-meta-tags-opengraph-image :height))
               (list "property" "og:image:alt" (plist-get org-html-meta-tags-opengraph-image :alt))))
       (list
        (when (org-string-nw-p author)
          (list "property" "og:article:author:first_name" (car (s-split-up-to " " author 2))))
        (when (and (org-string-nw-p author) (s-contains-p " " author))
          (list "property" "og:article:author:last_name" (cadr (s-split-up-to " " author 2))))
        (list "property" "og:article:published_time"
              (format-time-string
               "%FT%T%z"
               (or
                (when-let ((date-str (cadar (org-collect-keywords '("DATE")))))
                  (unless (string= date-str (format-time-string "%F"))
                    (ignore-errors (encode-time (org-parse-time-string date-str)))))
                (if buffer-file-name
                    (file-attribute-modification-time (file-attributes buffer-file-name))
                  (current-time)))))
        (when buffer-file-name
          (list "property" "og:article:modified_time"
                (format-time-string "%FT%T%z" (file-attribute-modification-time (file-attributes buffer-file-name)))))))))

  (unless (functionp #'org-html-meta-tags-default)
    (defalias 'org-html-meta-tags-default #'ignore))
  (setq org-html-meta-tags #'org-html-meta-tags-fancy)

  (setq org-html-style-plain org-html-style-default
        org-html-htmlize-output-type 'css
        org-html-doctype "html5"
        org-html-html5-fancy t)

  (defun org-html-reload-fancy-style ()
    (interactive)
    (setq org-html-style-fancy
          (concat (f-read-text (expand-file-name "misc/org-export-header.html" doom-private-dir))
                  "<script>\n"
                  (f-read-text (expand-file-name "misc/org-css/main.js" doom-private-dir))
                  "</script>\n<style>\n"
                  (f-read-text (expand-file-name "misc/org-css/main.min.css" doom-private-dir))
                  "</style>"))
    (when org-fancy-html-export-mode
      (setq org-html-style-default org-html-style-fancy)))
  (org-html-reload-fancy-style)

  (defvar org-html-export-collapsed nil)
  (eval '(cl-pushnew '(:collapsed "COLLAPSED" "collapsed" org-html-export-collapsed t)
                     (org-export-backend-options (org-export-get-backend 'html))))
  (add-to-list 'org-default-properties "EXPORT_COLLAPSED")

  (defadvice! org-html-src-block-collapsable (orig-fn src-block contents info)
    "Wrap the usual <pre> block in a <details>"
    :around #'org-html-src-block
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn src-block contents info)
      (let* ((properties (cadr src-block))
             (lang (mode-name-to-lang-name
                    (plist-get properties :language)))
             (name (plist-get properties :name))
             (ref (org-export-get-reference src-block info))
             (collapsed-p (member (or (org-export-read-attribute :attr_html src-block :collapsed)
                                      (plist-get info :collapsed))
                                  '("y" "yes" "t" t "true" "all"))))
        (format
         "<details id='%s' class='code'%s><summary%s>%s</summary>
<div class='gutter'>
<a href='#%s'>#</a>
<button title='Copy to clipboard' onclick='copyPreToClipbord(this)'>⎘</button>\
</div>
%s
</details>"
         ref
         (if collapsed-p "" " open")
         (if name " class='named'" "")
         (concat
          (when name (concat "<span class=\"name\">" name "</span>"))
          "<span class=\"lang\">" lang "</span>")
         ref
         (if name
             (replace-regexp-in-string (format "<pre\\( class=\"[^\"]+\"\\)? id=\"%s\">" ref) "<pre\\1>"
                                       (funcall orig-fn src-block contents info))
           (funcall orig-fn src-block contents info))))))

  (defun mode-name-to-lang-name (mode)
    (or (cadr (assoc mode
                     '(("asymptote" "Asymptote")
                       ("awk" "Awk")
                       ("C" "C")
                       ("clojure" "Clojure")
                       ("css" "CSS")
                       ("D" "D")
                       ("ditaa" "ditaa")
                       ("dot" "Graphviz")
                       ("calc" "Emacs Calc")
                       ("emacs-lisp" "Emacs Lisp")
                       ("fortran" "Fortran")
                       ("gnuplot" "gnuplot")
                       ("haskell" "Haskell")
                       ("hledger" "hledger")
                       ("java" "Java")
                       ("js" "Javascript")
                       ("latex" "LaTeX")
                       ("ledger" "Ledger")
                       ("lisp" "Lisp")
                       ("lilypond" "Lilypond")
                       ("lua" "Lua")
                       ("matlab" "MATLAB")
                       ("mscgen" "Mscgen")
                       ("ocaml" "Objective Caml")
                       ("octave" "Octave")
                       ("org" "Org mode")
                       ("oz" "OZ")
                       ("plantuml" "Plantuml")
                       ("processing" "Processing.js")
                       ("python" "Python")
                       ("R" "R")
                       ("ruby" "Ruby")
                       ("sass" "Sass")
                       ("scheme" "Scheme")
                       ("screen" "Gnu Screen")
                       ("sed" "Sed")
                       ("sh" "shell")
                       ("sql" "SQL")
                       ("sqlite" "SQLite")
                       ("forth" "Forth")
                       ("io" "IO")
                       ("J" "J")
                       ("makefile" "Makefile")
                       ("maxima" "Maxima")
                       ("perl" "Perl")
                       ("picolisp" "Pico Lisp")
                       ("scala" "Scala")
                       ("shell" "Shell Script")
                       ("ebnf2ps" "ebfn2ps")
                       ("cpp" "C++")
                       ("abc" "ABC")
                       ("coq" "Coq")
                       ("groovy" "Groovy")
                       ("bash" "bash")
                       ("csh" "csh")
                       ("ash" "ash")
                       ("dash" "dash")
                       ("ksh" "ksh")
                       ("mksh" "mksh")
                       ("posh" "posh")
                       ("ada" "Ada")
                       ("asm" "Assembler")
                       ("caml" "Caml")
                       ("delphi" "Delphi")
                       ("html" "HTML")
                       ("idl" "IDL")
                       ("mercury" "Mercury")
                       ("metapost" "MetaPost")
                       ("modula-2" "Modula-2")
                       ("pascal" "Pascal")
                       ("ps" "PostScript")
                       ("prolog" "Prolog")
                       ("simula" "Simula")
                       ("tcl" "tcl")
                       ("tex" "LaTeX")
                       ("plain-tex" "TeX")
                       ("verilog" "Verilog")
                       ("vhdl" "VHDL")
                       ("xml" "XML")
                       ("nxml" "XML")
                       ("conf" "Configuration File"))))
        mode))

  (defadvice! org-html-table-wrapped (orig-fn table contents info)
    "Wrap the usual <table> in a <div>"
    :around #'org-html-table
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn table contents info)
      (let* ((name (plist-get (cadr table) :name))
             (ref (org-export-get-reference table info)))
        (format "<div id='%s' class='table'>
<div class='gutter'><a href='#%s'>#</a></div>
<div class='tabular'>
%s
</div>\
</div>"
                ref ref
                (if name
                    (replace-regexp-in-string (format "<table id=\"%s\"" ref) "<table"
                                              (funcall orig-fn table contents info))
                  (funcall orig-fn table contents info))))))


  (defadvice! org-html--format-toc-headline-colapseable (orig-fn headline info)
    "Add a label and checkbox to `org-html--format-toc-headline's usual output,
to allow the TOC to be a collapseable tree."
    :around #'org-html--format-toc-headline
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn headline info)
      (let ((id (or (org-element-property :CUSTOM_ID headline)
                    (org-export-get-reference headline info))))
        (format "<input type='checkbox' id='toc--%s'/><label for='toc--%s'>%s</label>"
                id id (funcall orig-fn headline info)))))

  (defadvice! org-html--toc-text-stripped-leaves (orig-fn toc-entries)
    "Remove label"
    :around #'org-html--toc-text
    (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
        (funcall orig-fn toc-entries)
      (replace-regexp-in-string "<input [^>]+><label [^>]+>\\(.+?\\)</label></li>" "\\1</li>"
                                (funcall orig-fn toc-entries))))

  (setq org-html-text-markup-alist
        '((bold . "<b>%s</b>")
          (code . "<code>%s</code>")
          (italic . "<i>%s</i>")
          (strike-through . "<del>%s</del>")
          (underline . "<span class=\"underline\">%s</span>")
          (verbatim . "<kbd>%s</kbd>")))

  (appendq! org-html-checkbox-types
            '((html-span
               (on . "<span class='checkbox'></span>")
               (off . "<span class='checkbox'></span>")
               (trans . "<span class='checkbox'></span>"))))
  (setq org-html-checkbox-type 'html-span)

  (pushnew! org-html-special-string-regexps
            '("-&gt;" . "&#8594;")
            '("&lt;-" . "&#8592;"))

  (defun org-export-html-headline-anchor (text backend info)
    (when (and (org-export-derived-backend-p backend 'html)
               (not (org-export-derived-backend-p backend 're-reveal))
               org-fancy-html-export-mode)
      (unless (bound-and-true-p org-msg-export-in-progress)
        (replace-regexp-in-string
         "<h\\([0-9]\\) id=\"\\([a-z0-9-]+\\)\">\\(.*[^ ]\\)<\\/h[0-9]>" ; this is quite restrictive, but due to `org-reference-contraction' I can do this
         "<h\\1 id=\"\\2\">\\3<a aria-hidden=\"true\" href=\"#\\2\">#</a> </h\\1>"
         text))))

  (add-to-list 'org-export-filter-headline-functions
               'org-export-html-headline-anchor)

  (org-link-set-parameters "Https"
                           :follow (lambda (url arg) (browse-url (concat "https:" url) arg))
                           :export #'org-url-fancy-export)

  (defun org-url-fancy-export (url _desc backend)
    (let ((metadata (org-url-unfurl-metadata (concat "https:" url))))
      (cond
       ((org-export-derived-backend-p backend 'html)
        (concat
         "<div class=\"link-preview\">"
         (format "<a href=\"%s\">" (concat "https:" url))
         (when (plist-get metadata :image)
           (format "<img src=\"%s\"/>" (plist-get metadata :image)))
         "<small>"
         (replace-regexp-in-string "//\\(?:www\\.\\)?\\([^/]+\\)/?.*" "\\1" url)
         "</small><p>"
         (when (plist-get metadata :title)
           (concat "<b>" (org-html-encode-plain-text (plist-get metadata :title)) "</b></br>"))
         (when (plist-get metadata :description)
           (org-html-encode-plain-text (plist-get metadata :description)))
         "</p></a></div>"))
       (t url))))

  (setq org-url-unfurl-metadata--cache nil)
  (defun org-url-unfurl-metadata (url)
    (cdr (or (assoc url org-url-unfurl-metadata--cache)
             (car (push
                   (cons
                    url
                    (let* ((head-data
                            (-filter #'listp
                                     (cdaddr
                                      (with-current-buffer (progn (message "Fetching metadata from %s" url)
                                                                  (url-retrieve-synchronously url t t 5))
                                        (goto-char (point-min))
                                        (delete-region (point-min) (- (search-forward "<head") 6))
                                        (delete-region (search-forward "</head>") (point-max))
                                        (goto-char (point-min))
                                        (while (re-search-forward "<script[^\u2800]+?</script>" nil t)
                                          (replace-match ""))
                                        (goto-char (point-min))
                                        (while (re-search-forward "<style[^\u2800]+?</style>" nil t)
                                          (replace-match ""))
                                        (libxml-parse-html-region (point-min) (point-max))))))
                           (meta (delq nil
                                       (mapcar
                                        (lambda (tag)
                                          (when (eq 'meta (car tag))
                                            (cons (or (cdr (assoc 'name (cadr tag)))
                                                      (cdr (assoc 'property (cadr tag))))
                                                  (cdr (assoc 'content (cadr tag))))))
                                        head-data))))
                      (let ((title (or (cdr (assoc "og:title" meta))
                                       (cdr (assoc "twitter:title" meta))
                                       (nth 2 (assq 'title head-data))))
                            (description (or (cdr (assoc "og:description" meta))
                                             (cdr (assoc "twitter:description" meta))
                                             (cdr (assoc "description" meta))))
                            (image (or (cdr (assoc "og:image" meta))
                                       (cdr (assoc "twitter:image" meta)))))
                        (when image
                          (setq image (replace-regexp-in-string
                                       "^/" (concat "https://" (replace-regexp-in-string "//\\([^/]+\\)/?.*" "\\1" url) "/")
                                       (replace-regexp-in-string
                                        "^//" "https://"
                                        image))))
                        (list :title title :description description :image image))))
                   org-url-unfurl-metadata--cache)))))

  (setq org-html-mathjax-options
        '((path "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js" )
          (scale "1")
          (autonumber "ams")
          (multlinewidth "85%")
          (tagindent ".8em")
          (tagside "right")))

  (setq org-html-mathjax-template
        "<script>
MathJax = {
  chtml: {
    scale: %SCALE
  },
  svg: {
    scale: %SCALE,
    fontCache: \"global\"
  },
  tex: {
    tags: \"%AUTONUMBER\",
    multlineWidth: \"%MULTLINEWIDTH\",
    tagSide: \"%TAGSIDE\",
    tagIndent: \"%TAGINDENT\"
  }
};
</script>
<script id=\"MathJax-script\" async
        src=\"%PATH\"></script>"))

(after! ox-html
  )

(defun org-html-block-collapsable (orig-fn block contents info)
  "Wrap the usual block in a <details>"
  (if (or (not org-fancy-html-export-mode) (bound-and-true-p org-msg-export-in-progress))
      (funcall orig-fn block contents info)
    (let ((ref (org-export-get-reference block info))
          (type (pcase (car block)
                  ('property-drawer "Properties")))
          (collapsed-default (pcase (car block)
                               ('property-drawer t)
                               (_ nil)))
          (collapsed-value (org-export-read-attribute :attr_html block :collapsed))
          (collapsed-p (or (member (org-export-read-attribute :attr_html block :collapsed)
                                   '("y" "yes" "t" t "true"))
                           (member (plist-get info :collapsed) '("all")))))
      (format
       "<details id='%s' class='code'%s>
<summary%s>%s</summary>
<div class='gutter'>\
<a href='#%s'>#</a>
<button title='Copy to clipboard' onclick='copyPreToClipbord(this)'>⎘</button>\
</div>
%s\n
</details>"
       ref
       (if (or collapsed-p collapsed-default) "" " open")
       (if type " class='named'" "")
       (if type (format "<span class='type'>%s</span>" type) "")
       ref
       (funcall orig-fn block contents info)))))

(advice-add 'org-html-example-block   :around #'org-html-block-collapsable)
(advice-add 'org-html-fixed-width     :around #'org-html-block-collapsable)
(advice-add 'org-html-property-drawer :around #'org-html-block-collapsable)

(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam
  :commands org-roam-ui-open
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(after! org-roam
  (setq +org-roam-open-buffer-on-find-file nil))

(after! org-agenda
  (setq org-agenda-files (list "~/org/school.org"
                               "~/org/todo.org")))

(use-package! citar
  :when (featurep! :completion vertico)
  :no-require
  :config
  (setq org-cite-insert-processor 'citar
        org-cite-follow-processor 'citar
        org-cite-activate-processor 'citar
        citar-bibliography '("~/org/references.bib"))
  (when (featurep! :lang org +roam2)
    ;; Include property drawer metadata for 'org-roam' v2.
    (setq citar-file-note-org-include '(org-id org-roam-ref))))

(use-package! citar
  :when (featurep! :completion vertico)
  :after org)

(use-package! citeproc
  :defer t)

;;; Org-Cite configuration
(map! :after org
      :map org-mode-map
      :localleader
      :desc "Insert citation" "@" #'org-cite-insert)

(use-package! oc
  :after citar
  :config
  (require 'ox)
  (setq org-cite-global-bibliography
        (let ((paths (or citar-bibliography
                         (bound-and-true-p bibtex-completion-bibliography))))
          ;; Always return bibliography paths as list for org-cite.
          (if (stringp paths) (list paths) paths)))
  ;; setup export processor; default csl/citeproc-el, with biblatex for latex
  (setq org-cite-export-processors
        '((t csl))))

;;; Org-cite processors
(use-package! oc-biblatex
  :after oc)

(use-package! oc-csl
  :after oc
  :config
  (setq org-cite-csl-styles-dir "~/.config/bib/styles"))

(use-package! oc-natbib
  :after oc)

;;;; Third-party
(use-package! citar-org
  :no-require
  :custom
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  (org-support-shift-select t)
  (citar-bibliography '("~/org/references.bib"))
  (when (featurep! :lang org +roam2)
    ;; Include property drawer metadata for 'org-roam' v2.
    (citar-org-note-include '(org-id org-roam-ref)))
  ;; Personal extras
  (setq citar-symbols
        `((file ,(all-the-icons-faicon "file-o" :v-adjust -0.1) . " ")
          (note ,(all-the-icons-material "speaker_notes" :face 'all-the-icons-silver :v-adjust -0.3) . " ")
          (link ,(all-the-icons-octicon "link" :face 'all-the-icons-dsilver :v-adjust 0.01) . " "))))

(use-package! oc-csl-activate
  :after oc
  :config
  (setq org-cite-csl-activate-use-document-style t)
  (defun +org-cite-csl-activate/enable ()
    (interactive)
    (setq org-cite-activate-processor 'csl-activate)
    (add-hook! 'org-mode-hook '((lambda () (cursor-sensor-mode 1)) org-cite-csl-activate-render-all))
    (defadvice! +org-cite-csl-activate-render-all-silent (orig-fn)
      :around #'org-cite-csl-activate-render-all
      (with-silent-modifications (funcall orig-fn)))
    (when (eq major-mode 'org-mode)
      (with-silent-modifications
        (save-excursion
          (goto-char (point-min))
          (org-cite-activate (point-max)))
        (org-cite-csl-activate-render-all)))
    (fmakunbound #'+org-cite-csl-activate/enable)))

(use-package! doct
  :commands (doct))

(defun org-capture-select-template-prettier (&optional keys)
  "Select a capture template, in a prettier way than default
Lisp programs can force the template by setting KEYS to a string."
  (let ((org-capture-templates
         (or (org-contextualize-keys
              (org-capture-upgrade-templates org-capture-templates)
              org-capture-templates-contexts)
             '(("t" "Task" entry (file+headline "" "Tasks")
                "* TODO %?\n  %u\n  %a")))))
    (if keys
        (or (assoc keys org-capture-templates)
            (error "No capture template referred to by \"%s\" keys" keys))
      (org-mks org-capture-templates
               "Select a capture template\n━━━━━━━━━━━━━━━━━━━━━━━━━"
               "Template key: "
               `(("q" ,(concat (all-the-icons-octicon "stop" :face 'all-the-icons-red :v-adjust 0.01) "\tAbort")))))))
(advice-add 'org-capture-select-template :override #'org-capture-select-template-prettier)

(defun org-mks-pretty (table title &optional prompt specials)
  "Select a member of an alist with multiple keys. Prettified.

TABLE is the alist which should contain entries where the car is a string.
There should be two types of entries.

1. prefix descriptions like (\"a\" \"Description\")
   This indicates that `a' is a prefix key for multi-letter selection, and
   that there are entries following with keys like \"ab\", \"ax\"…

2. Select-able members must have more than two elements, with the first
   being the string of keys that lead to selecting it, and the second a
   short description string of the item.

The command will then make a temporary buffer listing all entries
that can be selected with a single key, and all the single key
prefixes.  When you press the key for a single-letter entry, it is selected.
When you press a prefix key, the commands (and maybe further prefixes)
under this key will be shown and offered for selection.

TITLE will be placed over the selection in the temporary buffer,
PROMPT will be used when prompting for a key.  SPECIALS is an
alist with (\"key\" \"description\") entries.  When one of these
is selected, only the bare key is returned."
  (save-window-excursion
    (let ((inhibit-quit t)
          (buffer (org-switch-to-buffer-other-window "*Org Select*"))
          (prompt (or prompt "Select: "))
          case-fold-search
          current)
      (unwind-protect
          (catch 'exit
            (while t
              (setq-local evil-normal-state-cursor (list nil))
              (erase-buffer)
              (insert title "\n\n")
              (let ((des-keys nil)
                    (allowed-keys '("\C-g"))
                    (tab-alternatives '("\s" "\t" "\r"))
                    (cursor-type nil))
                ;; Populate allowed keys and descriptions keys
                ;; available with CURRENT selector.
                (let ((re (format "\\`%s\\(.\\)\\'"
                                  (if current (regexp-quote current) "")))
                      (prefix (if current (concat current " ") "")))
                  (dolist (entry table)
                    (pcase entry
                      ;; Description.
                      (`(,(and key (pred (string-match re))) ,desc)
                       (let ((k (match-string 1 key)))
                         (push k des-keys)
                         ;; Keys ending in tab, space or RET are equivalent.
                         (if (member k tab-alternatives)
                             (push "\t" allowed-keys)
                           (push k allowed-keys))
                         (insert (propertize prefix 'face 'font-lock-comment-face) (propertize k 'face 'bold) (propertize "›" 'face 'font-lock-comment-face) "  " desc "…" "\n")))
                      ;; Usable entry.
                      (`(,(and key (pred (string-match re))) ,desc . ,_)
                       (let ((k (match-string 1 key)))
                         (insert (propertize prefix 'face 'font-lock-comment-face) (propertize k 'face 'bold) "   " desc "\n")
                         (push k allowed-keys)))
                      (_ nil))))
                ;; Insert special entries, if any.
                (when specials
                  (insert "─────────────────────────\n")
                  (pcase-dolist (`(,key ,description) specials)
                    (insert (format "%s   %s\n" (propertize key 'face '(bold all-the-icons-red)) description))
                    (push key allowed-keys)))
                ;; Display UI and let user select an entry or
                ;; a sub-level prefix.
                (goto-char (point-min))
                (unless (pos-visible-in-window-p (point-max))
                  (org-fit-window-to-buffer))
                (let ((pressed (org--mks-read-key allowed-keys prompt nil)))
                  (setq current (concat current pressed))
                  (cond
                   ((equal pressed "\C-g") (user-error "Abort"))
                   ((equal pressed "ESC") (user-error "Abort"))
                   ;; Selection is a prefix: open a new menu.
                   ((member pressed des-keys))
                   ;; Selection matches an association: return it.
                   ((let ((entry (assoc current table)))
                      (and entry (throw 'exit entry))))
                   ;; Selection matches a special entry: return the
                   ;; selection prefix.
                   ((assoc current specials) (throw 'exit current))
                   (t (error "No entry available")))))))
        (when buffer (kill-buffer buffer))))))
(advice-add 'org-mks :override #'org-mks-pretty)

(setf (alist-get 'height +org-capture-frame-parameters) 15)
(setq +org-capture-fn
      (lambda ()
        (interactive)
        (set-window-parameter nil 'mode-line-format 'none)
        (org-capture)))

(defun +doct-icon-declaration-to-icon (declaration)
  "Convert :icon declaration to icon"
  (let ((name (pop declaration))
        (set  (intern (concat "all-the-icons-" (plist-get declaration :set))))
        (face (intern (concat "all-the-icons-" (plist-get declaration :color))))
        (v-adjust (or (plist-get declaration :v-adjust) 0.01)))
    (apply set `(,name :face ,face :v-adjust ,v-adjust))))

(defun +doct-iconify-capture-templates (groups)
  "Add declaration's :icon to each template group in GROUPS."
  (let ((templates (doct-flatten-lists-in groups)))
    (setq doct-templates (mapcar (lambda (template)
                                   (when-let* ((props (nthcdr (if (= (length template) 4) 2 5) template))
                                               (spec (plist-get (plist-get props :doct) :icon)))
                                     (setf (nth 1 template) (concat (+doct-icon-declaration-to-icon spec)
                                                                    "\t"
                                                                    (nth 1 template))))
                                   template)
                                 templates))))

(setq doct-after-conversion-functions '(+doct-iconify-capture-templates))

(setq org-capture-templates
      (doct `(("Home" :keys "h"
               :icon ("home" :set "octicon" :color "cyan")
               :file "Home.org"
               :prepend t
               :headline "Inbox"
               :template ("* TODO %?"
                          "%i %a"))
              ("Work" :keys "w"
               :icon ("business" :set "material" :color "yellow")
               :file "Work.org"
               :prepend t
               :headline "Inbox"
               :template ("* TODO %?"
                          "SCHEDULED: %^{Schedule:}t"
                          "DEADLINE: %^{Deadline:}t"
                          "%i %a"))
              ("Note" :keys "n"
               :icon ("sticky-note" :set "faicon" :color "yellow")
               :file "Notes.org"
               :template ("* *?"
                          "%i %a"))
              ("Project" :keys "p"
               :icon ("repo" :set "octicon" :color "silver")
               :prepend t
               :type entry
               :headline "Inbox"
               :template ("* %{keyword} %?"
                          "%i"
                          "%a")
               :file ""
               :custom (:keyword "")
               :children (("Task" :keys "t"
                           :icon ("checklist" :set "octicon" :color "green")
                           :keyword "TODO"
                           :file +org-capture-project-todo-file)
                          ("Note" :keys "n"
                           :icon ("sticky-note" :set "faicon" :color "yellow")
                           :keyword "%U"
                           :file +org-capture-project-notes-file))))))

(after! org
  (setq org-ellipsis " ▾ "
        org-hide-leading-stars t
        org-priority-highest ?A
        org-priority-lowest ?E
        org-priority-faces
        '((?A . 'all-the-icons-red)
          (?B . 'all-the-icons-orange)
          (?C . 'all-the-icons-yellow)
          (?D . 'all-the-icons-green)
          (?E . 'all-the-icons-blue))))

(appendq! +ligatures-extra-symbols
          `(:checkbox      "☐"
            :pending       "◼"
            :checkedbox    "☑"
            :list_property "∷"
            :em_dash       "—"
            :ellipses      "…"
            :arrow_right   "→"
            :arrow_left    "←"
            :property      "☸"
            :options       "⌥"
            :startup       "⏻"
            :html_head     "🅷"
            :html          "🅗"
            :latex_class   "🄻"
            :latex_header  "🅻"
            :beamer_header "🅑"
            :latex         "🅛"
            :attr_latex    "🄛"
            :attr_html     "🄗"
            :attr_org      "⒪"
            :begin_quote   "❝"
            :end_quote     "❞"
            :caption       "☰"
            :header        "›"
            :begin_export  "⏩"
            :end_export    "⏪"
            :properties    "⚙"
            :end           "∎"
            :priority_a   ,(propertize "⚑" 'face 'all-the-icons-red)
            :priority_b   ,(propertize "⬆" 'face 'all-the-icons-orange)
            :priority_c   ,(propertize "■" 'face 'all-the-icons-yellow)
            :priority_d   ,(propertize "⬇" 'face 'all-the-icons-green)
            :priority_e   ,(propertize "❓" 'face 'all-the-icons-blue)))
(set-ligatures! 'org-mode
  :merge t
  :checkbox      "[ ]"
  :pending       "[-]"
  :checkedbox    "[X]"
  :list_property "::"
  :em_dash       "---"
  :ellipsis      "..."
  :arrow_right   "->"
  :arrow_left    "<-"
  :title         "#+title:"
  :subtitle      "#+subtitle:"
  :author        "#+author:"
  :date          "#+date:"
  :property      "#+property:"
  :options       "#+options:"
  :startup       "#+startup:"
  :macro         "#+macro:"
  :html_head     "#+html_head:"
  :html          "#+html:"
  :latex_class   "#+latex_class:"
  :latex_header  "#+latex_header:"
  :beamer_header "#+beamer_header:"
  :latex         "#+latex:"
  :attr_latex    "#+attr_latex:"
  :attr_html     "#+attr_html:"
  :attr_org      "#+attr_org:"
  :begin_quote   "#+begin_quote"
  :end_quote     "#+end_quote"
  :caption       "#+caption:"
  :header        "#+header:"
  :begin_export  "#+begin_export"
  :end_export    "#+end_export"
  :results       "#+RESULTS:"
  :property      ":PROPERTIES:"
  :end           ":END:"
  :priority_a    "[#A]"
  :priority_b    "[#B]"
  :priority_c    "[#C]"
  :priority_d    "[#D]"
  :priority_e    "[#E]")
(plist-put +ligatures-extra-symbols :name "⁍")

(defun org-syntax-convert-keyword-case-to-lower ()
  "Convert all #+KEYWORDS to #+keywords."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((count 0)
          (case-fold-search nil))
      (while (re-search-forward "^[ \t]*#\\+[A-Z_]+" nil t)
        (unless (s-matches-p "RESULTS" (match-string 0))
          (replace-match (downcase (match-string 0)) t)
          (setq count (1+ count))))
      (message "Replaced %d occurances" count))))

(add-hook 'org-mode-hook #'+org-pretty-mode)

(after! org
  (setq org-pretty-entities-include-sub-superscripts nil))

(use-package! org-pretty-table
  :after org
  :hook (org-mode . org-pretty-table-mode))

(after! org
  (setq org-agenda-deadline-faces
        '((1.0 . error)
          (1.0 . org-warning)
          (0.5 . org-upcoming-deadline)
          (0.0 . org-upcoming-distant-deadline))))

(after! org
  (setq org-fontify-quote-and-verse-blocks t))

(use-package! org-appear
  :after org
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autoemphasis t
        org-appear-autolinks t
        org-appear-autosubmarkers t))

(after! org-plot
  (defun org-plot/generate-theme (_type)
    "Use the current Doom theme colours to generate a GnuPlot preamble."
    (format "
fgt = \"textcolor rgb '%s'\" # foreground text
fgat = \"textcolor rgb '%s'\" # foreground alt text
fgl = \"linecolor rgb '%s'\" # foreground line
fgal = \"linecolor rgb '%s'\" # foreground alt line

# foreground colors
set border lc rgb '%s'
# change text colors of  tics
set xtics @fgt
set ytics @fgt
# change text colors of labels
set title @fgt
set xlabel @fgt
set ylabel @fgt
# change a text color of key
set key @fgt

# line styles
set linetype 1 lw 2 lc rgb '%s' # red
set linetype 2 lw 2 lc rgb '%s' # blue
set linetype 3 lw 2 lc rgb '%s' # green
set linetype 4 lw 2 lc rgb '%s' # magenta
set linetype 5 lw 2 lc rgb '%s' # orange
set linetype 6 lw 2 lc rgb '%s' # yellow
set linetype 7 lw 2 lc rgb '%s' # teal
set linetype 8 lw 2 lc rgb '%s' # violet

# border styles
set tics out nomirror
set border 3

# palette
set palette maxcolors 8
set palette defined ( 0 '%s',\
1 '%s',\
2 '%s',\
3 '%s',\
4 '%s',\
5 '%s',\
6 '%s',\
7 '%s' )
"
            (doom-color 'fg)
            (doom-color 'fg-alt)
            (doom-color 'fg)
            (doom-color 'fg-alt)
            (doom-color 'fg)
            ;; colours
            (doom-color 'red)
            (doom-color 'blue)
            (doom-color 'green)
            (doom-color 'magenta)
            (doom-color 'orange)
            (doom-color 'yellow)
            (doom-color 'teal)
            (doom-color 'violet)
            ;; duplicated
            (doom-color 'red)
            (doom-color 'blue)
            (doom-color 'green)
            (doom-color 'magenta)
            (doom-color 'orange)
            (doom-color 'yellow)
            (doom-color 'teal)
            (doom-color 'violet)))
  (defun org-plot/gnuplot-term-properties (_type)
    (format "background rgb '%s' size 1050,650"
            (doom-color 'bg)))
  (setq org-plot/gnuplot-script-preamble #'org-plot/generate-theme)
  (setq org-plot/gnuplot-term-extra #'org-plot/gnuplot-term-properties))

(use-package! xkcd
  :commands (xkcd-get-json
             xkcd-download xkcd-get
             ;; now for funcs from my extension of this pkg
             +xkcd-find-and-copy +xkcd-find-and-view
             +xkcd-fetch-info +xkcd-select)
  :config
  (setq xkcd-cache-dir (expand-file-name "xkcd/" doom-cache-dir)
        xkcd-cache-latest (concat xkcd-cache-dir "latest"))
  (unless (file-exists-p xkcd-cache-dir)
    (make-directory xkcd-cache-dir))
  (after! evil-snipe
    (add-to-list 'evil-snipe-disabled-modes 'xkcd-mode))
  :general (:states 'normal
            :keymaps 'xkcd-mode-map
            "<right>" #'xkcd-next
            "n"       #'xkcd-next ; evil-ish
            "<left>"  #'xkcd-prev
            "N"       #'xkcd-prev ; evil-ish
            "r"       #'xkcd-rand
            "a"       #'xkcd-rand ; because image-rotate can interfere
            "t"       #'xkcd-alt-text
            "q"       #'xkcd-kill-buffer
            "o"       #'xkcd-open-browser
            "e"       #'xkcd-open-explanation-browser
            ;; extras
            "s"       #'+xkcd-find-and-view
            "/"       #'+xkcd-find-and-view
            "y"       #'+xkcd-copy))

(after! xkcd
  (require 'emacsql-sqlite)

  (defun +xkcd-select ()
    "Prompt the user for an xkcd using `completing-read' and `+xkcd-select-format'. Return the xkcd number or nil"
    (let* (prompt-lines
           (-dummy (maphash (lambda (key xkcd-info)
                              (push (+xkcd-select-format xkcd-info) prompt-lines))
                            +xkcd-stored-info))
           (num (completing-read (format "xkcd (%s): " xkcd-latest) prompt-lines)))
      (if (equal "" num) xkcd-latest
        (string-to-number (replace-regexp-in-string "\\([0-9]+\\).*" "\\1" num)))))

  (defun +xkcd-select-format (xkcd-info)
    "Creates each completing-read line from an xkcd info plist. Must start with the xkcd number"
    (format "%-4s  %-30s %s"
            (propertize (number-to-string (plist-get xkcd-info :num))
                        'face 'counsel-key-binding)
            (plist-get xkcd-info :title)
            (propertize (plist-get xkcd-info :alt)
                        'face '(variable-pitch font-lock-comment-face))))

  (defun +xkcd-fetch-info (&optional num)
    "Fetch the parsed json info for comic NUM. Fetches latest when omitted or 0"
    (require 'xkcd)
    (when (or (not num) (= num 0))
      (+xkcd-check-latest)
      (setq num xkcd-latest))
    (let ((res (or (gethash num +xkcd-stored-info)
                   (puthash num (+xkcd-db-read num) +xkcd-stored-info))))
      (unless res
        (+xkcd-db-write
         (let* ((url (format "https://xkcd.com/%d/info.0.json" num))
                (json-assoc
                 (if (gethash num +xkcd-stored-info)
                     (gethash num +xkcd-stored-info)
                   (json-read-from-string (xkcd-get-json url num)))))
           json-assoc))
        (setq res (+xkcd-db-read num)))
      res))

  ;; since we've done this, we may as well go one little step further
  (defun +xkcd-find-and-copy ()
    "Prompt for an xkcd using `+xkcd-select' and copy url to clipboard"
    (interactive)
    (+xkcd-copy (+xkcd-select)))

  (defun +xkcd-copy (&optional num)
    "Copy a url to xkcd NUM to the clipboard"
    (interactive "i")
    (let ((num (or num xkcd-cur)))
      (gui-select-text (format "https://xkcd.com/%d" num))
      (message "xkcd.com/%d copied to clipboard" num)))

  (defun +xkcd-find-and-view ()
    "Prompt for an xkcd using `+xkcd-select' and view it"
    (interactive)
    (xkcd-get (+xkcd-select))
    (switch-to-buffer "*xkcd*"))

  (defvar +xkcd-latest-max-age (* 60 60) ; 1 hour
    "Time after which xkcd-latest should be refreshed, in seconds")

  ;; initialise `xkcd-latest' and `+xkcd-stored-info' with latest xkcd
  (add-transient-hook! '+xkcd-select
    (require 'xkcd)
    (+xkcd-fetch-info xkcd-latest)
    (setq +xkcd-stored-info (+xkcd-db-read-all)))

  (add-transient-hook! '+xkcd-fetch-info
    (xkcd-update-latest))

  (defun +xkcd-check-latest ()
    "Use value in `xkcd-cache-latest' as long as it isn't older thabn `+xkcd-latest-max-age'"
    (unless (and (file-exists-p xkcd-cache-latest)
                 (< (- (time-to-seconds (current-time))
                       (time-to-seconds (file-attribute-modification-time (file-attributes xkcd-cache-latest))))
                    +xkcd-latest-max-age))
      (let* ((out (xkcd-get-json "http://xkcd.com/info.0.json" 0))
             (json-assoc (json-read-from-string out))
             (latest (cdr (assoc 'num json-assoc))))
        (when (/= xkcd-latest latest)
          (+xkcd-db-write json-assoc)
          (with-current-buffer (find-file xkcd-cache-latest)
            (setq xkcd-latest latest)
            (erase-buffer)
            (insert (number-to-string latest))
            (save-buffer)
            (kill-buffer (current-buffer)))))
      (shell-command (format "touch %s" xkcd-cache-latest))))

  (defvar +xkcd-stored-info (make-hash-table :test 'eql)
    "Basic info on downloaded xkcds, in the form of a hashtable")

  (defadvice! xkcd-get-json--and-cache (url &optional num)
    "Fetch the Json coming from URL.
If the file NUM.json exists, use it instead.
If NUM is 0, always download from URL.
The return value is a string."
    :override #'xkcd-get-json
    (let* ((file (format "%s%d.json" xkcd-cache-dir num))
           (cached (and (file-exists-p file) (not (eq num 0))))
           (out (with-current-buffer (if cached
                                         (find-file file)
                                       (url-retrieve-synchronously url))
                  (goto-char (point-min))
                  (unless cached (re-search-forward "^$"))
                  (prog1
                      (buffer-substring-no-properties (point) (point-max))
                    (kill-buffer (current-buffer))))))
      (unless (or cached (eq num 0))
        (xkcd-cache-json num out))
      out))

  (defadvice! +xkcd-get (num)
    "Get the xkcd number NUM."
    :override 'xkcd-get
    (interactive "nEnter comic number: ")
    (xkcd-update-latest)
    (get-buffer-create "*xkcd*")
    (switch-to-buffer "*xkcd*")
    (xkcd-mode)
    (let (buffer-read-only)
      (erase-buffer)
      (setq xkcd-cur num)
      (let* ((xkcd-data (+xkcd-fetch-info num))
             (num (plist-get xkcd-data :num))
             (img (plist-get xkcd-data :img))
             (safe-title (plist-get xkcd-data :safe-title))
             (alt (plist-get xkcd-data :alt))
             title file)
        (message "Getting comic...")
        (setq file (xkcd-download img num))
        (setq title (format "%d: %s" num safe-title))
        (insert (propertize title
                            'face 'outline-1))
        (center-line)
        (insert "\n")
        (xkcd-insert-image file num)
        (if (eq xkcd-cur 0)
            (setq xkcd-cur num))
        (setq xkcd-alt alt)
        (message "%s" title))))

  (defconst +xkcd-db--sqlite-available-p
    (with-demoted-errors "+org-xkcd initialization: %S"
      (emacsql-sqlite-ensure-binary)
      t))

  (defvar +xkcd-db--connection (make-hash-table :test #'equal)
    "Database connection to +org-xkcd database.")

  (defun +xkcd-db--get ()
    "Return the sqlite db file."
    (expand-file-name "xkcd.db" xkcd-cache-dir))

  (defun +xkcd-db--get-connection ()
    "Return the database connection, if any."
    (gethash (file-truename xkcd-cache-dir)
             +xkcd-db--connection))

  (defconst +xkcd-db--table-schema
    '((xkcds
       [(num integer :unique :primary-key)
        (year        :not-null)
        (month       :not-null)
        (link        :not-null)
        (news        :not-null)
        (safe_title  :not-null)
        (title       :not-null)
        (transcript  :not-null)
        (alt         :not-null)
        (img         :not-null)])))

  (defun +xkcd-db--init (db)
    "Initialize database DB with the correct schema and user version."
    (emacsql-with-transaction db
      (pcase-dolist (`(,table . ,schema) +xkcd-db--table-schema)
        (emacsql db [:create-table $i1 $S2] table schema))))

  (defun +xkcd-db ()
    "Entrypoint to the +org-xkcd sqlite database.
Initializes and stores the database, and the database connection.
Performs a database upgrade when required."
    (unless (and (+xkcd-db--get-connection)
                 (emacsql-live-p (+xkcd-db--get-connection)))
      (let* ((db-file (+xkcd-db--get))
             (init-db (not (file-exists-p db-file))))
        (make-directory (file-name-directory db-file) t)
        (let ((conn (emacsql-sqlite db-file)))
          (set-process-query-on-exit-flag (emacsql-process conn) nil)
          (puthash (file-truename xkcd-cache-dir)
                   conn
                   +xkcd-db--connection)
          (when init-db
            (+xkcd-db--init conn)))))
    (+xkcd-db--get-connection))

  (defun +xkcd-db-query (sql &rest args)
    "Run SQL query on +org-xkcd database with ARGS.
SQL can be either the emacsql vector representation, or a string."
    (if  (stringp sql)
        (emacsql (+xkcd-db) (apply #'format sql args))
      (apply #'emacsql (+xkcd-db) sql args)))

  (defun +xkcd-db-read (num)
    (when-let ((res
                (car (+xkcd-db-query [:select * :from xkcds
                                      :where (= num $s1)]
                                     num
                                     :limit 1))))
      (+xkcd-db-list-to-plist res)))

  (defun +xkcd-db-read-all ()
    (let ((xkcd-table (make-hash-table :test 'eql :size 4000)))
      (mapcar (lambda (xkcd-info-list)
                (puthash (car xkcd-info-list) (+xkcd-db-list-to-plist xkcd-info-list) xkcd-table))
              (+xkcd-db-query [:select * :from xkcds]))
      xkcd-table))

  (defun +xkcd-db-list-to-plist (xkcd-datalist)
    `(:num ,(nth 0 xkcd-datalist)
      :year ,(nth 1 xkcd-datalist)
      :month ,(nth 2 xkcd-datalist)
      :link ,(nth 3 xkcd-datalist)
      :news ,(nth 4 xkcd-datalist)
      :safe-title ,(nth 5 xkcd-datalist)
      :title ,(nth 6 xkcd-datalist)
      :transcript ,(nth 7 xkcd-datalist)
      :alt ,(nth 8 xkcd-datalist)
      :img ,(nth 9 xkcd-datalist)))

  (defun +xkcd-db-write (data)
    (+xkcd-db-query [:insert-into xkcds
                     :values $v1]
                    (list (vector
                           (cdr (assoc 'num        data))
                           (cdr (assoc 'year       data))
                           (cdr (assoc 'month      data))
                           (cdr (assoc 'link       data))
                           (cdr (assoc 'news       data))
                           (cdr (assoc 'safe_title data))
                           (cdr (assoc 'title      data))
                           (cdr (assoc 'transcript data))
                           (cdr (assoc 'alt        data))
                           (cdr (assoc 'img        data)))))))

(after! org
  (org-link-set-parameters "xkcd"
                           :image-data-fun #'+org-xkcd-image-fn
                           :follow #'+org-xkcd-open-fn
                           :export #'+org-xkcd-export
                           :complete #'+org-xkcd-complete)

  (defun +org-xkcd-open-fn (link)
    (+org-xkcd-image-fn nil link nil))

  (defun +org-xkcd-image-fn (protocol link description)
    "Get image data for xkcd num LINK"
    (let* ((xkcd-info (+xkcd-fetch-info (string-to-number link)))
           (img (plist-get xkcd-info :img))
           (alt (plist-get xkcd-info :alt)))
      (message alt)
      (+org-image-file-data-fn protocol (xkcd-download img (string-to-number link)) description)))

  (defun +org-xkcd-export (num desc backend _com)
    "Convert xkcd to html/LaTeX form"
    (let* ((xkcd-info (+xkcd-fetch-info (string-to-number num)))
           (img (plist-get xkcd-info :img))
           (alt (plist-get xkcd-info :alt))
           (title (plist-get xkcd-info :title))
           (file (xkcd-download img (string-to-number num))))
      (cond ((org-export-derived-backend-p backend 'html)
             (format "<img class='invertible' src='%s' title=\"%s\" alt='%s'>" img (subst-char-in-string ?\" ?“ alt) title))
            ((org-export-derived-backend-p backend 'latex)
             (format "\\begin{figure}[!htb]
    \\centering
    \\includegraphics[scale=0.4]{%s}%s
  \\end{figure}" file (if (equal desc (format "xkcd:%s" num)) ""
                        (format "\n  \\caption*{\\label{xkcd:%s} %s}"
                                num
                                (or desc
                                    (format "\\textbf{%s} %s" title alt))))))
            (t (format "https://xkcd.com/%s" num)))))

  (defun +org-xkcd-complete (&optional arg)
    "Complete xkcd using `+xkcd-stored-info'"
    (format "xkcd:%d" (+xkcd-select))))

(map! :map org-mode-map
      :localleader
      :desc "View exported file" "v" #'org-view-output-file)

(defun org-view-output-file (&optional org-file-path)
  "Visit buffer open on the first output file (if any) found, using `org-view-output-file-extensions'"
  (interactive)
  (let* ((org-file-path (or org-file-path (buffer-file-name) ""))
         (dir (file-name-directory org-file-path))
         (basename (file-name-base org-file-path))
         (output-file nil))
    (dolist (ext org-view-output-file-extensions)
      (unless output-file
        (when (file-exists-p
               (concat dir basename "." ext))
          (setq output-file (concat dir basename "." ext)))))
    (if output-file
        (if (member (file-name-extension output-file) org-view-external-file-extensions)
            (browse-url-xdg-open output-file)
          (pop-to-bufferpop-to-buffer (or (find-buffer-visiting output-file)
                                          (find-file-noselect output-file))))
      (message "No exported file found"))))

(defvar org-view-output-file-extensions '("pdf" "md" "rst" "txt" "tex" "html")
  "Search for output files with these extensions, in order, viewing the first that matches")
(defvar org-view-external-file-extensions '("html")
  "File formats that should be opened externally.")

(use-package! lexic
  :commands lexic-search lexic-list-dictionary
  :config
  (map! :map lexic-mode-map
        :n "q" #'lexic-return-from-lexic
        :nv "RET" #'lexic-search-word-at-point
        :n "a" #'outline-show-all
        :n "h" (cmd! (outline-hide-sublevels 3))
        :n "o" #'lexic-toggle-entry
        :n "n" #'lexic-next-entry
        :n "N" (cmd! (lexic-next-entry t))
        :n "p" #'lexic-previous-entry
        :n "P" (cmd! (lexic-previous-entry t))
        :n "E" (cmd! (lexic-return-from-lexic) ; expand
                     (switch-to-buffer (lexic-get-buffer)))
        :n "M" (cmd! (lexic-return-from-lexic) ; minimise
                     (lexic-goto-lexic))
        :n "C-p" #'lexic-search-history-backwards
        :n "C-n" #'lexic-search-history-forwards
        :n "/" (cmd! (call-interactively #'lexic-search))))

(defadvice! +lookup/dictionary-definition-lexic (identifier &optional arg)
  "Look up the definition of the word at point (or selection) using `lexic-search'."
  :override #'+lookup/dictionary-definition
  (interactive
   (list (or (doom-thing-at-point-or-region 'word)
             (read-string "Look up in dictionary: "))
         current-prefix-arg))
  (lexic-search identifier nil nil t))

(use-package! notebook
  :commands notebook-mode)

(after! org
  (add-hook 'org-mode-hook 'turn-on-org-cdlatex))

(defadvice! org-edit-latex-emv-after-insert ()
  :after #'org-cdlatex-environment-indent
  (org-edit-latex-environment))

(use-package pdf-view
  :hook (pdf-tools-enabled . pdf-view-themed-minor-mode)
  :config
  (setq pdf-view-resize-factor 1.1)
  (setq-default pdf-view-display-size 'fit-page))

(defvar org-latex-caption-preamble "
\\usepackage{subcaption}
\\usepackage[hypcap=true]{caption}
\\setkomafont{caption}{\\sffamily\\small}
\\setkomafont{captionlabel}{\\upshape\\bfseries}
\\captionsetup{justification=raggedright,singlelinecheck=true}
\\usepackage{capt-of} % required by Org
"
  "Preamble that improves captions.")

(defvar org-latex-checkbox-preamble "
\\newcommand{\\checkboxUnchecked}{$\\square$}
\\newcommand{\\checkboxTransitive}{\\rlap{\\raisebox{-0.1ex}{\\hspace{0.35ex}\\Large\\textbf -}}$\\square$}
\\newcommand{\\checkboxChecked}{\\rlap{\\raisebox{0.2ex}{\\hspace{0.35ex}\\scriptsize \\ding{52}}}$\\square$}
"
  "Preamble that improves checkboxes.")

(defvar org-latex-box-preamble "
% args = #1 Name, #2 Colour, #3 Ding, #4 Label
\\newcommand{\\defsimplebox}[4]{%
  \\definecolor{#1}{HTML}{#2}
  \\newenvironment{#1}[1][]
  {%
    \\par\\vspace{-0.7\\baselineskip}%
    \\textcolor{#1}{#3} \\textcolor{#1}{\\textbf{\\def\\temp{##1}\\ifx\\temp\\empty#4\\else##1\\fi}}%
    \\vspace{-0.8\\baselineskip}
    \\begin{addmargin}[1em]{1em}
  }{%
    \\end{addmargin}
    \\vspace{-0.5\\baselineskip}
  }%
}
"
  "Preamble that provides a macro for custom boxes.")

(defadvice! +org-latex-link (orig-fn link desc info)
  "Acts as `org-latex-link', but supports remote images."
  :around #'org-latex-link
  (setq o-link link
        o-desc desc
        o-info info)
  (if (and (member (plist-get (cadr link) :type) '("http" "https"))
           (member (file-name-extension (plist-get (cadr link) :path))
                   '("png" "jpg" "jpeg" "pdf" "svg")))
      (org-latex-link--remote link desc info)
    (funcall orig-fn link desc info)))

(defun org-latex-link--remote (link _desc info)
  (let* ((url (plist-get (cadr link) :raw-link))
         (ext (file-name-extension url))
         (target (format "%s%s.%s"
                         (temporary-file-directory)
                         (replace-regexp-in-string "[./]" "-"
                                                   (file-name-sans-extension (substring (plist-get (cadr link) :path) 2)))
                         ext)))
    (unless (file-exists-p target)
      (url-copy-file url target))
    (setcdr link (--> (cadr link)
                      (plist-put it :type "file")
                      (plist-put it :path target)
                      (plist-put it :raw-link (concat "file:" target))
                      (list it)))
    (concat "% fetched from " url "\n"
            (org-latex--inline-image link info))))

(defvar org-latex-italic-quotes t
  "Make \"quote\" environments italic.")
(defvar org-latex-par-sep t
  "Vertically seperate paragraphs, and remove indentation.")

(defvar org-latex-conditional-features
  '(("\\[\\[\\(?:file\\|https?\\):\\(?:[^]]\\|\\\\\\]\\)+?\\.\\(?:eps\\|pdf\\|png\\|jpeg\\|jpg\\|jbig2\\)\\]\\]" . image)
    ("\\[\\[\\(?:file\\|https?\\):\\(?:[^]]+?\\|\\\\\\]\\)\\.svg\\]\\]\\|\\\\includesvg" . svg)
    ("^[ \t]*|" . table)
    ("cref:\\|\\cref{\\|\\[\\[[^\\]]+\\]\\]" . cleveref)
    ("[;\\\\]?\\b[A-Z][A-Z]+s?[^A-Za-z]" . acronym)
    ("\\+[^ ].*[^ ]\\+\\|_[^ ].*[^ ]_\\|\\\\uu?line\\|\\\\uwave\\|\\\\sout\\|\\\\xout\\|\\\\dashuline\\|\\dotuline\\|\\markoverwith" . underline)
    (":float wrap" . float-wrap)
    (":float sideways" . rotate)
    ("^[ \t]*#\\+caption:\\|\\\\caption" . caption)
    ("\\[\\[xkcd:" . (image caption))
    ((and org-latex-italic-quotes "^[ \t]*#\\+begin_quote\\|\\\\begin{quote}") . italic-quotes)
    (org-latex-par-sep . par-sep)
    ("^[ \t]*\\(?:[-+*]\\|[0-9]+[.)]\\|[A-Za-z]+[.)]\\) \\[[ -X]\\]" . checkbox)
    ("^[ \t]*#\\+begin_warning\\|\\\\begin{warning}" . box-warning)
    ("^[ \t]*#\\+begin_info\\|\\\\begin{info}"       . box-info)
    ("^[ \t]*#\\+begin_success\\|\\\\begin{success}" . box-success)
    ("^[ \t]*#\\+begin_error\\|\\\\begin{error}"     . box-error))
  "Org feature tests and associated LaTeX feature flags.

Alist where the car is a test for the presense of the feature,
and the cdr is either a single feature symbol or list of feature symbols.

When a string, it is used as a regex search in the buffer.
The feature is registered as present when there is a match.

The car can also be a
- symbol, the value of which is fetched
- function, which is called with info as an argument
- list, which is `eval'uated

If the symbol, function, or list produces a string: that is used as a regex
search in the buffer. Otherwise any non-nil return value will indicate the
existance of the feature.")

(defvar org-latex-feature-implementations
  '((image         :snippet "\\usepackage{graphicx}" :order 2)
    (svg           :snippet "\\usepackage{svg}" :order 2)
    (table         :snippet "\\usepackage{longtable}\n\\usepackage{booktabs}" :order 2)
    (cleveref      :snippet "\\usepackage[capitalize]{cleveref}" :order 1)
    (underline     :snippet "\\usepackage[normalem]{ulem}" :order 0.5)
    (float-wrap    :snippet "\\usepackage{wrapfig}" :order 2)
    (rotate        :snippet "\\usepackage{rotating}" :order 2)
    (caption       :snippet org-latex-caption-preamble :order 2.1)
    (acronym       :snippet "\\newcommand{\\acr}[1]{\\protect\\textls*[110]{\\scshape #1}}\n\\newcommand{\\acrs}{\\protect\\scalebox{.91}[.84]{\\hspace{0.15ex}s}}" :order 0.4)
    (italic-quotes :snippet "\\renewcommand{\\quote}{\\list{}{\\rightmargin\\leftmargin}\\item\\relax\\em}\n" :order 0.5)
    (par-sep       :snippet "\\setlength{\\parskip}{\\baselineskip}\n\\setlength{\\parindent}{0pt}\n" :order 0.5)
    (.pifont       :snippet "\\usepackage{pifont}")
    (checkbox      :requires .pifont :order 3
                   :snippet (concat (unless (memq 'maths features)
                                      "\\usepackage{amssymb} % provides \\square")
                                    org-latex-checkbox-preamble))
    (.fancy-box    :requires .pifont    :snippet org-latex-box-preamble :order 3.9)
    (box-warning   :requires .fancy-box :snippet "\\defsimplebox{warning}{e66100}{\\ding{68}}{Warning}" :order 4)
    (box-info      :requires .fancy-box :snippet "\\defsimplebox{info}{3584e4}{\\ding{68}}{Information}" :order 4)
    (box-success   :requires .fancy-box :snippet "\\defsimplebox{success}{26a269}{\\ding{68}}{\\vspace{-\\baselineskip}}" :order 4)
    (box-error     :requires .fancy-box :snippet "\\defsimplebox{error}{c01c28}{\\ding{68}}{Important}" :order 4))
  "LaTeX features and details required to implement them.

List where the car is the feature symbol, and the rest forms a plist with the
following keys:
- :snippet, which may be either
  - a string which should be included in the preamble
  - a symbol, the value of which is included in the preamble
  - a function, which is evaluated with the list of feature flags as its
    single argument. The result of which is included in the preamble
  - a list, which is passed to `eval', with a list of feature flags available
    as \"features\"

- :requires, a feature or list of features that must be available
- :when, a feature or list of features that when all available should cause this
    to be automatically enabled.
- :prevents, a feature or list of features that should be masked
- :order, for when ordering is important. Lower values appear first.
    The default is 0.

Features that start with ! will be eagerly loaded, i.e. without being detected.")

(defun org-latex-detect-features (&optional buffer info)
  "List features from `org-latex-conditional-features' detected in BUFFER."
  (let ((case-fold-search nil))
    (with-current-buffer (or buffer (current-buffer))
      (delete-dups
       (mapcan (lambda (construct-feature)
                 (when (let ((out (pcase (car construct-feature)
                                    ((pred stringp) (car construct-feature))
                                    ((pred functionp) (funcall (car construct-feature) info))
                                    ((pred listp) (eval (car construct-feature)))
                                    ((pred symbolp) (symbol-value (car construct-feature)))
                                    (_ (user-error "org-latex-conditional-features key %s unable to be used" (car construct-feature))))))
                         (if (stringp out)
                             (save-excursion
                               (goto-char (point-min))
                               (re-search-forward out nil t))
                           out))
                   (if (listp (cdr construct-feature)) (cdr construct-feature) (list (cdr construct-feature)))))
               org-latex-conditional-features)))))

(defun org-latex-expand-features (features)
  "For each feature in FEATURES process :requires, :when, and :prevents keywords and sort according to :order."
  (dolist (feature features)
    (unless (assoc feature org-latex-feature-implementations)
      (error "Feature %s not provided in org-latex-feature-implementations" feature)))
  (setq current features)
  (while current
    (when-let ((requirements (plist-get (cdr (assq (car current) org-latex-feature-implementations)) :requires)))
      (setcdr current (if (listp requirements)
                          (append requirements (cdr current))
                        (cons requirements (cdr current)))))
    (setq current (cdr current)))
  (dolist (potential-feature
           (append features (delq nil (mapcar (lambda (feat)
                                                (when (plist-get (cdr feat) :eager)
                                                  (car feat)))
                                              org-latex-feature-implementations))))
    (when-let ((prerequisites (plist-get (cdr (assoc potential-feature org-latex-feature-implementations)) :when)))
      (setf features (if (if (listp prerequisites)
                             (cl-every (lambda (preq) (memq preq features)) prerequisites)
                           (memq prerequisites features))
                         (append (list potential-feature) features)
                       (delq potential-feature features)))))
  (dolist (feature features)
    (when-let ((prevents (plist-get (cdr (assoc feature org-latex-feature-implementations)) :prevents)))
      (setf features (cl-set-difference features (if (listp prevents) prevents (list prevents))))))
  (sort (delete-dups features)
        (lambda (feat1 feat2)
          (if (< (or (plist-get (cdr (assoc feat1 org-latex-feature-implementations)) :order) 1)
                 (or (plist-get (cdr (assoc feat2 org-latex-feature-implementations)) :order) 1))
              t nil))))

(defun org-latex-generate-features-preamble (features)
  "Generate the LaTeX preamble content required to provide FEATURES.
This is done according to `org-latex-feature-implementations'"
  (let ((expanded-features (org-latex-expand-features features)))
    (concat
     (format "\n%% features: %s\n" expanded-features)
     (mapconcat (lambda (feature)
                  (when-let ((snippet (plist-get (cdr (assoc feature org-latex-feature-implementations)) :snippet)))
                    (concat
                     (pcase snippet
                       ((pred stringp) snippet)
                       ((pred functionp) (funcall snippet features))
                       ((pred listp) (eval `(let ((features ',features)) (,@snippet))))
                       ((pred symbolp) (symbol-value snippet))
                       (_ (user-error "org-latex-feature-implementations :snippet value %s unable to be used" snippet)))
                     "\n")))
                expanded-features
                "")
     "% end features\n")))

(defvar info--tmp nil)

(defadvice! org-latex-save-info (info &optional t_ s_)
  :before #'org-latex-make-preamble
  (setq info--tmp info))

(defadvice! org-splice-latex-header-and-generated-preamble-a (orig-fn tpl def-pkg pkg snippets-p &optional extra)
  "Dynamically insert preamble content based on `org-latex-conditional-preambles'."
  :around #'org-splice-latex-header
  (let ((header (funcall orig-fn tpl def-pkg pkg snippets-p extra)))
    (if snippets-p header
      (concat header
              (org-latex-generate-features-preamble (org-latex-detect-features nil info--tmp))
              "\n"))))

(setq-default org-latex-pdf-process '("tectonic -Z shell-escape --outdir=%o %f"))

(setq-default org-latex-pdf-process '("tectonic -Z shell-escape --outdir=%o %f"))
(setq TeX-save-query nil
      TeX-show-compilation t
      TeX-command-extra-options "-shell-escape")

(after! latex
  (add-to-list 'TeX-command-list '("XeLaTeX" "%`xelatex%(mode)%' %t" TeX-run-TeX nil t)))

(after! ox-latex
  (add-to-list 'org-latex-classes
               '("cb-doc" "\\documentclass{scrartcl}"
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\paragraph{%s}" . "\\paragraph*{%s}")
                 ("\\subparagraph{%s}" . "\\subparagraph*{%s}"))))

(after! ox-latex
  (setq org-latex-default-class "cb-doc"
        org-latex-tables-booktabs t
        org-latex-hyperref-template "\\colorlet{greenyblue}{blue!70!green}
\\colorlet{blueygreen}{blue!40!green}
\\providecolor{link}{named}{greenyblue}
\\providecolor{cite}{named}{blueygreen}
\\hypersetup{
  pdfauthor={%a},
  pdftitle={%t},
  pdfkeywords={%k},
  pdfsubject={%d},
  pdfcreator={%c},
  pdflang={%L},
  breaklinks=true,
  colorlinks=true,
  linkcolor=,
  urlcolor=link,
  citecolor=cite\n}
\\urlstyle{same}
"
        org-latex-reference-command "\\cref{%s}"))

(setq org-latex-default-packages-alist
      `(("AUTO" "inputenc" t
         ("pdflatex"))
        ("T1" "fontenc" t
         ("pdflatex"))
        ("" "fontspec" t)
        ("" "graphicx" t)
        ("" "grffile" t)
        ("" "longtable" nil)
        ("" "wrapfig" nil)
        ("" "rotating" nil)
        ("normalem" "ulem" t)
        ("" "amsmath" t)
        ("" "textcomp" t)
        ("" "amssymb" t)
        ("" "capt-of" nil)
        ("" "firamath-otf" t)
        ("dvipsnames" "xcolor" nil)
        ("colorlinks=true, linkcolor=Blue, citecolor=BrickRed, urlcolor=PineGreen" "hyperref" nil)
        ("" "indentfirst" nil)
        ""
        "\\setmonofont{Liga SFMono Nerd Font}"
        "\\setmainfont{Fira Sans}"))

(use-package! engrave-faces-latex
  :after ox-latex
  :config
  (setq org-latex-listings 'engraved))

(defadvice! org-latex-src-block-engraved (orig-fn src-block contents info)
  "Like `org-latex-src-block', but supporting an engraved backend"
  :around #'org-latex-src-block
  (if (eq 'engraved (plist-get info :latex-listings))
      (org-latex-scr-block--engraved src-block contents info)
    (funcall orig-fn src-block contents info)))

(defadvice! org-latex-inline-src-block-engraved (orig-fn inline-src-block contents info)
  "Like `org-latex-inline-src-block', but supporting an engraved backend"
  :around #'org-latex-inline-src-block
  (if (eq 'engraved (plist-get info :latex-listings))
      (org-latex-inline-scr-block--engraved inline-src-block contents info)
    (funcall orig-fn src-block contents info)))

(defvar-local org-export-has-code-p nil)

(defadvice! org-export-expect-no-code (&rest _)
  :before #'org-export-as
  (setq org-export-has-code-p nil))

(defadvice! org-export-register-code (&rest _)
  :after #'org-latex-src-block-engraved
  :after #'org-latex-inline-src-block-engraved
  (setq org-export-has-code-p t))

(setq org-latex-engraved-code-preamble "
\\usepackage{fvextra}
\\fvset{
  commandchars=\\\\\\{\\},
  highlightcolor=white!95!black!80!blue,
  breaklines=true,
  breaksymbol=\\color{white!60!black}\\tiny\\ensuremath{\\hookrightarrow}}
\\renewcommand\\theFancyVerbLine{\\footnotesize\\color{black!40!white}\\arabic{FancyVerbLine}}

\\definecolor{codebackground}{HTML}{f7f7f7}
\\definecolor{codeborder}{HTML}{f0f0f0}

% TODO have code boxes keep line vertical alignment
\\usepackage[breakable,xparse]{tcolorbox}
\\DeclareTColorBox[]{Code}{o}%
{colback=codebackground, colframe=codeborder,
  fontupper=\\footnotesize,
  colupper=EFD,
  IfNoValueTF={#1}%
  {boxsep=2pt, arc=2.5pt, outer arc=2.5pt,
    boxrule=0.5pt, left=2pt}%
  {boxsep=2.5pt, arc=0pt, outer arc=0pt,
    boxrule=0pt, leftrule=1.5pt, left=0.5pt},
  right=2pt, top=1pt, bottom=0.5pt,
  breakable}
")

(add-to-list 'org-latex-conditional-features '((and org-export-has-code-p "^[ \t]*#\\+begin_src\\|^[ \t]*#\\+BEGIN_SRC\\|src_[A-Za-z]") . engraved-code) t)
(add-to-list 'org-latex-conditional-features '("^[ \t]*#\\+begin_example\\|^[ \t]*#\\+BEGIN_EXAMPLE" . engraved-code-setup) t)
(add-to-list 'org-latex-feature-implementations '(engraved-code :requires engraved-code-setup :snippet (engrave-faces-latex-gen-preamble) :order 99) t)
(add-to-list 'org-latex-feature-implementations '(engraved-code-setup :snippet org-latex-engraved-code-preamble :order 98) t)

(defun org-latex-scr-block--engraved (src-block contents info)
  (let* ((lang (org-element-property :language src-block))
         (attributes (org-export-read-attribute :attr_latex src-block))
         (float (plist-get attributes :float))
         (num-start (org-export-get-loc src-block info))
         (retain-labels (org-element-property :retain-labels src-block))
         (caption (org-element-property :caption src-block))
         (caption-above-p (org-latex--caption-above-p src-block info))
         (caption-str (org-latex--caption/label-string src-block info))
         (placement (or (org-unbracket-string "[" "]" (plist-get attributes :placement))
                        (plist-get info :latex-default-figure-position)))
         (float-env
          (cond
           ((string= "multicolumn" float)
            (format "\\begin{listing*}[%s]\n%s%%s\n%s\\end{listing*}"
                    placement
                    (if caption-above-p caption-str "")
                    (if caption-above-p "" caption-str)))
           (caption
            (format "\\begin{listing}[%s]\n%s%%s\n%s\\end{listing}"
                    placement
                    (if caption-above-p caption-str "")
                    (if caption-above-p "" caption-str)))
           ((string= "t" float)
            (concat (format "\\begin{listing}[%s]\n"
                            placement)
                    "%s\n\\end{listing}"))
           (t "%s")))
         (options (plist-get info :latex-minted-options))
         (content-buffer
          (with-temp-buffer
            (insert
             (let* ((code-info (org-export-unravel-code src-block))
                    (max-width
                     (apply 'max
                            (mapcar 'length
                                    (org-split-string (car code-info)
                                                      "\n")))))
               (org-export-format-code
                (car code-info)
                (lambda (loc _num ref)
                  (concat
                   loc
                   (when ref
                     ;; Ensure references are flushed to the right,
                     ;; separated with 6 spaces from the widest line
                     ;; of code.
                     (concat (make-string (+ (- max-width (length loc)) 6)
                                          ?\s)
                             (format "(%s)" ref)))))
                nil (and retain-labels (cdr code-info)))))
            (funcall (org-src-get-lang-mode lang))
            (engrave-faces-latex-buffer)))
         (content
          (with-current-buffer content-buffer
            (buffer-string)))
         (body
          (format
           "\\begin{Code}\n\\begin{Verbatim}[%s]\n%s\\end{Verbatim}\n\\end{Code}"
           ;; Options.
           (concat
            (org-latex--make-option-string
             (if (or (not num-start) (assoc "linenos" options))
                 options
               (append
                `(("linenos")
                  ("firstnumber" ,(number-to-string (1+ num-start))))
                options)))
            (let ((local-options (plist-get attributes :options)))
              (and local-options (concat "," local-options))))
           content)))
    (kill-buffer content-buffer)
    ;; Return value.
    (format float-env body)))

(defun org-latex-inline-scr-block--engraved (inline-src-block _contents info)
  (let ((options (org-latex--make-option-string
                  (plist-get info :latex-minted-options)))
        code-buffer code)
    (setq code-buffer
          (with-temp-buffer
            (insert (org-element-property :value inline-src-block))
            (funcall (org-src-get-lang-mode
                      (org-element-property :language inline-src-block)))
            (engrave-faces-latex-buffer)))
    (setq code (with-current-buffer code-buffer
                 (buffer-string)))
    (kill-buffer code-buffer)
    (format "\\Verb%s{%s}"
            (if (string= options "") ""
              (format "[%s]" options))
            code)))

(defadvice! org-latex-example-block-engraved (orig-fn example-block contents info)
  "Like `org-latex-example-block', but supporting an engraved backend"
  :around #'org-latex-example-block
  (let ((output-block (funcall orig-fn example-block contents info)))
    (if (eq 'engraved (plist-get info :latex-listings))
        (format "\\begin{Code}[alt]\n%s\n\\end{Code}" output-block)
      output-block)))

(use-package! ox-chameleon
  :after ox)

(setq org-export-with-sub-superscripts '{})

(map! :map calc-mode-map
      :after calc
      :localleader
      :desc "Embedded calc (toggle)" "e" #'calc-embedded)
(map! :map org-mode-map
      :after org
      :localleader
      :desc "Embedded calc (toggle)" "E" #'calc-embedded)
(map! :map latex-mode-map
      :after latex
      :localleader
      :desc "Embedded calc (toggle)" "e" #'calc-embedded)

(defvar calc-embedded-trail-window nil)
(defvar calc-embedded-calculator-window nil)

(defadvice! calc-embedded-with-side-pannel (&rest _)
  :after #'calc-do-embedded
  (when calc-embedded-trail-window
    (ignore-errors
      (delete-window calc-embedded-trail-window))
    (setq calc-embedded-trail-window nil))
  (when calc-embedded-calculator-window
    (ignore-errors
      (delete-window calc-embedded-calculator-window))
    (setq calc-embedded-calculator-window nil))
  (when (and calc-embedded-info
             (> (* (window-width) (window-height)) 1200))
    (let ((main-window (selected-window))
          (vertical-p (> (window-width) 80)))
      (select-window
       (setq calc-embedded-trail-window
             (if vertical-p
                 (split-window-horizontally (- (max 30 (/ (window-width) 3))))
               (split-window-vertically (- (max 8 (/ (window-height) 4)))))))
      (switch-to-buffer "*Calc Trail*")
      (select-window
       (setq calc-embedded-calculator-window
             (if vertical-p
                 (split-window-vertically -6)
               (split-window-horizontally (- (/ (window-width) 2))))))
      (switch-to-buffer "*Calculator*")
      (select-window main-window))))
