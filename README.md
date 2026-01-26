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

## 常用参数（环境变量）

- 精简安装桌面：`DESKTOP_LITE=1 bash stage1-prereqs.sh`
- 自动跳过确认：`AUTO_YES=1 bash stage1-prereqs.sh`
- 只装 Node/Codex 不装桌面：`INSTALL_DESKTOP=0 bash stage1-prereqs.sh`
- 只打印不执行（用于预览）：`DRY_RUN=1 bash stage1-prereqs.sh`
- 重试次数：`RETRY_MAX=6 bash stage1-prereqs.sh`

日志默认写到：`~/longgu-stage1.log`

## Termux Desktop 安装时的建议选择

- GUI Mode：选 `Termux:x11`（不要选 Both）
- Desktop/WM：选 `XFCE`
- 图形异常时：启动用 `tx11start --nogpu` 或 `tx11start --legacy`

