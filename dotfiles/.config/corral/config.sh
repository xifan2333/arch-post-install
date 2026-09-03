# shellcheck shell=bash
# Corral default config (shell). Shipped with the plugin as config.default.sh.
#
# On first run Corral copies this to the single editable config:
#   ${XDG_CONFIG_HOME:-~/.config}/corral/config.sh
# Edit THAT file — one path for Herdr plugin and standalone. Host differences
# are detected in shell via $HERDR_ENV / $HERDR_BIN_PATH (see open(), github_detail).
# Existing configs are never rewritten automatically. Delete config.sh to seed
# a fresh copy of this template on the next launch.
#
# River-style: call `corral bind <key> <action>` (like `riverctl map …`).
#   global actions: quit feature-explorer feature-scm feature-github
#   navigation:     up down top bottom page-up page-down toggle expand
#                   collapse collapse-all toggle-hidden refresh open
#   Explorer:       explorer-create explorer-delete explorer-rename
#   SCM actions:    scm-toggle-stage scm-stage-all scm-unstage-all scm-open-diff
#                   scm-focus-message scm-suggest-message scm-discard
#                   scm-cancel scm-sync
#   GitHub:         github-issues github-pulls github-actions github-view
#                   github-diff github-checks github-log github-log-failed
#                   github-filter github-load-more github-cycle-state
#   GitHub detail:  github-comment github-approve github-context-action
#                   github-close-reopen github-merge github-rerun-failed
#                   github-rerun-all github-workflow-dispatch github-submit
#                   github-confirm github-cancel
#   text editing:   edit-backspace edit-delete edit-home edit-end
#   any other action = a shell function of that name (defined below)
#
# Views may emit shell actions after a configured internal action:
#   open    Explorer  → open a file in the reused side pane / $EDITOR
#   diff*   SCM        → staged / worktree / untracked diff in the reused pane
#   commit_message SCM → commit the panel's inline message and report status

corral bind q quit
corral bind ctrl+c quit
corral bind 1 feature-explorer
corral bind 2 feature-scm
corral bind 3 feature-github

corral bind j down
corral bind down down
corral bind k up
corral bind up up
corral bind g top
corral bind G bottom
corral bind pageup page-up
corral bind pagedown page-down
corral bind h collapse
corral bind left collapse
corral bind l expand
corral bind right expand
corral bind enter toggle
corral bind . toggle-hidden
corral bind z collapse-all
corral bind r refresh
corral bind explorer:a explorer-create
corral bind explorer:d explorer-delete
corral bind explorer:r explorer-rename

corral bind s scm-toggle-stage
corral bind space scm-toggle-stage
corral bind a scm-stage-all
corral bind u scm-unstage-all
corral bind o scm-open-diff
corral bind c scm-focus-message
corral bind D scm-discard
corral bind esc scm-cancel
corral bind S scm-sync
corral bind A scm-suggest-message

corral bind github:i github-issues
corral bind github:p github-pulls
corral bind github:a github-actions
corral bind github:w github-workflows
corral bind github:enter github-view
corral bind github:o github-view
corral bind github:d github-diff
corral bind github:c github-checks
corral bind github:x github-log-failed
corral bind github:L github-log
corral bind github:f github-filter
corral bind github:] github-load-more
corral bind github:s github-cycle-state
corral bind github:t github-workflow-dispatch
corral bind github:tab github-next-section
corral bind github:backtab github-prev-section
corral bind github:y github-confirm
corral bind github:n github-filter-cancel
corral bind github:esc github-filter-cancel

corral bind github-detail:d github-diff
corral bind github-detail:C github-checks
corral bind github-detail:f github-log-failed
corral bind github-detail:L github-log
corral bind github-detail:tab github-next-section
corral bind github-detail:backtab github-prev-section
corral bind github-detail:c github-comment
corral bind github-detail:o open
corral bind github-detail:a github-approve
corral bind github-detail:x github-context-action
corral bind github-detail:D github-close-reopen
corral bind github-detail:m github-merge
corral bind github-detail:R github-rerun-failed
corral bind github-detail:A github-rerun-all
corral bind github-detail:ctrl+enter github-submit
corral bind github-detail:ctrl+s github-submit
corral bind github-detail:y github-confirm
corral bind github-detail:n github-cancel
corral bind github-detail:esc github-cancel

corral bind backspace edit-backspace
corral bind delete edit-delete
corral bind home edit-home
corral bind end edit-end

CORRAL_EDITOR="${CORRAL_EDITOR:-nvim}"
CORRAL_EDITOR_LABEL="Corral Editor"
CORRAL_EDITOR_TOKEN="corral-editor-owner"

_corral_valid_pane_id() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9:._-]*$ ]]
}

