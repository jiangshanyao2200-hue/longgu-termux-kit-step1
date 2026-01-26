#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Stage 1: 只负责“环境就绪”
# - pkg upgrade
# - 安装 nodejs/git/termux-api
# - npm 全局安装 openai 与 @openai/codex
# - 安装并引导用户完成 Termux Desktop（建议使用 sabamdarif/termux-desktop）
#
# 设计目标：可重复执行；关键节点暂停让用户手动检查/确认。

DRY_RUN="${DRY_RUN:-0}"                   # 1: 只打印不执行
AUTO_YES="${AUTO_YES:-0}"                # 1: 自动继续，不停留确认
INSTALL_DESKTOP="${INSTALL_DESKTOP:-1}"  # 0: 跳过桌面安装
DESKTOP_LITE="${DESKTOP_LITE:-0}"        # 1: termux-desktop 走 LITE 模式
RETRY_MAX="${RETRY_MAX:-4}"              # 网络/源偶发抖动时会救命
RETRY_SLEEP_S="${RETRY_SLEEP_S:-3}"
LOG_FILE="${LOG_FILE:-$HOME/longgu-stage1.log}"

if [ -t 1 ] && [ -n "${TERM:-}" ]; then
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GRN=$'\033[32m'
  C_YLW=$'\033[33m'
  C_BLU=$'\033[34m'
  C_CYN=$'\033[36m'
  C_RST=$'\033[0m'
else
  C_DIM=""; C_BOLD=""; C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_CYN=""; C_RST=""
fi

say() { printf "%s\n" "$*"; }
log() { printf "%s %s\n" "$(date +'%F %T')" "$*" >>"$LOG_FILE" 2>/dev/null || true; }

show_help() {
  cat <<'EOF'
Termux Stage 1：基础环境 + Termux Desktop（Termux:X11 / tx11start）

用法：
  bash stage1-prereqs.sh

常用参数（环境变量）：
  DRY_RUN=1            只打印不执行（预览流程）
  AUTO_YES=1           跳过所有“回车确认”
  INSTALL_DESKTOP=0    不安装 Termux Desktop，只装 Node/Codex
  DESKTOP_LITE=1       termux-desktop 使用 Lite 模式（更快更省）
  RETRY_MAX=6          失败最大重试次数（默认 4）
  RETRY_SLEEP_S=3      首次重试等待秒数（默认 3，会逐次递增）
  LOG_FILE=~/xxx.log   指定日志文件（默认 ~/longgu-stage1.log）

说明：
  - Termux Desktop 使用上游安装器：sabamdarif/termux-desktop
  - 目标是 Termux:X11 + tx11start（脚本会给出推荐选项）
EOF
}

banner() {
  say "${C_CYN}${C_BOLD}╔══════════════════════════════════════════════════════╗${C_RST}"
  say "${C_CYN}${C_BOLD}║  龙骨 Termux Stage 1：基础环境 + Termux Desktop     ║${C_RST}"
  say "${C_CYN}${C_BOLD}╚══════════════════════════════════════════════════════╝${C_RST}"
  say "${C_DIM}日志：$LOG_FILE${C_RST}"
}

section() {
  say
  say "${C_BLU}${C_BOLD}== $* ==${C_RST}"
}

pause() {
  local prompt="${1:-按回车继续…}"
  if (( AUTO_YES )); then
    say "${C_DIM}[stage1] AUTO_YES=1：跳过确认：$prompt${C_RST}"
    log "AUTO_YES skip: $prompt"
    return 0
  fi
  read -r -p "$prompt" _ </dev/tty || true
}

need_termux() {
  if [[ -z "${PREFIX:-}" || "$PREFIX" != *"/com.termux/"* ]]; then
    say "${C_RED}[stage1] 请在 Termux 内运行此脚本。${C_RST}" >&2
    exit 1
  fi
}

on_err() {
  local code=$?
  say
  say "${C_RED}${C_BOLD}[stage1] 出错退出（code=$code）。${C_RST}"
  say "${C_YLW}你可以直接重跑脚本；多数失败来自网络/源抖动，重试通常可恢复。${C_RST}"
  say "${C_DIM}日志：$LOG_FILE${C_RST}"
  exit "$code"
}
trap on_err ERR

