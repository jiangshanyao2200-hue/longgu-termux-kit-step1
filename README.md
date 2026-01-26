# Termux 界面定制 Stage 1

目标：将您的termux快速升级强化

1️⃣ 安装termux进入

2️⃣ 安装git
`pkg update -y && pkg install -y git`

3️⃣ clone 脚本
`git clone https://github.com/jiangshanyao2200-hue/longgu-termux-kit-step1`

4️⃣ 进入目录
`cd ~/longgu-termux-kit-step1`

5️⃣ 运行脚本
`bash stage1-prereqs.sh`


>Stage 1：

- `pkg update/upgrade`
- 安装：`nodejs`、`git`、`termux-api`
- 全局安装：`openai`、`@openai/codex`
- 引导安装 **Termux Desktop（sabamdarif/termux-desktop）**，目标是 `Termux:X11 + tx11start`

> Stage 2（motd/zsh/键位/DeepSeek 定制复原）
不在这个仓库里。


## Termux Desktop 安装时的建议选择

日志默认写到：`~/longgu-stage1.log`

安装器里请严格按下列选择：

说明：如果您不准备使用我们定制的主题（step2）
 您可以进行自由选择
 选择中有不懂的可以咨询任意AI
 这些配置通常是关于desktop的：
 ●软件集成
 ●壁纸选择
 ●硬件加速
 ●主题配置
 ●字体选择
 
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

## 安装完成后

 “Stage 1 完成” 后：重启进入

  Powerlevel10k 配置向导：

- 运行 `p10k configure`

- 推荐选择或按需选择：
  - Nerd Font v3 + Powerline
  - Large icons
  - Unicode
  - Lean
  - 12h time
  - 2 line
  - Compact
  - Few icons / Concise
  - Transient prompt：On
  - Instant prompt：Verbose（如遇兼容问题可关）
