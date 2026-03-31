#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Stage 1: 只负责“环境就绪”
# - pkg upgrade
# - 安装基础依赖
# - 安装并引导用户完成 Termux Desktop（建议使用 sabamdarif/termux-desktop）
#
# 设计目标：可重复执行；关键节点暂停让用户手动检查/确认。

DRY_RUN="${DRY_RUN:-0}"                   # 1: 只打印不执行
AUTO_YES="${AUTO_YES:-0}"                # 1: 自动继续，不停留确认
INSTALL_DESKTOP="${INSTALL_DESKTOP:-1}"  # 0: 跳过桌面安装
DESKTOP_LITE="${DESKTOP_LITE:-0}"        # 1: termux-desktop 走 LITE 模式
RETRY_MAX="${RETRY_MAX:-4}"              # 网络/源偶发抖动时会救命
RETRY_SLEEP_S="${RETRY_SLEEP_S:-3}"
PAUSE_LEVEL="${PAUSE_LEVEL:-1}"          # 0: 少停顿  1: 关键节点停顿(默认)  2: 更多停顿
LOG_FILE="${LOG_FILE:-$HOME/longgu-stage1.log}"
DESKTOP_INSTALLER_SOURCE="${DESKTOP_INSTALLER_SOURCE:-curl}" # curl|git|auto
STEP_INDEX=0
STEP_TOTAL=0
CACHE_DIR="${HOME}/.cache/longgu-stage1"
UPSTREAM_CACHE_DIR="${CACHE_DIR}/termux-desktop-upstream"
TMP_INSTALLER=""
DESKTOP_INSTALLER_URL="https://raw.githubusercontent.com/sabamdarif/termux-desktop/main/setup-termux-desktop"
DESKTOP_UPSTREAM_REPO="https://github.com/sabamdarif/termux-desktop.git"
TERMUX_APP_URL="https://github.com/termux/termux-app/releases"
TERMUX_API_URL="https://github.com/termux/termux-api/releases"
TERMUX_X11_URL="https://github.com/termux/termux-x11/releases"
BASE_PACKAGES=(git curl ca-certificates termux-api termux-tools)

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
die() { say "${C_RED}${C_BOLD}[FAIL] $*${C_RST}" >&2; exit 1; }

repeat_char() {
  local ch="$1"
  local count="$2"
  local out=""
  while (( ${#out} < count )); do
    out="${out}${ch}"
  done
  printf "%s" "${out:0:count}"
}

progress_bar() {
  local current="$1"
  local total="$2"
  local width=10
  local filled=0
  local empty
  if (( total > 0 )); then
    filled=$(( current * width / total ))
  fi
  (( filled > width )) && filled=$width
  empty=$(( width - filled ))
  printf "[%s%s]" "$(repeat_char "=" "$filled")" "$(repeat_char "." "$empty")"
}

info() { say "${C_CYN}${C_BOLD}[INFO]${C_RST} $*"; }
warn() { say "${C_YLW}${C_BOLD}[WARN]${C_RST} $*"; }
ok() { say "${C_GRN}${C_BOLD}[ OK ]${C_RST} $*"; }
skip() { say "${C_DIM}${C_BOLD}[SKIP]${C_RST} $*"; }
run_msg() { say "${C_CYN}${C_BOLD}[RUN ]${C_RST} $*"; }
item() { say "  - $*"; }
is_enabled() { [[ "${1:-0}" == "1" ]]; }

validate_bool_flag() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[01]$ ]] || die "${name} 仅支持 0 或 1，当前值：${value}"
}

validate_uint_range() {
  local name="$1"
  local value="$2"
  local min="$3"
  local max="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || die "${name} 必须是整数，当前值：${value}"
  (( value >= min && value <= max )) || die "${name} 必须在 ${min}-${max} 之间，当前值：${value}"
}