_corral_runtime_dir() {
    local base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}" dir
    dir="$base/corral-${UID:-$(id -u)}"
    mkdir -p "$dir" || return 1
    chmod 700 "$dir" || return 1
    printf '%s' "$dir"
}

_corral_nvim_socket() {
    local owner=$1 key runtime
    key=${owner//[^A-Za-z0-9_.-]/_}
    runtime="$(_corral_runtime_dir)" || return 1
    printf '%s/nvim-%s.sock' "$runtime" "$key"
}

_corral_owned_editor() {
    local herdr=$1 owner=$2
    "$herdr" pane list 2>/dev/null |
        jq -r --arg token "$CORRAL_EDITOR_TOKEN" --arg owner "$owner" \
            'first(.result.panes[] | select(.tokens[$token] == $owner) | .pane_id) // empty' 2>/dev/null
}

_corral_focus_pane() {
    local herdr=$1 pane=$2
    "$herdr" pane zoom "$pane" --on >/dev/null 2>&1 &&
        "$herdr" pane zoom "$pane" --off >/dev/null 2>&1
}

_corral_nvim_ready() {
    local herdr=$1 pane=$2 socket=$3 nvim=$4
    [[ -S "$socket" ]] || return 1
    "$herdr" pane process-info --pane "$pane" 2>/dev/null |
        jq -e 'any(.result.process_info.foreground_processes[]?; .name == "nvim")' >/dev/null ||
        return 1
    [[ "$("$nvim" --server "$socket" --remote-expr '1' 2>/dev/null || true)" == 1 ]]
}

_corral_restore_sidebar_width() {
    local herdr=$1 owner=$2 corral_bin plan direction amount
    corral_bin=$(command -v corral 2>/dev/null || true)
    [[ -n "$corral_bin" ]] || return 0
    plan="$("$herdr" pane layout --pane "$owner" 2>/dev/null |
        "$corral_bin" --resize-plan "$owner" 2>/dev/null || true)"
    [[ -n "$plan" ]] || return 0
    IFS=$'\t' read -r direction amount <<<"$plan"
    "$herdr" pane resize --pane "$owner" --direction "$direction" --amount "$amount" \
        >/dev/null 2>&1
}

# Ensure one owner-scoped nvim RPC instance and echo "pane<TAB>socket<TAB>nvim".
_corral_ensure_nvim() {
    local herdr="$HERDR_BIN_PATH" owner="${HERDR_PANE_ID:-}" editor nvim socket pid out cmd
    local neighbor split_target swap_target
    _corral_valid_pane_id "$owner" || return 1
    editor="${CORRAL_EDITOR:-${EDITOR:-${VISUAL:-nvim}}}"
    nvim="$(command -v "${editor%% *}" 2>/dev/null || true)"
    [[ -n "$nvim" && "$(basename "$nvim")" == nvim ]] || {
        printf 'corral: hosted pane reuse currently requires nvim\n' >&2
        return 1
    }
    socket="$(_corral_nvim_socket "$owner")" || return 1
    pid="$(_corral_owned_editor "$herdr" "$owner" || true)"
    [[ -z "$pid" ]] || _corral_valid_pane_id "$pid" || return 1

    if [[ -n "$pid" ]]; then
        _corral_nvim_ready "$herdr" "$pid" "$socket" "$nvim" || {
            printf 'corral: owned editor is not the expected nvim RPC instance\n' >&2
            return 1
        }
        _corral_focus_pane "$herdr" "$pid" || return 1
        printf '%s\t%s\t%s' "$pid" "$socket" "$nvim"
        return 0
    fi

    rm -f -- "$socket"
    # Splitting the 32-column sidebar itself would shrink Corral and leave an
    # unreadable 8-column editor. Instead split its immediate right neighbor,
    # then swap the new owned pane into the wide left slot of that editor area.
    split_target="$owner"
    swap_target=""
    neighbor="$("$herdr" pane neighbor --direction right --pane "$owner" 2>/dev/null |
        jq -r '.result.neighbor.neighbor_pane_id // empty' 2>/dev/null || true)"
    if _corral_valid_pane_id "$neighbor" && [[ "$neighbor" != "$owner" ]]; then
        split_target="$neighbor"
        swap_target="$neighbor"
    fi
    out="$("$herdr" pane split "$split_target" --direction right --focus --ratio 0.75 2>&1)" || return 1
    pid="$(printf '%s' "$out" | jq -r '.result.pane.pane_id // empty' 2>/dev/null || true)"
    _corral_valid_pane_id "$pid" || return 1
    if ! "$herdr" pane report-metadata "$pid" --source corral-editor \
        --token "$CORRAL_EDITOR_TOKEN=$owner" >/dev/null 2>&1 ||
        ! "$herdr" pane rename "$pid" "$CORRAL_EDITOR_LABEL" >/dev/null 2>&1; then
        "$herdr" pane close "$pid" >/dev/null 2>&1 || true
        return 1
    fi
    printf -v cmd 'exec %q --listen %q' "$nvim" "$socket"
    if ! "$herdr" pane run "$pid" "$cmd" >/dev/null 2>&1; then
        "$herdr" pane close "$pid" >/dev/null 2>&1 || true
        return 1
    fi
    if [[ -n "$swap_target" ]] &&
        ! "$herdr" pane swap --source-pane "$pid" --target-pane "$swap_target" >/dev/null 2>&1; then
        "$herdr" pane close "$pid" >/dev/null 2>&1 || true
        return 1
    fi
    _corral_restore_sidebar_width "$herdr" "$owner" || {
        "$herdr" pane close "$pid" >/dev/null 2>&1 || true
        return 1
    }
    for _ in $(seq 1 40); do
        if _corral_nvim_ready "$herdr" "$pid" "$socket" "$nvim"; then
            printf '%s\t%s\t%s' "$pid" "$socket" "$nvim"
            return 0
        fi
        sleep 0.05
    done
    "$herdr" pane close "$pid" >/dev/null 2>&1 || true
    rm -f -- "$socket"
    return 1
}