retry() {
  local max="${1}"; shift
  local sleep_s="${1}"; shift
  local attempt=1
  while true; do
    if (( DRY_RUN )); then
      say "${C_DIM}+ $*${C_RST}"
      log "DRY_RUN: $*"
      return 0
    fi

    say "${C_CYN}+ $*${C_RST}"
    log "RUN: $*"

    set +e
    "$@"
    local rc=$?
    set -e
    if (( rc == 0 )); then
      return 0
    fi
    if (( attempt >= max )); then
      say "${C_RED}[retry] 已重试 ${attempt}/${max} 次仍失败：$*${C_RST}"
      log "FAIL rc=$rc after ${attempt}/${max}: $*"
      return "$rc"
    fi
    say "${C_YLW}[retry] 失败（rc=$rc），${sleep_s}s 后重试 ${attempt}/${max}…${C_RST}"
    log "RETRY rc=$rc attempt=${attempt}/${max} sleep=${sleep_s}: $*"
    sleep "$sleep_s"
    attempt=$(( attempt + 1 ))
    sleep_s=$(( sleep_s + 2 ))
  done
}

pkg_update_upgrade() {
  section "更新系统（pkg update/upgrade）"
  say "这一步很慢很正常：它在为后续安装“铺路”。保持屏幕常亮、网络稳定即可。"
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg update -y || retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg update
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg upgrade -y || retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg upgrade
  say "${C_GRN}[ok] 系统更新完成。${C_RST}"
}

pkg_install() {
  local pkgs=("$@")
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg install -y "${pkgs[@]}"
}

npm_global_has() {
  local name="$1"
  if ! command -v npm >/dev/null 2>&1; then
    return 1
  fi
  npm -g ls --depth=0 "$name" >/dev/null 2>&1
}

npm_global_install() {
  local name="$1"
  if npm_global_has "$name"; then
    say "${C_DIM}[skip] npm 已存在：$name${C_RST}"
    return 0
  fi
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" npm i -g "$name"
}

check_termux_x11_app() {
  # sabamdarif 安装器里也会检查并提示下载链接，这里提前温柔提醒一次。
  section "前置提醒（Termux:X11 / Phantom Process Killer）"
  say "建议先确认："
  say "  1) Termux 来自 GitHub/F-Droid（不要 Play 版）"
  say "  2) 已安装 Termux:API 与 Termux:X11（APK）"
  say "  3) Android 12+ 建议关闭 Phantom Process Killer（否则桌面可能被杀）"
  say
  if command -v pm >/dev/null 2>&1; then
    if pm list packages 2>/dev/null | grep -q '^package:com.termux.x11$'; then
      say "${C_GRN}[ok] 检测到已安装：com.termux.x11${C_RST}"
    else
      say "${C_YLW}[提示] 未检测到 com.termux.x11（你仍可继续安装，但后面需要手动装 APK）。${C_RST}"
      say "  下载页：https://github.com/termux/termux-x11/releases"
    fi
  else
    say "${C_DIM}[info] 无法通过 pm 检测 APK（可忽略）。${C_RST}"
  fi
  pause "确认无误后回车继续（或 Ctrl+C 退出先处理）… "
}

install_node_and_tools() {
  section "安装基础依赖（nodejs/git/termux-api 等）"
  pkg_install git curl ca-certificates nodejs python termux-api termux-tools

  section "校验 Node/NPM"
  retry 1 0 node -v
  retry 1 0 npm -v

  section "安装 OpenAI / Codex（npm 全局）"
  say "说明：openai 通常是“项目依赖”，但你需要一键安装，这里按全局安装处理。"
  npm_global_install openai
  npm_global_install @openai/codex

  section "校验 codex"
  if (( DRY_RUN )); then
    say "${C_DIM}+ command -v codex && (codex --version || codex --help)${C_RST}"
  else
    command -v codex >/dev/null
    (codex --version 2>/dev/null || codex --help >/dev/null) || true
  fi
  say "${C_GRN}[ok] Node/OpenAI/Codex 就绪。${C_RST}"
}

manual_repo_check() {
  section "Termux Desktop 前：启用仓库并手动测试源"
  say "这一步的核心：确保 x11-repo/tur-repo 的源顺畅，否则后面会非常折磨。"
  pkg_install x11-repo tur-repo
  say
  say "建议你手动确认：termux-x11-nightly 是否能被找到（代表源 OK）。"
  if (( DRY_RUN )); then
    say "${C_DIM}+ pkg show termux-x11-nightly || pkg search termux-x11${C_RST}"
  else
    (pkg show termux-x11-nightly 2>/dev/null || pkg search termux-x11 2>/dev/null || true)
  fi
  say
  say "如果下载慢/报错：先运行 ${C_BOLD}termux-change-repo${C_RST} 选一个更快的镜像，然后再回来继续。"
  pause "源没问题就回车继续安装 Termux Desktop（或 Ctrl+C 退出先改源）… "
}

