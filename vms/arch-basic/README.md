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
| `README.md`       | 本文件                                           |
| `arch-basic.*`    | Quickemu 运行时生成（socket / pid / 日志 / `.sh`），可忽略 |

## 备注

- 官方 `basic` 镜像的 `sshd` 因缺 host key 启动失败；已用 `ssh-keygen -A` 修复并 `systemctl enable sshd`。
- 原镜像用 GRUB（BIOS/UEFI 双支持）；已迁移为纯 UEFI + systemd-boot。
- 宿主机依赖：`qemu-desktop`、`edk2-ovmf`、`swtpm`、`quickemu`。