# CORRAL_WEZTERM_PREVIEW_HELPERS_BEGIN
# WezTerm side-pane helpers. Prefer one reused nvim pane for open + previews
# (:edit / :terminal). If the target pane is not nvim, start one.
_corral_wezterm_pane_title() {
    local pid=$1 panes
    panes="$(wezterm cli list --format json 2>/dev/null || true)"
    jq -r --argjson id "$pid" '.[] | select(.pane_id == $id) | .title // empty' \
        <<<"$panes" 2>/dev/null || true
}

# Resolve an existing target pane: remembered → same-tab rightmost.
# Prints pane id, or empty if none (caller starts nvim). Does not split.
_corral_wezterm_pane() {
    [[ -n "${WEZTERM_PANE:-}" ]] && command -v wezterm >/dev/null 2>&1 || return 1
    local me="$WEZTERM_PANE" state="$CORRAL_CONFIG_DIR/wezterm-editor.pane"
    local pid panes saved
    panes="$(wezterm cli list --format json 2>/dev/null || true)"
    saved="$(cat "$state" 2>/dev/null || true)"
    pid="$(jq -r --argjson me "$me" --arg saved "$saved" '
    ($saved | tonumber? // 0) as $s
    | if $s > 0 and any(.[]; .pane_id == $s) and $s != $me then $s
      else
        (map(select(.pane_id == $me))[0].tab_id) as $tab
        | [ .[] | select(.tab_id == $tab and .pane_id != $me) ] as $others
        # Prefer an existing nvim/vim pane so we do not steal agent panes (pi).
        | (($others | map(select(.title != null and (.title | test("nvim|vim"; "i")))) | sort_by(-.left_col) | .[0].pane_id)
            // ($others | sort_by(-.left_col) | .[0].pane_id)
            // empty)
      end
    ' <<<"$panes" 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then
        printf '%s' "$pid" >"$state"
        printf '%s' "$pid"
    fi
}

# Ensure the wezterm target is nvim so :edit / :terminal work. Reuses an
# existing nvim/vim pane; otherwise splits a fresh `nvim` pane (never steals
# agent panes like pi). Prints the pane id to use.
_corral_wezterm_ensure_nvim() {
    local pid=${1:-} me="$WEZTERM_PANE" state="$CORRAL_CONFIG_DIR/wezterm-editor.pane"
    local title bin new_pid _i
    bin=$(command -v nvim 2>/dev/null || true)
    [[ -n "$bin" ]] || {
        printf 'corral: wezterm pane reuse requires nvim\n' >&2
        return 1
    }
    if [[ -n "$pid" ]]; then
        title="$(_corral_wezterm_pane_title "$pid")"
        if [[ "$title" == *nvim* || "$title" == *vim* ]]; then
            printf '%s' "$pid"
            return 0
        fi
    fi
    # Missing or non-nvim target → dedicated nvim split (PROG form, reliable TTY).
    new_pid="$(wezterm cli split-pane --pane-id "$me" --right --percent 75 -- "$bin" 2>/dev/null | tr -d '[:space:]')" || return 1
    [[ -n "$new_pid" ]] || return 1
    printf '%s' "$new_pid" >"$state"
    for _i in $(seq 1 40); do
        title="$(_corral_wezterm_pane_title "$new_pid")"
        if [[ "$title" == *nvim* || "$title" == *vim* ]]; then
            printf '%s' "$new_pid"
            return 0
        fi
        sleep 0.05
    done
    printf '%s' "$new_pid"
}

# Write cmd to a private script and run it via nvim :terminal in the wezterm
# side pane. Hosted corral has no TTY, so less/corral-github must not eval here.
_corral_run_wezterm() {
    local cmd="$1" input_mode="${2:-normal}" pid runtime script qscript
    pid="$(_corral_wezterm_pane)" || return 1
    pid="$(_corral_wezterm_ensure_nvim "$pid")" || return 1
    runtime="$(_corral_runtime_dir)" || return 1
    script="$(mktemp "$runtime/preview.XXXXXX")" || return 1
    {
        printf '#!/usr/bin/env bash\n'
        printf "trap 'rm -f -- \"\$0\"' EXIT\n"
        printf 'set -o pipefail\n'
        printf '%s\n' "$cmd"
    } >"$script" || {
        rm -f -- "$script"
        return 1
    }
    chmod 700 "$script" || {
        rm -f -- "$script"
        return 1
    }
    qscript=$(printf '%q' "$script")
    wezterm cli activate-pane --pane-id "$pid" >/dev/null 2>&1 || true
    if ! wezterm cli send-text --pane-id "$pid" --no-paste $'\x1c\x0e\e' >/dev/null 2>&1; then
        rm -f -- "$script"
        return 1
    fi
    sleep 0.05
    # Private script path is shell-quoted. nvim :terminal gets a real PTY so
    # less / corral-github raw-mode work (unlike eval in the hosted action).
    if ! wezterm cli send-text --pane-id "$pid" --no-paste \
        ":terminal bash ${qscript}"$'\r' >/dev/null 2>&1; then
        rm -f -- "$script"
        return 1
    fi
    sleep 0.05
    # Exit terminal mode (C-\ C-n) and mark the buffer so Neovim config can
    # scope diff-review keymaps to Corral previews only. Re-enter insert when
    # the caller asked for terminal input.
    wezterm cli send-text --pane-id "$pid" --no-paste $'\x1c\x0e' >/dev/null 2>&1 || true
    wezterm cli send-text --pane-id "$pid" --no-paste ':let b:corral_preview = 1'$'\r' >/dev/null 2>&1 || true
    if [[ "$input_mode" == terminal ]]; then
        sleep 0.05
        wezterm cli send-text --pane-id "$pid" --no-paste 'i' >/dev/null 2>&1 || true
    fi
}

# Dispatch a preview/pager command to the right host surface. Hosted previews
# stay in nvim Normal mode unless the caller explicitly requests terminal input.
_corral_preview() {
    local cmd="$1" input_mode="${2:-normal}"
    if [[ -n "${HERDR_BIN_PATH:-}" && -n "${HERDR_ENV:-}" ]]; then
        echo CORRAL_SUSPEND=0
        _corral_run "$cmd" "$input_mode"
        return $?
    fi
    if [[ -n "${WEZTERM_PANE:-}" ]] && command -v wezterm >/dev/null 2>&1; then
        echo CORRAL_SUSPEND=0
        _corral_run_wezterm "$cmd" "$input_mode"
        return $?
    fi
    echo CORRAL_SUSPEND=1
    eval "$cmd"
}
# CORRAL_WEZTERM_PREVIEW_HELPERS_END

open() {
    local file="${1:-${CORRAL_FILE:-}}"
    [[ -n "$file" && -e "$file" ]] || return 1
    local editor="${EDITOR:-${VISUAL:-vi}}" vfile
    local -a editor_cmd
    read -r -a editor_cmd <<<"$editor"
    vfile=${file// /\\ }

    # --- herdr ---
    if [[ -n "${HERDR_BIN_PATH:-}" && -n "${HERDR_ENV:-}" ]]; then
        echo CORRAL_SUSPEND=0
        local endpoint pid socket nvim
        endpoint="$(_corral_ensure_nvim)" || return 1
        IFS=$'\t' read -r pid socket nvim <<<"$endpoint"
        "$nvim" --server "$socket" --remote "$file" >/dev/null 2>&1 || return 1
        _corral_focus_pane "$HERDR_BIN_PATH" "$pid" || return 1
        return 0
    fi

    # --- wezterm ---
    # Reuse one nvim side pane: remembered → rightmost → split nvim if needed.
    # Always :edit into it; never `split-pane -- $editor file`.
    if [[ -n "${WEZTERM_PANE:-}" ]] && command -v wezterm >/dev/null 2>&1; then
        echo CORRAL_SUSPEND=0
        local pid
        pid="$(_corral_wezterm_pane)" || return 1
        pid="$(_corral_wezterm_ensure_nvim "$pid")" || return 1
        wezterm cli activate-pane --pane-id "$pid" >/dev/null 2>&1 || true
        wezterm cli send-text --pane-id "$pid" --no-paste $'\e:edit '"$vfile"$'\r' >/dev/null
        return 0
    fi

    echo CORRAL_SUSPEND=1
    exec "${editor_cmd[@]}" "$file"
}

# Run a generated preview command in a terminal buffer inside the SAME owned
# nvim pane. The command is stored in a private temporary script, so neither
# shell syntax nor filenames are injected as nvim keystrokes/Ex source.
_corral_run() {
    local cmd="$1" input_mode="${2:-normal}" endpoint pid socket nvim runtime script vim_path expr
    endpoint="$(_corral_ensure_nvim)" || return 1
    IFS=$'\t' read -r pid socket nvim <<<"$endpoint"
    runtime="$(_corral_runtime_dir)" || return 1
    script="$(mktemp "$runtime/preview.XXXXXX")" || return 1
    {
        printf '#!/usr/bin/env bash\n'
        printf "trap 'rm -f -- \"\$0\"' EXIT\n"
        printf 'set -o pipefail\n'
        printf '%s\n' "$cmd"
    } >"$script" || {
        rm -f -- "$script"
        return 1
    }
    chmod 700 "$script" || {
        rm -f -- "$script"
        return 1
    }
    vim_path="$(printf '%s' "$script" | jq -Rs .)" || {
        rm -f -- "$script"
        return 1
    }
    expr="execute('if &buftype ==# ''terminal'' | bwipeout! | endif | enew | setlocal nonumber norelativenumber signcolumn=no foldcolumn=0 wrap | terminal ' . fnameescape($vim_path)) . execute('setlocal wrap') . execute('call winrestview({''leftcol'': 0})')"
    # Mark the buffer so Neovim config applies diff-review keymaps only to
    # Corral previews, never to a terminal the user opens manually.
    expr+=" . execute('let b:corral_preview = 1')"
    if [[ "$input_mode" == terminal ]]; then
        expr+=" . execute('startinsert')"
    fi
    if ! "$nvim" --server "$socket" --remote-expr "$expr" >/dev/null 2>&1; then
        rm -f -- "$script"
        return 1
    fi
    _corral_focus_pane "$HERDR_BIN_PATH" "$pid"
}

# Diff renderer for SCM previews:
#   delta (default, unified syntax-highlighted diff with n/p navigation) | corral | difft | fancy | git
CORRAL_DIFF_TOOL="${CORRAL_DIFF_TOOL:-delta}"

# Diff context lines for SCM previews:
#   full (default: whole file with highlighted diffs) | 3 (standard hunk) | <number>
CORRAL_DIFF_CONTEXT="${CORRAL_DIFF_CONTEXT:-full}"

# Optional delta fallback settings when CORRAL_DIFF_TOOL=delta.
CORRAL_DELTA_THEME="${CORRAL_DELTA_THEME:-Catppuccin Mocha}"
_corral_delta_opts() {
    printf -- '--syntax-theme=%q --line-numbers --hunk-header-decoration-style=none --file-decoration-style="#45475a ul" --file-style="#89b4fa bold" --paging=never' \
        "$CORRAL_DELTA_THEME"
}

# A plain unified-diff producer. `kind` is explicit because an MM path appears
# in both lists with different patches. Untracked files need `--no-index`;
# git's exit 1 then means "different", not failure. Rename/copy previews pass
# both pathspecs so Git retains their structural semantics.
_corral_diff_source() {
    local kind=$1 qdir=$2 qfile=$3 qorig=${4:-} color=${5:-never} color_arg="" ctx_arg="" paths
    [[ "$color" == always ]] && color_arg='-c color.ui=always '

    local ctx="${CORRAL_DIFF_CONTEXT:-full}"
    if [[ "$ctx" == "full" ]]; then
        ctx_arg="-U99999 "
    elif [[ "$ctx" =~ ^[0-9]+$ ]]; then
        ctx_arg="-U$ctx "
    fi

    paths=$qfile
    [[ -n "$qorig" ]] && paths="$paths $qorig"
    case "$kind" in
    staged) printf 'git -C %s --literal-pathspecs %sdiff %s--cached -- %s' "$qdir" "$color_arg" "$ctx_arg" "$paths" ;;
    untracked) printf '{ git -C %s --literal-pathspecs %sdiff %s--no-index -- /dev/null %s || test $? -eq 1; }' "$qdir" "$color_arg" "$ctx_arg" "$qfile" ;;
    *) printf 'git -C %s --literal-pathspecs %sdiff %s-- %s' "$qdir" "$color_arg" "$ctx_arg" "$paths" ;;
    esac
}

