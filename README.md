# Termux Stage 1（tx11start / Termux:X11）

这是一个“只做环境就绪”的一键脚本（Stage 1）：

- `pkg update/upgrade`
- 安装：`nodejs`、`git`、`termux-api`
- 全局安装：`openai`、`@openai/codex`
- 引导安装 **Termux Desktop（sabamdarif/termux-desktop）**，目标是 `Termux:X11 + tx11start`

> Stage 2（motd/zsh/键位/DeepSeek 定制复原）不在这个仓库里。

## 使用

```bash
bash stage1-prereqs.sh
```

建议第一次先用“可观察模式”（更多停顿/方便截图）：

```bash
PAUSE_LEVEL=2 bash stage1-prereqs.sh
```

## 常用参数（环境变量）

- 精简安装桌面：`DESKTOP_LITE=1 bash stage1-prereqs.sh`
- 自动跳过确认：`AUTO_YES=1 bash stage1-prereqs.sh`
- 只装 Node/Codex 不装桌面：`INSTALL_DESKTOP=0 bash stage1-prereqs.sh`
- 只打印不执行（用于预览）：`DRY_RUN=1 bash stage1-prereqs.sh`
- 重试次数：`RETRY_MAX=6 bash stage1-prereqs.sh`

日志默认写到：`~/longgu-stage1.log`

## Termux Desktop 安装时的建议选择

为了“尽量复刻当前那台手机的安装结果”，安装器里请严格按下列选择（建议先截图）：

1) Select Install Type：`1. Custom`
2) Select Desktop Environment：`1. XFCE`
3) Select Style：`1 (Basic Style)`
4) Browser：`2. chromium`
5) IDE：`1. VS Code`
6) Media Player：`2. Mpv`
7) Photo Editor：`1. Gimp`
8) Wine：`1. Native`
9) Hardware Acceleration：`n`
10) Extra Wallpapers (1GB+)：`n`
11) Shell：`1. Zsh + zinit`
12) Zsh Theme：`2. Powerlevel10k`
13) Terminal Utilities：`y`
14) Nerd Font：`Meslo`
15) File Manager Tools Enhancement：`y`
16) GUI Mode：`1. Termux:x11`（不要选 Both）
17) Desktop autostart at Termux startup：`n`
18) Linux container：`n`

提示：
- 图形异常时：启动用 `tx11start --nogpu` 或 `tx11start --legacy`
- 硬件加速当前按“禁用”复刻；后续你要追求性能再单独开（避免新机型/ROM 兼容坑）。