validate_env_settings() {
  validate_bool_flag "DRY_RUN" "$DRY_RUN"
  validate_bool_flag "AUTO_YES" "$AUTO_YES"
  validate_bool_flag "INSTALL_DESKTOP" "$INSTALL_DESKTOP"
  validate_bool_flag "DESKTOP_LITE" "$DESKTOP_LITE"
  validate_uint_range "RETRY_MAX" "$RETRY_MAX" 1 20
  validate_uint_range "RETRY_SLEEP_S" "$RETRY_SLEEP_S" 0 120
  validate_uint_range "PAUSE_LEVEL" "$PAUSE_LEVEL" 0 2
  [[ -n "$LOG_FILE" ]] || die "LOG_FILE 不能为空。"
  case "$DESKTOP_INSTALLER_SOURCE" in
    auto|curl|git) ;;
    *) die "DESKTOP_INSTALLER_SOURCE 仅支持 auto、curl、git，当前值：${DESKTOP_INSTALLER_SOURCE}" ;;
  esac
}

prepare_log_file() {
  local log_dir
  log_dir="$(dirname "$LOG_FILE")"
  mkdir -p "$log_dir" 2>/dev/null || true
  : >"$LOG_FILE" 2>/dev/null || true
}

prepare_cache_dir() {
  mkdir -p "$CACHE_DIR" || die "无法创建缓存目录：$CACHE_DIR"
}

prepare_runtime() {
  prepare_cache_dir
  prepare_log_file
}

prepare_temp_installer() {
  prepare_cache_dir
  if (( DRY_RUN )); then
    TMP_INSTALLER="${CACHE_DIR}/setup-termux-desktop.dryrun"
    return 0
  fi
  TMP_INSTALLER="$(mktemp "${CACHE_DIR}/setup-termux-desktop.XXXXXX")" || die "无法创建临时安装器文件。"
}

cleanup() {
  if [[ -n "${TMP_INSTALLER:-}" && -e "$TMP_INSTALLER" && "$TMP_INSTALLER" == "$CACHE_DIR"/setup-termux-desktop* ]]; then
    rm -f -- "$TMP_INSTALLER" 2>/dev/null || true
  fi
}

setup_step_total() {
  STEP_INDEX=0
  STEP_TOTAL=5
  if is_enabled "$INSTALL_DESKTOP"; then
    STEP_TOTAL=7
  fi
}

show_overview() {
  say
  info "流程概览："
  item "前置提醒"
  item "环境信息"
  item "更新系统"
  item "安装基础依赖"
  if is_enabled "$INSTALL_DESKTOP"; then
    item "启用仓库"
    item "安装 Termux Desktop"
    item "手动验证"
  else
    item "跳过桌面安装"
  fi
}

show_completion_summary() {
  local desktop_done="${1:-1}"
  say
  say "${C_CYN}${C_BOLD}+------------------------+${C_RST}"
  say "${C_CYN}${C_BOLD}| 完成摘要               |${C_RST}"
  say "${C_CYN}${C_BOLD}+------------------------+${C_RST}"
  info "已完成："
  item "前置检查"
  item "环境信息"
  item "系统更新"
  item "基础依赖"
  if (( desktop_done )); then
    item "仓库启用"
    item "Termux Desktop"
    say
    info "下一步："
    item "command -v tx11start"
    item "tx11start"
  else
    say
    info "下一步："
    item "如需桌面，重新运行脚本"
    item "bash stage1-prereqs.sh"
  fi
  say
  say "${C_DIM}log: $(basename "$LOG_FILE")${C_RST}"
}

show_help() {
  banner
  show_overview
  say
  info "用法："
  item "bash stage1-prereqs.sh"
  say
  info "常用变量："
  item "DRY_RUN=1 预览流程"
  item "AUTO_YES=1 跳过确认"
  item "INSTALL_DESKTOP=0 只装基础依赖"
  item "DESKTOP_LITE=1 使用 Lite 模式"
  item "PAUSE_LEVEL=2 增加停顿"
  item "RETRY_MAX=6 增加重试次数"
  item "RETRY_SLEEP_S=3 设置重试等待"
  item "LOG_FILE=~/xxx.log 自定义日志"
  item "DESKTOP_INSTALLER_SOURCE=auto|curl|git"
  say
  info "说明："
  item "Termux Desktop 使用上游安装器"
  item "目标环境为 Termux:X11 + tx11start"
}

banner() {
  local desktop_mode="standard"
  if is_enabled "$DESKTOP_LITE"; then
    desktop_mode="lite"
  fi
  say "${C_CYN}${C_BOLD}+------------------------+${C_RST}"
  say "${C_CYN}${C_BOLD}| LONGGU STAGE 1         |${C_RST}"
  say "${C_CYN}${C_BOLD}| Termux Desktop Setup   |${C_RST}"
  say "${C_CYN}${C_BOLD}+------------------------+${C_RST}"
  say "${C_DIM}mode: ${desktop_mode}${C_RST}"
  say "${C_DIM}source: ${DESKTOP_INSTALLER_SOURCE}${C_RST}"
  say "${C_DIM}log: $(basename "$LOG_FILE")${C_RST}"
}