# Build one complete diff command for <kind> <dir> <file> [orig]. Resolve
# external programs to absolute paths here: the reused pane's interactive shell
# may have a different PATH from Corral's action process.
_corral_diff_cmd() {
    local kind=$1 dir=$2 file=$3 orig=${4:-} qdir qfile qorig source tool bin
    qdir=$(printf '%q' "$dir")
    qfile=$(printf '%q' "$file")
    qorig=""
    [[ -n "$orig" ]] && qorig=$(printf '%q' "$orig")
    tool=$CORRAL_DIFF_TOOL
    source=$(_corral_diff_source "$kind" "$qdir" "$qfile" "$qorig")

    case "$tool" in
    delta)
        bin=$(command -v delta 2>/dev/null || true)
        if [[ -n "$bin" ]]; then
            printf '%s | %q %s' "$source" "$bin" "$(_corral_delta_opts)"
            return
        fi
        ;;
    difft)
        bin=$(command -v difft 2>/dev/null || true)
        if [[ -n "$bin" ]]; then
            if [[ "$kind" == untracked ]]; then
                printf 'DFT_COLOR=always %q /dev/null %s | less -R' "$bin" "$qfile"
            else
                local cached=""
                [[ "$kind" == staged ]] && cached='--cached '
                printf 'DFT_COLOR=always GIT_EXTERNAL_DIFF=%q git -C %s --literal-pathspecs --no-pager diff %s-- %s %s | less -R' "$bin" "$qdir" "$cached" "$qfile" "$qorig"
            fi
            return
        fi
        ;;
    fancy)
        bin=$(command -v diff-so-fancy 2>/dev/null || true)
        if [[ -n "$bin" ]]; then
            source=$(_corral_diff_source "$kind" "$qdir" "$qfile" "$qorig" always)
            printf '%s | %q | less -R' "$source" "$bin"
            return
        fi
        ;;
    git | corral) ;;
    *)
        printf 'printf %q >&2; false' "corral: unknown CORRAL_DIFF_TOOL=$tool"
        return
        ;;
    esac

    source=$(_corral_diff_source "$kind" "$qdir" "$qfile" "$qorig" always)
    printf '%s | less -R' "$source"
}

