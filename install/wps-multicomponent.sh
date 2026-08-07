#!/bin/bash
# 确保 WPS 使用多组件模式 (prome_independ)
#
# 背景: WPS 12.x 默认整合模式 (prome_fushion) 存在启动参数 bug
#   (-multiply 强制/绝对路径参数导致秒退、双击无反应)
#   切换多组件模式后一切正常。此脚本幂等, 可重复执行。
#
# 用法: ./install/wps-multicomponent.sh
set -e

CFG="${HOME}/.config/Kingsoft/Office.conf"
mkdir -p "$(dirname "$CFG")"
[ -f "$CFG" ] || touch "$CFG"

KEY1='wpsoffice\Application%20Settings\AppComponentMode'
KEY2='wpsoffice\Application%20Settings\AppComponentModeInstall'

for KEY in "$KEY1" "$KEY2"; do
    if grep -qF "$KEY=" "$CFG"; then
        sed -i "s|^${KEY}=.*|${KEY}=prome_independ|" "$CFG"
        echo "[已更新] ${KEY}=prome_independ"
    else
        echo "${KEY}=prome_independ" >> "$CFG"
        echo "[已追加] ${KEY}=prome_independ"
    fi
done

echo "完成: WPS 多组件模式已确保"