section() {
  local bar
  STEP_INDEX=$(( STEP_INDEX + 1 ))
  bar="$(progress_bar "$STEP_INDEX" "$STEP_TOTAL")"
  say
  say "${C_BLU}${C_BOLD}${bar} Step ${STEP_INDEX}/${STEP_TOTAL}${C_RST}"
  say "${C_BOLD}$*${C_RST}"
  say "${C_DIM}$(repeat_char "-" 24)${C_RST}"
}

micro_pause() {
  if (( PAUSE_LEVEL >= 2 )) && (( ! AUTO_YES )); then
    sleep 0.35
  fi
}

pause() {
  local prompt="${1:-按回车继续…}"
  if (( AUTO_YES )); then
    skip "AUTO_YES=1：$prompt"
    log "AUTO_YES skip: $prompt"
    return 0
  fi
  if (( PAUSE_LEVEL <= 0 )); then
    skip "PAUSE_LEVEL=0：$prompt"
    log "PAUSE_LEVEL skip: $prompt"
    return 0
  fi
  read -r -p "$prompt" _ </dev/tty || true
}

need_termux() {
  if [[ -z "${PREFIX:-}" || "$PREFIX" != *"/com.termux/"* ]]; then
    die "请在 Termux 内运行此脚本。"
  fi
}

on_err() {
  local code=$?
  say
  say "${C_RED}${C_BOLD}[FAIL] 脚本退出（code=$code）${C_RST}"
  warn "可直接重跑，常见原因是网络或源抖动。"
  say "${C_DIM}日志：$LOG_FILE${C_RST}"
  exit "$code"
}
trap on_err ERR
trap cleanup EXIT

retry() {
  local max="${1}"; shift
  local sleep_s="${1}"; shift
  local attempt=1
  while true; do
    if (( DRY_RUN )); then
      skip "DRY_RUN: $*"
      log "DRY_RUN: $*"
      return 0
    fi

    run_msg "$*"
    log "RUN: $*"

    set +e
    "$@"
    local rc=$?
    set -e
    if (( rc == 0 )); then
      return 0
    fi
    if (( attempt >= max )); then
      warn "已重试 ${attempt}/${max} 次仍失败。"
      log "FAIL rc=$rc after ${attempt}/${max}: $*"
      return "$rc"
    fi
    warn "失败 rc=$rc，${sleep_s}s 后重试 ${attempt}/${max}。"
    log "RETRY rc=$rc attempt=${attempt}/${max} sleep=${sleep_s}: $*"
    sleep "$sleep_s"
    attempt=$(( attempt + 1 ))
    sleep_s=$(( sleep_s + 2 ))
  done
}

pkg_update_upgrade() {
  section "更新系统"
  info "如果出现确认提示，按提示继续即可。"
  pause "回车开始更新系统… "
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg update -y || retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg update
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg upgrade -y || retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg upgrade
  ok "系统更新完成。"
  micro_pause
}

pkg_install() {
  local pkgs=("$@")
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" pkg install -y "${pkgs[@]}"
}

check_termux_x11_app() {
  section "前置提醒"
  info "先确认已安装以下 App："
  item "Termux（建议 GitHub 版）"
  item "Termux:API"
  item "Termux:X11"
  warn "安装时请保持前台、亮屏、电量充足。"
  say
  info "下载页："
  item "Termux: ${TERMUX_APP_URL}"
  item "Termux:API: ${TERMUX_API_URL}"
  item "Termux:X11: ${TERMUX_X11_URL}"
  say
  pause "安装完成后回车继续… "
}

install_basic_tools() {
  section "安装基础依赖"
  info "将安装 git / curl / termux-api 等组件。"
  pause "准备好就回车继续安装基础依赖… "
  pkg_install "${BASE_PACKAGES[@]}"
  ok "基础依赖安装完成。"
}

