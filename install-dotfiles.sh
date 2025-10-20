#!/bin/bash
# Deploy dotfiles using stow
# 目标：将 $DOTFILES_SRC 同步到 $DOTFILES_TARGET，然后 Stows 到 $HOME。
# 使用 rsync -a -u 确保运行时脚本对文件的动态修改（在 $DOTFILES_TARGET 中）不会被覆盖。

# Simple output functions
print_step() { echo -e "\n\033[0;34m==>\033[0m \033[1;37m$1\033[0m"; }
print_substep() { echo -e "  \033[0;35m->\033[0m $1"; }
print_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }
print_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
print_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

# --- 变量和工具检查 ---
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_SRC="$SCRIPT_DIR/dotfiles"
DOTFILES_TARGET="$HOME/.dotfiles"

# 检查所需工具
for tool in stow rsync git; do
    if ! command -v "$tool" &> /dev/null; then
        print_error "$tool is not installed. Please install it."
        exit 1
    fi
done

# 切换到 Stow 目标目录，所有操作都将在这里进行
mkdir -p "$DOTFILES_TARGET"
cd "$DOTFILES_TARGET" || exit 1

# --- 步骤 1: Git 仓库初始化与配置 ---
GIT_INITIATED=false
if [ ! -d ".git" ]; then
    print_step "Initializing Git repository in $DOTFILES_TARGET"
    if git init >/dev/null 2>&1; then
        print_success "Git repository initialized."
        GIT_INITIATED=true
    else
        print_error "Failed to initialize Git in $DOTFILES_TARGET. Skipping Git checks."
    fi
fi

# 设置 Git 忽略文件模式（权限变化），防止 chmod +x 导致的状态修改报告
# 仅在 .git 目录存在时执行
if [ -d ".git" ]; then
    print_substep "Setting Git to ignore file mode changes (core.filemode false)"
    git config core.filemode false
    print_success "Git file mode tracking disabled."
fi

# --- 步骤 2: 将 Git 仓库内容同步到 Stow 工作目录 ---
print_step "Syncing dotfiles to Stow working directory ($DOTFILES_TARGET)"
# rsync -a -u: 只更新目标端比源端旧的文件。这保证了运行时对文件的修改会被保留。
rsync -a -u "$DOTFILES_SRC/" "$DOTFILES_TARGET/"
print_success "Stow working directory synced."

# --- 步骤 3: 首次运行后的初始 Git 提交 ---
# 确保 HEAD 是有效的，以便后续 git diff-index 检查能正常工作
if [ -d ".git" ]; then
    if [ "$GIT_INITIATED" = true ] || [ "$(git rev-list --count HEAD 2>/dev/null || echo 0)" -eq 0 ]; then
        print_step "Performing initial commit"
        git add .
        if git commit -m "Initial commit of dotfiles via deployment script" >/dev/null 2>&1; then
            print_success "Initial commit successful. Git history established."
        else
            print_warning "Skipping initial commit (no files to commit or already committed)."
        fi
    fi
fi

# --- 步骤 4: Stow 部署和冲突处理 ---
print_step "Deploying dotfiles using stow"

# 1. Unstow first (忽略错误)
stow -D -t "$HOME" . 2>/dev/null || true
print_substep "Previous links unstowed."

# 2. 检查并处理冲突
if ! stow -n -t "$HOME" . 2>&1 | grep -q "would cause conflicts"; then
    print_substep "No major conflicts detected."
else
    # 发现并移除与 Stow 冲突的常规文件和符号链接
    # 在rsync update模式下，这些可能是运行时脚本创建的符号链接（如theme.yml）
    stow -n -t "$HOME" . 2>&1 | grep "existing target" | sed 's/.*existing target //' | sed 's/ since.*//' | while read -r conflict; do
        target="$HOME/$conflict"
        # 删除常规文件和符号链接，但保留目录
        # 这些是运行时脚本创建的，rsync不会覆盖它们，所以需要手动清理
        if [ -e "$target" ] && [ ! -d "$target" ]; then
            print_warning "Removing conflicting file or symlink (created by runtime scripts): $target"
            rm -f "$target"
        fi
    done
fi

# 3. Stow the package
if stow -t "$HOME" .; then
    print_success "Dotfiles deployed: ~/.dotfiles/* -> ~/"
else
    print_error "Failed to stow dotfiles. Check output for remaining conflicts."
    exit 1
fi

# --- 步骤 5: 后续清理和权限设置 ---
print_step "Setting executable permissions for scripts"
if [ -d "$HOME/.local/bin" ]; then
    chmod +x "$HOME/.local/bin"/* 2>/dev/null || true
fi
if [ -d "$HOME/.local/lib" ]; then
    # 这是您之前脚本中的 chmod 操作，它将不再导致 Git 报告修改
    chmod +x "$HOME/.local/lib"/* 2>/dev/null || true
fi
print_success "Script permissions updated."

# --- 步骤 6: Git 状态检查（处理动态修改） ---
print_step "Checking Git status for dynamic changes"

# 检查 .git 目录是否存在
if [ -d ".git" ]; then
    # 检查工作目录中是否有未提交的修改
    if ! git diff-index --quiet HEAD --; then
        print_warning "Dynamic changes detected in $DOTFILES_TARGET/"
        print_info "Reminder: Your runtime scripts have modified files (e.g., bashrc) after initial commit."
        print_info "Please review these changes with 'git status' and commit them."
        # 简要显示被修改的文件
        git status -s
    else
        print_success "No uncommitted dynamic changes in dotfiles repository."
    fi
else
    print_warning "Skipping Git status check: $DOTFILES_TARGET is not a Git repository."
fi

# 脚本正常结束
exit 0