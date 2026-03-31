# Termux 界面定制 Stage 1

目标：准备 Termux Desktop 的基础环境。

使用前请先安装以下 App：

1. Termux
2. Termux:API
3. Termux:X11

建议优先使用 GitHub 版本。

运行步骤：

1. 打开 Termux
2. 安装 git
   `pkg update -y && pkg install -y git`
3. clone 脚本
   `git clone https://github.com/jiangshanyao2200-hue/longgu-termux-kit-step1`
4. 进入目录
   `cd ~/longgu-termux-kit-step1`
5. 运行脚本
   `bash stage1-prereqs.sh`

脚本当前会做这些事：

- 更新系统包
- 安装基础依赖：`git`、`curl`、`ca-certificates`、`termux-api`、`termux-tools`
- 启用 `x11-repo` 和 `tur-repo`
- 下载并运行上游 `termux-desktop` 安装器

脚本不会再自动安装 OpenAI 或 Codex。

安装完成后可执行：

`tx11start`