manual_repo_check() {
  section "启用仓库"
  pause "回车继续启用仓库… "
  pkg_install x11-repo tur-repo
  say
  info "检查 termux-x11 软件源："
  if (( DRY_RUN )); then
    say "${C_DIM}+ pkg show termux-x11-nightly || pkg search termux-x11${C_RST}"
  else
    (pkg show termux-x11-nightly 2>/dev/null || pkg search termux-x11 2>/dev/null || true)
  fi
  say
  warn "如果源有问题，先运行 ${C_BOLD}termux-change-repo${C_RST}。"
  pause "确认后回车继续安装 Termux Desktop… "
}

fetch_desktop_installer_curl() {
  local installer="$1"
  retry "$RETRY_MAX" "$RETRY_SLEEP_S" curl -fL --connect-timeout 20 --max-time 600 \
    "$DESKTOP_INSTALLER_URL" -o "$installer"
  retry 1 0 chmod +x "$installer"
}

fetch_desktop_installer_git() {
  local installer="$1"
  local dir="$UPSTREAM_CACHE_DIR"
  retry 1 0 mkdir -p "$CACHE_DIR"
  if [[ -d "$dir/.git" ]]; then
    retry "$RETRY_MAX" "$RETRY_SLEEP_S" git -C "$dir" pull --rebase --autostash
  else
    retry "$RETRY_MAX" "$RETRY_SLEEP_S" git clone --depth=1 "$DESKTOP_UPSTREAM_REPO" "$dir"
  fi
  retry 1 0 cp -a "$dir/setup-termux-desktop" "$installer"
  retry 1 0 chmod +x "$installer"
}

install_termux_desktop() {
  section "安装 Termux Desktop"
  info "这一步耗时可能较长。"
  say

  local installer=""
  local start_ts end_ts dur rc
  prepare_temp_installer
  installer="$TMP_INSTALLER"

  while true; do
    if [[ "$DESKTOP_INSTALLER_SOURCE" == "curl" ]]; then
      fetch_desktop_installer_curl "$installer"
    elif [[ "$DESKTOP_INSTALLER_SOURCE" == "git" ]]; then
      fetch_desktop_installer_git "$installer"
    else
      if ! fetch_desktop_installer_curl "$installer"; then
        warn "curl 获取安装器失败，改用 git clone。"
        fetch_desktop_installer_git "$installer"
      fi
    fi

    pause "准备进入 Termux Desktop 安装器。回车继续… "

    start_ts="$(date +%s)"
    rc=0

    if (( DRY_RUN )); then
      if is_enabled "$DESKTOP_LITE"; then
        skip "LITE=1 $installer"
      else
        skip "$installer"
      fi
    else
      set +e
      if is_enabled "$DESKTOP_LITE"; then
        env LITE=1 "$installer"
      else
        "$installer"
      fi
      rc=$?
      set -e
    fi

    end_ts="$(date +%s)"
    dur=$(( end_ts - start_ts ))
    say
    info "Termux Desktop 用时：${dur}s"

    if (( rc == 0 )); then
      ok "Termux Desktop 安装流程结束。"
      return 0
    fi

    warn "Termux Desktop 安装器返回非 0（rc=$rc）。"
    warn "常见原因：网络抖动、镜像源不稳、后台被杀。"
    pause "回车重试一次（或 Ctrl+C 退出稍后再试）… "
  done
}

final_notes() {
  section "手动验证"
  info "安装结束后可执行以下命令检查："
  item "command -v tx11start"
  item "tx11start"
  say
  show_completion_summary 1
  say
  ok "Stage 1 完成。"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    show_help
    return 0
  fi
  validate_env_settings
  need_termux
  prepare_runtime
  setup_step_total
  banner
  show_overview

  check_termux_x11_app

  section "环境信息"
  if command -v termux-info >/dev/null 2>&1; then
    if (( DRY_RUN )); then
      say "${C_DIM}+ termux-info${C_RST}"
    else
      termux-info || true
    fi
  else
    info "未找到 termux-info（可忽略）。"
  fi

  pkg_update_upgrade
  install_basic_tools

  if (( ! INSTALL_DESKTOP )); then
    section "跳过桌面安装"
    info "你设置了 INSTALL_DESKTOP=0：已跳过 Termux Desktop。"
    show_completion_summary 0
    return 0
  fi

  manual_repo_check
  install_termux_desktop
  final_notes
}

main "$@"