_corral_show_diff() {
    local kind=$1 file="${2:-${CORRAL_FILE:-}}" dir path orig cmd
    [[ -n "$file" ]] || return 1
    # SCM provides a stable repository root and repo-relative path. The fallback
    # keeps custom/manual calls compatible, while deleted SCM paths no longer
    # depend on a parent directory that may not exist.
    dir="${CORRAL_GIT_ROOT:-$(dirname "$file")}"
    path="${CORRAL_GIT_PATH:-$file}"
    orig="${CORRAL_GIT_ORIG:-}"
    cmd=$(_corral_diff_cmd "$kind" "$dir" "$path" "$orig")
    _corral_preview "$cmd"
}

# Feature actions emitted by SCM; keep kind explicit across the shell boundary.
diff() { _corral_show_diff unstaged "$@"; }
diff_staged() { _corral_show_diff staged "$@"; }
diff_untracked() { _corral_show_diff untracked "$@"; }

# Show a commit/branch reference, optionally restricted to the File History path.
show_ref() {
    local dir="${CORRAL_GIT_ROOT:-${1:-.}}" ref="${CORRAL_GIT_REF:-}" path="${CORRAL_GIT_PATH:-}"
    local qdir qref qpath source cmd
    [[ -n "$ref" ]] || return 1
    qdir=$(printf '%q' "$dir")
    qref=$(printf '%q' "$ref")
    local ctx="${CORRAL_DIFF_CONTEXT:-full}" ctx_arg=""
    [[ "$ctx" == "full" ]] && ctx_arg="-U99999 "
    [[ "$ctx" =~ ^[0-9]+$ ]] && ctx_arg="-U$ctx "
    source="git -C $qdir --literal-pathspecs show --format=fuller --stat --patch ${ctx_arg}--end-of-options $qref"
    if [[ -n "$path" ]]; then
        qpath=$(printf '%q' "$path")
        source="$source -- $qpath"
    fi
    if [[ "$CORRAL_DIFF_TOOL" == "delta" ]] && command -v delta >/dev/null 2>&1; then
        printf -v cmd '%s | %q %s' "$source" "$(command -v delta)" "$(_corral_delta_opts)"
    else
        cmd="$source | less -R"
    fi
    _corral_preview "$cmd"
}

