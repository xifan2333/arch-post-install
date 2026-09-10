#!/usr/bin/env bash
# arch-basic VM 管理脚本
set -euo pipefail

VM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${VM_DIR}/arch-basic.conf"
DISK="${VM_DIR}/disk.qcow2"
MONITOR="${VM_DIR}/arch-basic-monitor.socket"
PORT=22220
GUEST_USER=arch
CLEAN_SNAPSHOT="clean-systemd-boot"

usage() {
    cat <<EOF
用法: $(basename "$0") <命令> [参数]

  start [--headless]    启动 VM（前台，可选 --headless 无界面）
  stop                  ACPI 优雅关机
  reset                 停止 VM 并回滚到 ${CLEAN_SNAPSHOT} 纯净快照
  ssh [命令...]         SSH 进入客户机（默认交互 shell）
  status                运行状态 + 磁盘/快照信息

  snapshot create <tag> 创建磁盘快照
  snapshot apply  <tag> 回滚到指定快照（VM 必须先关机）
  snapshot delete <tag> 删除快照
  snapshot list         列出快照

示例:
  ./vm.sh start
  ./vm.sh start --headless
  ./vm.sh ssh
  ./vm.sh reset
  ./vm.sh snapshot create before-test
EOF
}

is_running() {
    pgrep -f "qemu-system-x86_64.*arch-basic" >/dev/null 2>&1
}

require_stopped() {
    if is_running; then
        echo "错误: VM 正在运行，请先 './vm.sh stop'" >&2
        exit 1
    fi
}

cmd_start() {
    if is_running; then
        echo "VM 已在运行"
        exit 0
    fi
    local extra_args=()
    if [[ "${1:-}" == "--headless" || "${1:-}" == "headless" ]]; then
        echo "启动 arch-basic (无头模式) ..."
        extra_args+=(--display none)
    else
        echo "启动 arch-basic ..."
    fi
    exec quickemu --vm "$CONF" "${extra_args[@]}"
}

cmd_stop() {
    if ! is_running; then
        echo "VM 未运行"
        exit 0
    fi
    if [ -S "$MONITOR" ]; then
        printf 'system_powerdown\n' | socat - "UNIX-CONNECT:${MONITOR}" >/dev/null 2>&1 || true
        echo "已发送 ACPI 关机，等待退出 ..."
        for _ in $(seq 1 30); do
            is_running || {
                echo "已退出"
                return 0
            }
            sleep 1
        done
        echo "超时，强制结束"
    fi
    pkill -f "qemu-system-x86_64.*arch-basic" || true
}

cmd_reset() {
    if is_running; then
        echo "VM 正在运行，正在优雅关机 ..."
        cmd_stop
    fi
    echo "回滚到纯净快照: ${CLEAN_SNAPSHOT} ..."
    quickemu --vm "$CONF" --snapshot apply "${CLEAN_SNAPSHOT}"
    echo "回滚完成，当前状态为干净环境"
}

cmd_ssh() {
    exec ssh -p "$PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${GUEST_USER}@127.0.0.1" "$@"
}

cmd_status() {
    if is_running; then
        echo "状态: 运行中 (PID $(pgrep -f 'qemu-system-x86_64.*arch-basic' | head -1))"
    else
        echo "状态: 已停止"
    fi
    echo
    qemu-img info -U "$DISK" | grep -E "virtual size|disk size"
    echo
    echo "快照:"
    qemu-img snapshot -l -U "$DISK" || true
}

cmd_snapshot() {
    local action="${1:-list}" tag="${2:-}"
    case "$action" in
    list)
        qemu-img snapshot -l -U "$DISK"
        ;;
    create)
        [ -n "$tag" ] || {
            echo "需要快照名" >&2
            exit 1
        }
        require_stopped
        quickemu --vm "$CONF" --snapshot create "$tag"
        ;;
    apply)
        [ -n "$tag" ] || {
            echo "需要快照名" >&2
            exit 1
        }
        require_stopped
        quickemu --vm "$CONF" --snapshot apply "$tag"
        ;;
    delete)
        [ -n "$tag" ] || {
            echo "需要快照名" >&2
            exit 1
        }
        quickemu --vm "$CONF" --snapshot delete "$tag"
        ;;
    *)
        usage
        exit 1
        ;;
    esac
}

case "${1:-}" in
start)
    shift
    cmd_start "$@"
    ;;
stop) cmd_stop ;;
reset) cmd_reset ;;
ssh)
    shift
    cmd_ssh "$@"
    ;;
status) cmd_status ;;
snapshot)
    shift
    cmd_snapshot "$@"
    ;;
"" | -h | --help | help) usage ;;
*)
    usage
    exit 1
    ;;
esac
