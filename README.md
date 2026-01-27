# Termux 界面定制 Stage 1

目标：将您的termux快速升级强化
使用前必备termux，termuxapi，termuxtx11，termuxstyling，均在github。本脚本只协助做快速安装和部署，非本人开发。

官方为termux，termuxdesktop。

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

> Stage 2（AI termux强化）:

不在这个仓库里，正在开发


## Termux Desktop 安装时的建议选择

日志默认写到：`~/longgu-stage1.log`

Ternux destktop安装器选项说明：

 您可以进行自由选择

 选择中有不懂的可以咨询AI

 这些配置通常是关于desktop的：

 ●软件集成

 ●壁纸选择

 ●硬件加速

 ●主题配置

 ●字体选择

推荐选项

1 安装类型 选3 Generic With Hardware Acceleration（开启硬件加速），根据处理器决定。

2 桌面环境 选1 xfce

3 桌面风格 选5 modern style（现代风格）

快速全面自动


另外


如果在选项1你选择了 custom 自定义

则会包含大量自定义选项

Select Install Type：1. Custom

Select Desktop Environment：1. XFCE （推荐）

Select Style：1 (Basic Style) or 5 （modern）（桌面风格 1极简5现代化）

Browser：（浏览器）

IDE：（开发工具）

Media Player：（视频播放器）

Photo Editor：（图片编辑器）

Wine：扩展系统（如Windows）

Hardware Acceleration：（硬件加速）

Extra Wallpapers (1GB+)：（更多壁纸）

Shell：1. Zsh + zinit（termux美化 推荐1）

Zsh Theme：2. Powerlevel10k（推荐2）

Terminal Utilities：y（增强工具包推荐y）

Nerd Font：字体（推荐MesloLGS NF）

File Manager Tools Enhancement：y（推荐y）

GUI Mode：1. Termux:x11（不要选Both推荐x11）

Desktop autostart at Termux startup：n（不要自启动 选n）

Linux container：Linux容器（推荐n 需要自己再装）
 
提示：
- tx11start进入xfce桌面
- 图形异常时：启动用 `tx11start --nogpu` 或 `tx11start --legacy`
- 硬件加速当前按“禁用”复刻；后续你要追求性能再单独开（避免新机型/ROM 兼容坑）。