# Worktree activation opens its root in the same owner-scoped nvim instance.
open_worktree() {
    local path="${CORRAL_WORKTREE_PATH:-${1:-}}"
    [[ -n "$path" && -d "$path" ]] || return 1
    open "$path"
}

# CORRAL_GITHUB_PREVIEW_BEGIN
# GitHub's long-form views share the owner-scoped nvim pane with Explorer and
# SCM. Identifiers arrive as structured env, are validated, and are shell-quoted
# before entering the private preview script.
github_preview() {
    local kind="${CORRAL_GITHUB_KIND:-}" repo="${CORRAL_GITHUB_REPO:-}"
    local number="${CORRAL_GITHUB_NUMBER:-}" run_id="${CORRAL_GITHUB_RUN_ID:-}"
    local gh_bin qgh qrepo cmd
    [[ -n "$repo" ]] || return 1
    gh_bin=$(command -v gh 2>/dev/null || true)
    [[ -n "$gh_bin" ]] || {
        printf 'corral: GitHub CLI (gh) not found\n' >&2
        return 1
    }
    qgh=$(printf '%q' "$gh_bin")
    qrepo=$(printf '%q' "$repo")
    case "$kind" in
    issue)
        [[ "$number" =~ ^[0-9]+$ ]] || return 1
        printf -v cmd 'GH_PROMPT_DISABLED=1 GH_PAGER=cat %s issue view %s --repo %s --comments | less -R' "$qgh" "$number" "$qrepo"
        ;;
    pr)
        [[ "$number" =~ ^[0-9]+$ ]] || return 1
        printf -v cmd 'GH_PROMPT_DISABLED=1 GH_PAGER=cat %s pr view %s --repo %s --comments | less -R' "$qgh" "$number" "$qrepo"
        ;;
    diff)
        [[ "$number" =~ ^[0-9]+$ ]] || return 1
        if [[ "$CORRAL_DIFF_TOOL" == "delta" ]] && command -v delta >/dev/null 2>&1; then
            printf -v cmd 'GH_PROMPT_DISABLED=1 GH_PAGER=cat %s pr diff %s --repo %s | %q %s' "$qgh" "$number" "$qrepo" "$(command -v delta)" "$(_corral_delta_opts)"
        else
            printf -v cmd 'GH_PROMPT_DISABLED=1 GH_PAGER=cat %s pr diff %s --repo %s | less -R' "$qgh" "$number" "$qrepo"
        fi
        ;;
    checks)
        [[ "$number" =~ ^[0-9]+$ ]] || return 1
        # gh uses exit 8 for pending checks; it is a valid preview state.
        printf -v cmd '{ GH_PROMPT_DISABLED=1 GH_PAGER=cat %s pr checks %s --repo %s; code=$?; (( code == 0 || code == 8 )); } | less -R' "$qgh" "$number" "$qrepo"
        ;;
    run)
        [[ "$run_id" =~ ^[0-9]+$ ]] || return 1
        printf -v cmd 'GH_PROMPT_DISABLED=1 GH_PAGER=cat %s run view %s --repo %s | less -R' "$qgh" "$run_id" "$qrepo"
        ;;
    log)
        [[ "$run_id" =~ ^[0-9]+$ ]] || return 1
        printf -v cmd 'GH_PROMPT_DISABLED=1 GH_PAGER=cat %s run view %s --repo %s --log | less -R' "$qgh" "$run_id" "$qrepo"
        ;;
    log-failed)
        [[ "$run_id" =~ ^[0-9]+$ ]] || return 1
        printf -v cmd 'GH_PROMPT_DISABLED=1 GH_PAGER=cat %s run view %s --repo %s --log-failed | less -R' "$qgh" "$run_id" "$qrepo"
        ;;
    *) return 1 ;;
    esac
    _corral_preview "$cmd" terminal
}
# CORRAL_GITHUB_PREVIEW_END

