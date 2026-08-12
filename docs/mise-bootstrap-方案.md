# QQ/微信 输入法修复：mise bootstrap 接管方案（圈定最佳方案）

> 2026-08-13 定稿。解决"linuxqq / wechat 每次更新后输入法切换失效"这一反复复发的问题，
> 并顺带接管 elephant 启动器的搜索配置。选定 mise bootstrap 作为唯一维护路径。

---

## 1. 问题背景

### 1.1 症状

- `linuxqq-appimage` 每次 `pacman -Syu` 更新后，QQ 里 fcitx5 输入法切换失效；
- 手动修复（编辑 `~/.local/share/applications/linuxqq.desktop` 加参数）有效，但下次更新又复发。

### 1.2 根因链（均有日志/源码证据）

```
腾讯 3.2.30 起 --ozone-platform-hint=wayland 失效（AUR linuxqq 评论：GoodbyeNJN 2026-07-04，
Mundanity 2026-07-07 确认显式 --ozone-platform=wayland 有效）
        │
        ▼
IME 参数只能通过 desktop 文件 Exec 传入（无标准环境变量可强制）
        │
        ▼
elephant（omarchy 默认启动器，abenz1267/elephant）以 map[basename] 缓存 desktop 条目，
fsnotify 实时监听，同名文件"后写入者覆盖"——不区分用户级/系统级
（源码：internal/providers/desktopapplications/{files.go,query.go}）
        │
        ▼
pacman 更新重写 /usr/share/applications/*.desktop（裸 Exec）→ elephant 缓存被顶成裸参数版
        │
        ▼
QQ 落到 XWayland → text-input-v3 不可用 → fcitx5 无法切换输入法
```

关键实测时间线（journalctl 证据）：

| 时刻 | 事件 | elephant 缓存 |
|---|---|---|
| 08-08 02:21 | nvim 编辑用户级 desktop（带 flags） | 带 flags ✓ |
| 08-08 01:05 | 启动 QQ，uwsm_app-daemon 收到带 flags 命令 | — |
| 08-13 00:42 | pacman 更新重写系统级 desktop（裸参数） | 裸参数 ✗ |
| 08-13 00:59 | 启动 QQ，uwsm_app-daemon 收到裸命令 `--no-sandbox` | 无窗口、无 IME |

微信（wechat-appimage 4.1.1）同构风险：当前侥幸走用户级文件，一旦更新即复发。

---

## 2. 方案对比（为什么选 mise bootstrap）

| 方案 | 缺陷 | 结论 |
|---|---|---|
| 手动编辑用户级 desktop | 更新后系统级 mtime 变新，elephant 后写覆盖；不可复现、易忘 | ✗ |
| 只改系统级 desktop | 每次包更新被覆盖，需重复 sudo 操作 | ✗ |
| 环境变量 `ELECTRON_OZONE_PLATFORM_HINT` | 3.2.30+ 失效（与 hint 参数同机制）；无强制 ozone 的标准变量 | ✗ |
| 替换 `/usr/bin/linuxqq` wrapper 脚本 | 包更新覆盖；AppImage 场景更脆弱 | ✗ |
| **mise bootstrap 接管** | 无 | ✅ **选定** |

mise bootstrap 方案的三层保障：

1. **声明式**：所有修复物（desktop 文件、hook、搜索配置）进 git，`mise bootstrap` 一键部署；
2. **幂等**：hook 部署用 `cmp` 比较、desktop 重写用 sed（已含参数时匹配不到、零副作用）；
3. **自动兜底**：pacman hook 在每次包更新后立即重写系统级 desktop —— 无论 elephant 缓存哪份文件，内容都是带 flags 的。

---

## 3. 落地清单

