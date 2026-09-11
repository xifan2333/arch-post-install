# arch-basic — Arch Linux VM

由 **Quickemu** 管理的 Arch Linux 虚拟机，直接以官方预装 qcow2 镜像启动（零安装）。

## 规格

| 项目      | 值                                                              |
| --------- | --------------------------------------------------------------- |
| 客户机    | Arch Linux（官方 arch-boxes `basic` 镜像，2026-09-01）           |
| 固件      | **UEFI**（OVMF `/usr/share/edk2/x64/OVMF_CODE.4m.fd`）           |
| 引导器    | **systemd-boot**（ESP 挂载于 `/boot`，GRUB 已移除）              |
| CPU / RAM | 4 vCPU（2 核 × 2 线程）/ 4 GiB                                   |
| 磁盘      | 40 GiB（qcow2，稀疏，实际约 730 MiB）                            |
| 文件系统  | 根 `/` 为 btrfs；ESP 为 vfat（300 MiB，挂 `/boot`）              |
| 网络      | QEMU user-mode NAT，`eth0 = 10.0.2.15/24`                        |
| 登录      | 用户 `arch` / 密码 `arch`                                        |
| SSH       | `ssh arch@localhost -p 22220`                                    |
| 共享目录  | 宿主机 `~` → 客户机 `~/xifan`（9p，`mount_tag=Public-xifan`）    |
| WebDAV    | 客户机内 `dav://localhost:9843/`                                 |

## 管理

```bash
./vm.sh start                  # 启动
./vm.sh ssh                    # SSH 登录
./vm.sh stop                   # ACPI 优雅关机
./vm.sh status                 # 运行状态 + 磁盘/快照信息

./vm.sh snapshot create <tag>  # 新建磁盘快照
./vm.sh snapshot apply  <tag>  # 回滚（VM 必须先关机）
./vm.sh snapshot delete <tag>  # 删除快照
./vm.sh snapshot list          # 列出快照
```

> 不想用脚本也可以直接：
> `quickemu --vm vms/arch-basic/arch-basic.conf`

## 快照

已有快照 **`clean-systemd-boot`** —— UEFI + systemd-boot 迁移完成后的干净状态。
这是**磁盘快照**，回滚会丢弃其后的所有改动；**回滚前 VM 必须关机**。

## 目录内容

| 文件              | 说明                                             |
| ----------------- | ------------------------------------------------ |
| `arch-basic.conf` | Quickemu 配置（唯一需要手工维护的文件）          |
| `disk.qcow2`      | 系统盘（含所有快照）                             |
| `OVMF_VARS.fd`    | UEFI NVRAM，保存 efibootmgr 启动项               |
| `vm.sh`           | 本目录管理脚本                                   |
| `hmp.py`          | 通过 QEMU HMP 向客户机注入真实输入的测试工具      |
| `README.md`       | 本文件                                           |
| `arch-basic.*`    | Quickemu 运行时生成（socket / pid / 日志 / `.sh`），可忽略 |

## 向客户机注入输入（测试桌面组件时用）

**不要用 `ydotool` / `wtype` 之类的合成输入设备。** 它们会在客户机里凭空
多出一台虚拟输入设备（`libinput list-devices` 会多出 `ydotoold virtual
device`），于是你测的就不再是用户真实走的输入路径，而且多设备并存会让指针
归属变得不可预测。

正确做法是复用 QEMU 自己的输入通道 — 事件直接进 `QEMU HID Tablet`，也就是
物理鼠标驱动的同一台设备：

```bash
./hmp.py                                  # 查看鼠标设备列表（确认 * 在 #4）
./hmp.py move <dx> <dy>                   # 相对移动指针
./hmp.py cmd 'mouse_button 1'             # 左键按下（1=L, 2=R, 4=M），状态保持
./hmp.py cmd 'mouse_button 0'             # 全部抬起
./hmp.py cmd 'sendkey meta_l 3000'        # 按住 Super 3 秒（跨整个拖拽序列）
./hmp.py drag-super 1 <dx> <dy>           # 按住 Super 拖左键
./hmp.py wheel <dz>                       # 滚动滚轮
```

规范测试一个手势的写法：

```bash
# 1. 先把指针停到已知位置，并确认窗口管理器认为的 hover 目标
./hmp.py move -3000 -3000 && ./hmp.py move 300 400
ssh arch@127.0.0.1 -p 22220 'WAYLAND_DISPLAY=wayland-1 xrwm status'
#   看 hovered_window_id，确认指针确实落在预期的窗口上，再动手势

# 2. 再做手势，并对比手势前后的 status / 日志
./hmp.py cmd 'sendkey meta_l 2500'
./hmp.py cmd 'mouse_button 4' && sleep 0.5 && ./hmp.py cmd 'mouse_button 0'
```

> **踩过的坑**：如果手势"没生效"，先看 `hovered_window_id` 是不是 `null`。
> 指针不在任何窗口上时，指针绑定照样会触发，但窗口管理器的 hover 目标是空，
> 于是动作无处施加 —— 这不是绑定没注册，而是测试没有把指针放到窗口上。

## 备注

- 官方 `basic` 镜像的 `sshd` 因缺 host key 启动失败；已用 `ssh-keygen -A` 修复并 `systemctl enable sshd`。
- 原镜像用 GRUB（BIOS/UEFI 双支持）；已迁移为纯 UEFI + systemd-boot。
- 宿主机依赖：`qemu-desktop`、`edk2-ovmf`、`swtpm`、`quickemu`。
- HMP socket 只在 VM 运行时存在；`hmp.py` 默认连 `arch-basic-monitor.socket`。