# CORRAL_GITHUB_DETAIL_BEGIN
# Open the independent full-width GitHub client in the same owner-scoped nvim
# terminal used by Explorer and SCM previews.
# Images are rendered as text links; click (or press o) downloads the file and
# opens it with CORRAL_GITHUB_IMAGE_VIEWER (default: imv).
CORRAL_GITHUB_IMAGE_VIEWER="${CORRAL_GITHUB_IMAGE_VIEWER:-imv}"
github_detail() {
    local kind="${CORRAL_GITHUB_KIND:-}" repo="${CORRAL_GITHUB_REPO:-}"
    local number="${CORRAL_GITHUB_NUMBER:-}" run_id="${CORRAL_GITHUB_RUN_ID:-}"
    local bin qbin qrepo qviewer resource id view cmd
    [[ -n "$repo" ]] || return 1
    bin=$(command -v corral-github 2>/dev/null || true)
    if [[ -z "$bin" && -n "${HERDR_PLUGIN_ROOT:-}" ]]; then
        for candidate in \
            "$HERDR_PLUGIN_ROOT/target/release/corral-github" \
            "$HERDR_PLUGIN_ROOT/target/debug/corral-github"; do
            if [[ -x "$candidate" ]]; then
                bin=$candidate
                break
            fi
        done
    fi
    [[ -n "$bin" ]] || {
        github_preview
        return $?
    }
    case "$kind" in
    issue)
        resource='issue'
        id="$number"
        view='overview'
        ;;
    pr)
        resource='pr'
        id="$number"
        view='overview'
        ;;
    diff)
        resource='pr'
        id="$number"
        view='diff'
        ;;
    checks)
        resource='pr'
        id="$number"
        view='checks'
        ;;
    run)
        resource='run'
        id="$run_id"
        view='overview'
        ;;
    log)
        resource='run'
        id="$run_id"
        view='log'
        ;;
    log-failed)
        resource='run'
        id="$run_id"
        view='log-failed'
        ;;
    *) return 1 ;;
    esac
    [[ "$id" =~ ^[0-9]+$ ]] || return 1
    qbin=$(printf '%q' "$bin")
    qrepo=$(printf '%q' "$repo")
    qviewer=$(printf '%q' "${CORRAL_GITHUB_IMAGE_VIEWER:-imv}")
    printf -v cmd 'exec env CORRAL_GITHUB_IMAGE_VIEWER=%s %s %s --repo %s %s --view %s' \
        "$qviewer" "$qbin" "$resource" "$qrepo" "$id" "$view"
    _corral_preview "$cmd" terminal
}
# CORRAL_GITHUB_DETAIL_END