```
arch-post-install/
├── mise.toml
│   └── [tasks.hooks]                      # 幂等部署 pacman hooks 到 /etc
├── dotfiles/
│   ├── .config/elephant/
│   │   └── desktopapplications.toml       # 搜索配置：放开英文搜索 + aliases
│   └── .local/share/applications/
│       ├── linuxqq.desktop                # 带 IME flags（软链接到 ~）
│       └── wechat.desktop                 # 带 IME flags（软链接到 ~）
└── mise/hooks/
    ├── linuxqq-appimage-ime.hook          # 更新后重写 QQ desktop Exec
    └── wechat-appimage-ime.hook           # 更新后重写微信 desktop Exec
```

### 3.1 IME 参数（QQ 与微信相同）

```ini
Exec=env DESKTOPINTEGRATION=false /usr/bin/linuxqq --no-sandbox \
  --enable-features=UseOzonePlatform --ozone-platform=wayland \
  --enable-wayland-ime --wayland-text-input-version=3 %U
```

### 3.2 pacman hook（linuxqq 版，微信同构）

```ini
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linuxqq-appimage

[Action]
Description = Re-apply Wayland IME flags to linuxqq.desktop
When = PostTransaction
Exec = /bin/sh -c "sed -i 's#/usr/bin/linuxqq --no-sandbox %U#/usr/bin/linuxqq --no-sandbox --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3 %U#' /usr/share/applications/linuxqq.desktop"
```

### 3.3 elephant 搜索配置

```toml
show_actions = false
only_search_title = false          # 放开 Name/Exec/GenericName/Keywords/Comment，英文可搜
history = false

[aliases]                          # 拼音/缩写精确置顶（100 万分）
"wx" = "wechat.desktop"
"weixin" = "wechat.desktop"
"qq" = "linuxqq.desktop"
```

---

## 4. 工作机理

### 平时（无更新）

- elephant 启动扫描：`xdg.ApplicationDirs` 用户目录在前 → 缓存用户级软链接（带 flags）→ 正常。

### 包更新时

```
pacman 写入系统级裸 desktop
        │
        ▼
PostTransaction hook 立即 sed 重写为带 flags（幂等，重复跑无副作用）
        │
        ▼
elephant fsnotify 事件触发 → addNewEntry 覆盖缓存 → 缓存到的是带 flags 版
        │
        ▼
无论从哪个 desktop 条目启动，QQ/微信都带完整 IME 参数
```

### 新机器部署

```bash
git clone https://github.com/xifan2333/arch-post-install.git ~/code/arch-post-install
cd ~/code/arch-post-install && mise trust
mise bootstrap --yes          # 链接 dotfiles + 装包 + [tasks.hooks] 部署 hooks
```

装包后系统级 desktop 虽是裸参数，但 elephant 初始加载用户目录优先 → 立即可用；
此后任何更新由 hook 兜底，永不复发。

---

## 5. 验证记录（2026-08-13 实测）

- **QQ**：重启后进程命令行含全部 IME 参数；`hyprctl clients` 显示 `xwayland: false`、窗口正常映射；输入法切换恢复。
- **微信**：同参数已生效（运行中进程验证），系统级 desktop 已补齐，预防到位。
- **hook 部署任务**：两分支实测 —— 文件缺失 → `[installed]`（sudo 自动）；文件一致 → `[ok] up to date`。
- **elephant 配置**：重启后 `desktop files=91` 正常加载，`wx`/`weixin` 别名命中置顶。

---

## 6. 维护注意

1. **换包需同步改 hook**：若从 `linuxqq-appimage` 换回 deb 版 `linuxqq`（其 desktop 文件名是 `qq.desktop`），需改 hook 的 `Target` 与 sed 路径；
2. **上游改 Exec 格式需更新 hook**：腾讯若调整 desktop Exec 行结构，sed 匹配失效，需同步更新 `mise/hooks/*.hook` 后重跑 `mise run hooks`；
3. **系统级 desktop 不进 git**：由 hook 维护；git 里的用户级副本是软链接源头；
4. **elephant 其余配置**（`calc.toml`、`symbols.toml`、`menus/`）尚未接管，需要时按同模式放入 `dotfiles/.config/elephant/`。