desktop_choice_tips() {
  section "Termux Desktop 安装建议（你在安装器里这样选）"
  say "你要的是 Termux:X11 + tx11start 这套，我建议："
  say "  1) GUI Mode：选 ${C_BOLD}Termux:x11（不要选 Both）${C_RST}"
  say "  2) Desktop/WM：选 ${C_BOLD}XFCE${C_RST}（兼容性最好、也最接近你现在的环境）"
  if (( DESKTOP_LITE )); then
    say "  3) 你当前设置 DESKTOP_LITE=1：会走“Lite Install”（更快、更省空间）"
  else
    say "  3) 如果你是新机/空间紧张：建议先用 ${C_BOLD}Lite Install${C_RST}；跑通后再补装可选项"
  fi
  say
  say "桌面装好后常用命令（安装器会创建）："
  say "  - tx11start            启动（默认）"
  say "  - tx11start --nogpu    兼容优先（图形异常时）"
  say "  - tx11start --legacy   兼容优先（绘制问题时）"
  say "  - tx11stop             停止"
  pause "记住这些建议后回车开始安装（会很久）… "
}

install_termux_desktop() {
  section "安装 Termux Desktop（sabamdarif/termux-desktop）"
  say "提示：这一步会下载大量包/配置，通常是“最长的一段路”。"
  say "建议：Wi‑Fi + 充电 + 屏幕常亮；中途失败不用慌，重跑即可续上。"
  say

  local installer="$HOME/setup-termux-desktop"
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" curl -fL --connect-timeout 20 --max-time 600 \
    "https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/setup-termux-desktop" -o "$installer"
  retry 1 0 chmod +x "$installer"

  local start_ts end_ts
  start_ts="$(date +%s)"

  local rc=0
  if (( DRY_RUN )); then
    if (( DESKTOP_LITE )); then
      say "${C_DIM}+ LITE=1 $installer${C_RST}"
    else
      say "${C_DIM}+ $installer${C_RST}"
    fi
  else
    set +e
    if (( DESKTOP_LITE )); then
      env LITE=1 "$installer"
    else
      "$installer"
    fi
    rc=$?
    set -e
  fi

  end_ts="$(date +%s)"
  local dur=$(( end_ts - start_ts ))
  say
  say "${C_DIM}[stage1] Termux Desktop 用时：${dur}s${C_RST}"

  if (( rc != 0 )); then
    say "${C_YLW}[stage1] Termux Desktop 安装器返回非 0（rc=$rc）。${C_RST}"
    say "常见原因：网络抖动/镜像源不稳/Android 杀后台。"
    pause "回车重试一次（或 Ctrl+C 退出稍后再试）… "
    install_termux_desktop
    return 0
  fi

  say "${C_GRN}[ok] Termux Desktop 安装流程结束。${C_RST}"
}

final_notes() {
  section "下一步（手动验证）"
  say "建议按顺序验证："
  say "  1) ${C_BOLD}command -v tx11start${C_RST}"
  say "  2) ${C_BOLD}tx11start${C_RST}（如果显示异常：试试 --nogpu 或 --legacy）"
  say "  3) ${C_BOLD}codex --help${C_RST}"
  say
  say "${C_GRN}Stage 1 完成。等你确认桌面能正常启动，我们再进入 Stage 2：恢复 motd/zsh/键位/定制 deepseek。${C_RST}"
}

main() {
  need_termux
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    show_help
    return 0
  fi
  : >"$LOG_FILE" 2>/dev/null || true
  banner

  check_termux_x11_app

  section "环境信息（供你确认架构/版本）"
  if command -v termux-info >/dev/null 2>&1; then
    if (( DRY_RUN )); then
      say "${C_DIM}+ termux-info${C_RST}"
    else
      termux-info || true
    fi
  else
    say "${C_DIM}[info] 未找到 termux-info（可忽略）。${C_RST}"
  fi

  pkg_update_upgrade
  install_node_and_tools

  if (( ! INSTALL_DESKTOP )); then
    section "跳过桌面安装"
    say "你设置了 INSTALL_DESKTOP=0：到这里结束。"
    final_notes
    return 0
  fi

  manual_repo_check
  desktop_choice_tips
  install_termux_desktop
  final_notes
}

main "$@"