# Optional intelligent commit-message provider. Corral appends one prompt
# argument containing instructions, changed files, and the bounded Git diff.
# The command must print one proposed subject line on stdout.
# Examples:
#   CORRAL_COMMIT_SUGGEST_CMD='pi -p --no-tools --no-session --no-context-files'
#   CORRAL_COMMIT_SUGGEST_CMD='my-local-model --prompt'
CORRAL_COMMIT_SUGGEST_CMD='pi -p --no-tools --no-session --no-context-files'
CORRAL_COMMIT_SUGGEST_PROMPT="${CORRAL_COMMIT_SUGGEST_PROMPT:-Generate exactly one Git commit subject following Conventional Commits 1.0.0. Format: <type>[optional scope][optional !]: <description>. Choose the single best type: feat for a new user-visible capability; fix for a defect; refactor for an internal change with no behavior change; perf for performance; docs for documentation only; test for tests only; build for build or dependency changes; ci for CI; style for formatting only; chore only when no more specific type fits. Add a short noun scope only when the affected component is unambiguous. Add ! only when the diff clearly introduces an incompatible API or behavior change. Write a specific present-tense imperative description that completes 'If applied, this commit will ...'. Prefer 50 characters for the whole subject and never exceed 72. Do not end with punctuation. Do not output quotes, Markdown, explanations, issue IDs, or a body. Base the subject only on the supplied files and diff; never invent changes. Good: 'feat(scm): add configurable commit suggestions'. Good: 'fix(diff): ignore stat separators outside hunks'. Bad: 'chore: update stuff'. Output only the subject line.}"
suggest_commit_message() {
    local dir="${CORRAL_GIT_ROOT:-${1:-.}}" diff files
    [[ -n "$CORRAL_COMMIT_SUGGEST_CMD" ]] || {
        printf 'Set CORRAL_COMMIT_SUGGEST_CMD in config.sh to enable suggestions.\n' >&2
        return 1
    }
    diff=$(git -C "$dir" --literal-pathspecs diff --cached --stat --patch --no-ext-diff)
    files=$(git -C "$dir" --literal-pathspecs diff --cached --name-only)
    if [[ -z "$diff" ]]; then
        diff=$(git -C "$dir" --literal-pathspecs diff --stat --patch --no-ext-diff)
        files=$(git -C "$dir" --literal-pathspecs diff --name-only)
    fi
    if [[ -z "$files" ]]; then
        files=$(git -C "$dir" --literal-pathspecs ls-files --others --exclude-standard)
    fi
    [[ -n "$diff" || -n "$files" ]] || {
        printf 'no changes to describe\n' >&2
        return 1
    }
    diff=${diff:0:16384}
    local payload qpayload
    payload="$CORRAL_COMMIT_SUGGEST_PROMPT"$'\n\nChanged files:\n'"$files"$'\n\nGit diff:\n'"$diff"
    export CORRAL_COMMIT_SUGGEST_PROMPT CORRAL_COMMIT_FILES="$files"
    # Quote the generated prompt before evaluating the user-configured command,
    # so arbitrary diff contents never become shell source.
    printf -v qpayload '%q' "$payload"
    eval "$CORRAL_COMMIT_SUGGEST_CMD $qpayload"
}

# Commit the SCM panel's inline message. The TUI receives success/failure and
# keeps the message on failure; no terminal handoff is needed.
commit_message() {
    local dir="${1:-${CORRAL_FILE:-.}}" message="${CORRAL_COMMIT_MESSAGE:-}"
    [[ -n "$message" ]] || return 1
    echo CORRAL_SUSPEND=0
    git -C "$dir" commit -m "$message"
}

# Optional interactive commit action for custom user bindings.
commit() {
    local dir="${1:-${CORRAL_FILE:-.}}"
    _corral_preview "git -C $(printf '%q' "$dir") commit -v"
}
