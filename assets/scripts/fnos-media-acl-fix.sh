#!/bin/sh
# fnos-media-acl-fix.sh —— 修复 fnOS 文件授权导致飞鲸影视服务端无法读取媒体目录/文件的问题
#
# 模式：
#   不带任何参数运行  → 进入交互菜单，按编号选择操作
#   带参数运行        → 按参数直接执行（适用于脚本或批量处理）
#
# 用法：
#   fnos-media-acl-fix.sh [-u USER] [-n] [-m MODE] [-d DIR]... [-f PATH]...
#   fnos-media-acl-fix.sh [-u USER] -l
#   fnos-media-acl-fix.sh [-u USER] -i
#   fnos-media-acl-fix.sh -h
#
# 选项：
#   -u USER   服务端运行账户（默认自动识别；未识别到时为 FlyNarwhalDev）
#   -l        仅检测：列出服务端无法访问的目录/文件，不做任何修改
#   -i        手动输入：逐行输入待处理的目录/文件路径，空行结束
#   -m MODE   修复方式，默认 auto
#               auto  = 先清除 fnOS 授权属性；仍不可访问时再为服务端账户追加读取 ACL
#               strip = 仅清除 fnOS 授权属性（不修改 POSIX ACL，会丢失 fnOS 共享记录）
#               acl   = 仅为服务端账户追加读取 ACL（不修改 fnOS 授权属性）
#   -n        预演：打印将要执行的操作，不产生任何修改
#   -v        输出每个被检查条目的结果（默认只输出无法访问的条目）
#   -h        显示本帮助
#
# 涉及的 fnOS 扩展属性：
#   system.trim_acl   文件授权记录；记录中未包含服务端账户时，除属主外均无法访问
#   user.trim-share   共享标记
#   user.trim_acl     由非特权账户写入的同类授权记录
#
# 退出码：0 全部可访问或已修复；1 仍存在无法访问的条目，或参数有误。
# 需以 root 运行；依赖 attr 包的 getfattr/setfattr 及 acl 包的 setfacl。

set -u

TRIM_ACL='system.trim_acl'
TRIM_SHARE='user.trim-share'
TRIM_ACL_USER='user.trim_acl'

# 飞鲸影视服务端以 fnOS 应用账户身份运行。正式版与开发版的应用名不同，
# 下列候选按优先级排列，取系统中实际存在的第一个。
APP_USER_CANDIDATES='App.Native.flyNarwhalServer FlyNarwhalDev'
APP_USER=''
APP_USER_EXPLICIT=0

MODE='auto'
DRY_RUN=0
LIST_ONLY=0
INTERACTIVE=0
VERBOSE=0
DIRS=''
FILES=''
HAS_ARGS=0

usage() {
    awk 'NR == 1 { next }
         /^#/ { sub(/^# ?/, ""); print; next }
         { exit }' "$0"
    exit "${1:-0}"
}

while getopts 'u:lid:f:nm:vh' opt; do
    case "$opt" in
        u) APP_USER=$OPTARG; APP_USER_EXPLICIT=1; HAS_ARGS=1 ;;
        l) LIST_ONLY=1; HAS_ARGS=1 ;;
        i) INTERACTIVE=1; HAS_ARGS=1 ;;
        d) DIRS="$DIRS
$OPTARG"; HAS_ARGS=1 ;;
        f) FILES="$FILES
$OPTARG"; HAS_ARGS=1 ;;
        n) DRY_RUN=1; HAS_ARGS=1 ;;
        m) MODE=$OPTARG; HAS_ARGS=1 ;;
        v) VERBOSE=1; HAS_ARGS=1 ;;
        h) usage 0 ;;
        *) usage 1 ;;
    esac
done
shift $((OPTIND - 1))

case "$MODE" in
    auto|strip|acl) ;;
    *) echo "错误：-m 仅支持 auto / strip / acl" >&2; exit 1 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请以 root 运行（需切换为服务端账户做访问校验，并修改其他账户的文件）" >&2
    exit 1
fi

command -v getfattr >/dev/null 2>&1 || { echo "错误：缺少 getfattr（attr 包）" >&2; exit 1; }
command -v setfattr >/dev/null 2>&1 || { echo "错误：缺少 setfattr（attr 包）" >&2; exit 1; }
command -v setfacl >/dev/null 2>&1 || { echo "错误：缺少 setfacl（acl 包）" >&2; exit 1; }

# ── 账户识别 ────────────────────────────────────────────────────────────

# 正式版在 fnOS 应用中心里显示为「飞鲸影视」，应用名为 App.Native.flyNarwhalServer。
# 系统账户名并不一定是应用名，因此依次尝试：运行中的服务端进程所属账户、
# 应用名对应的账户、开发版账户。
# 仅采信位于 /var/apps/ 或 /usr/local/apps/ 下、由 fnOS 应用中心托管的进程；
# 手动在终端里跑的调试实例（例如 /vol2/.../native-release）可能以 admin 运行，
# 不能代表正式安装后的服务端账户。
detect_app_user() {
    found=0
    for pid in $(pgrep -f 'fly-narwhal-server'); do
        cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
        # 服务端以相对路径 ./fly-narwhal-server-X 启动，进程名里没有目录，
        # 因此按工作目录判断是否由 fnOS 应用中心托管
        cwd=$(link=$(readlink "/proc/$pid/cwd" 2>/dev/null); printf '%s' "$link")
        case "$cmd $cwd" in
            *" /var/apps/"*|*" /usr/local/apps/"*) ;;
            *) continue ;;
        esac
        found=1
        owner=$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$owner" ] && id "$owner" >/dev/null 2>&1; then
            echo "$owner"
            return 0
        fi
    done
    [ "$found" -eq 1 ] && return 1
    for name in $APP_USER_CANDIDATES; do
        if id "$name" >/dev/null 2>&1; then
            echo "$name"
            return 0
        fi
    done
    echo 'FlyNarwhalDev'
}

if [ "$APP_USER_EXPLICIT" -eq 0 ]; then
    APP_USER=$(detect_app_user) || {
        echo "未能从运行中的服务端进程识别账户（进程名不含安装目录），"
        echo "请确认飞鲸影视服务端已安装并运行，或用 -u 指定账户。"
        exit 1
    }
fi

if ! id "$APP_USER" >/dev/null 2>&1; then
    echo "错误：系统中不存在账户 $APP_USER，可用 -u 指定服务端运行账户" >&2
    exit 1
fi

# ── 访问校验 ────────────────────────────────────────────────────────────

can_list() {
    su -s /bin/sh "$APP_USER" -c 'ls "$1" >/dev/null 2>&1' sh "$1"
}
can_read_file() {
    su -s /bin/sh "$APP_USER" -c 'test -r "$1"' sh "$1"
}
is_dir() { [ -d "$1" ]; }

has_attr() {
    getfattr -n "$2" -m- "$1" 2>/dev/null | grep -q "^$2="
}

has_trim_marker() {
    has_attr "$1" "$TRIM_ACL" || has_attr "$1" "$TRIM_SHARE" || has_attr "$1" "$TRIM_ACL_USER"
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    [预演] $1 ${2:-} ${3:-}"
    else
        "$@" || echo "    警告：命令执行失败：$*" >&2
    fi
}

accessible() {
    if is_dir "$1"; then can_list "$1"; else can_read_file "$1"; fi
}

# 检测并在需要时修复一个路径：$1 路径，$2 来源说明
check_path() {
    path=$1
    origin=$2

    if [ ! -e "$path" ]; then
        echo "跳过（路径不存在）：$path  [$origin]"
        return 2
    fi
    if accessible "$path"; then
        [ "$VERBOSE" -eq 1 ] && echo "正常：$path"
        return 0
    fi

    reported=$((reported + 1))
    echo "无法访问：$path  [$origin]"
    if has_trim_marker "$path"; then
        echo "  原因：该条目带有 fnOS 文件授权记录（由上级目录继承），服务端账户不在授权范围内"
    else
        echo "  原因：权限不足——属主为其他账户，且服务端账户未被授予读取权限"
    fi

    [ "$LIST_ONLY" -eq 1 ] && return 1

    if [ "$MODE" = 'auto' ] || [ "$MODE" = 'strip' ]; then
        for attr in "$TRIM_ACL" "$TRIM_SHARE" "$TRIM_ACL_USER"; do
            if has_attr "$path" "$attr"; then
                echo "  清除 fnOS 授权属性 $attr"
                run setfattr -x "$attr" "$path"
            fi
        done
        if [ "$DRY_RUN" -eq 0 ] && accessible "$path"; then
            echo "  结果：已恢复访问"
            resolved=$((resolved + 1))
            return 0
        fi
        if [ "$MODE" = 'strip' ]; then
            echo "  结果：清除授权属性后仍无法访问；strip 模式不修改普通权限，请改用 auto 或 acl"
            return 1
        fi
    fi

    # auto / acl：文件通常因上级目录不可进入而无法读取，先确保上级可访问
    parent=$(dirname "$path")
    if ! can_list "$parent"; then
        echo "  上级目录亦不可进入：$parent（优先处理）"
        check_path "$parent" "上级目录" || true
    fi
    if is_dir "$path"; then
        echo "  为服务端账户 $APP_USER 追加读取及进入权限（ACL）"
        run setfacl -m "u:$APP_USER:rx" "$path"
    else
        echo "  为服务端账户 $APP_USER 追加读取权限（ACL）"
        run setfacl -m "u:$APP_USER:r" "$path"
    fi
    if [ "$DRY_RUN" -eq 0 ] && accessible "$path"; then
        echo "  结果：已恢复访问"
        resolved=$((resolved + 1))
        return 0
    fi
    echo "  结果：仍无法访问。请在 fnOS「文件管理」中为该目录授权："
    echo "        属性 → 文件授权/共享权限 → 添加「飞鲸影视」→ 允许读取"
    return 1
}

note_result() {
    rc=$1
    if [ "$rc" -eq 1 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            dry_fail=$((dry_fail + 1))
        else
            fail=$((fail + 1))
        fi
    fi
}

# 递归遍历子目录，仅处理无法访问的条目（授权记录会继承到子项）
walk_tree() {
    dir=$1
    rc=0
    can_list "$dir" || rc=$?
    if [ "$rc" -ne 0 ]; then
        rc=0
        check_path "$dir" "子目录" || rc=$?
        note_result "$rc"
        accessible "$dir" || return 0
    fi
    for entry in "$dir"/* "$dir"/.[!.]*; do
        [ -e "$entry" ] || continue
        if [ -d "$entry" ]; then
            walk_tree "$entry"
        elif ! accessible "$entry"; then
            rc=0
            check_path "$entry" "子文件" || rc=$?
            note_result "$rc"
        fi
    done
}

# 扫描一个媒体根目录：先逐项检查顶层，再递归检查子目录
scan_root() {
    root=$1
    if [ ! -d "$root" ]; then
        echo "跳过（不是目录）：$root"
        return 0
    fi
    if ! can_list "$root"; then
        rc=0
        check_path "$root" "根目录" || rc=$?
        note_result "$rc"
    fi
    found=0
    for entry in "$root"/* "$root"/.[!.]*; do
        [ -e "$entry" ] || continue
        found=$((found + 1))
        rc=0
        check_path "$entry" "扫描 $root" || rc=$?
        note_result "$rc"
    done
    if [ "$LIST_ONLY" -eq 0 ]; then
        for entry in "$root"/* "$root"/.[!.]*; do
            [ -d "$entry" ] || continue
            walk_tree "$entry"
        done
    fi
    [ "$VERBOSE" -eq 1 ] && echo "已检查 $found 个顶层条目：$root"
    return 0
}

fail=0
dry_fail=0
reported=0
resolved=0
checked=0
status=0

reset_counters() {
    fail=0; dry_fail=0; reported=0; resolved=0; checked=0; status=0
}

# 输出本次运行小结
summarize() {
    unresolved=0
    if [ "$LIST_ONLY" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
        [ "$reported" -gt "$resolved" ] && unresolved=$((reported - resolved))
    else
        unresolved=$fail
    fi
    if [ "$status" -eq 0 ] && [ "$unresolved" -gt 0 ]; then status=1; fi

    if [ "$status" -eq 0 ]; then
        if [ "$reported" -eq 0 ]; then
            echo "完成：已检查 $checked 个目标，均可访问，无需修复。"
        else
            echo "完成：已检查 $checked 个目标，修复 $resolved 处无法访问的条目。"
            echo "      请在客户端中重新执行一次「立即扫描」以确认。"
        fi
    elif [ "$LIST_ONLY" -eq 1 ]; then
        echo "完成：已检查 $checked 个目标，其中 $unresolved 处无法访问（本次仅检测，未做修改）。"
        echo "      可返回菜单选择「自动修复」，或按下列路径逐一处理。"
    else
        echo "完成：已检查 $checked 个目标，其中 $unresolved 处仍无法访问（原因见上方）。"
        echo "      请按提示在 fnOS「文件管理」中为对应目录授权，或更换修复方式后重试。"
    fi
}

# ── 说明文字 ────────────────────────────────────────────────────────────

explain_background() {
    cat <<TXT

──────────────────────── 问题说明 ────────────────────────
 在客户端中，进度条无法显示预览缩略图，或在设置页执行「立即扫描」时提示
 某个目录无法访问，通常并非客户端缺陷，而是 NAS 上的文件权限使飞鲸影视
 服务端账户无法读取影片。

 服务端账户：飞鲸影视服务端以 fnOS 应用账户身份运行（本脚本当前识别为
 $APP_USER）。该账户必须能够进入影片所在目录，并读取其中的视频文件。

 无法访问通常由以下两类原因造成：

 A. fnOS 文件授权记录。在 fnOS 文件管理中为目录设置共享或授权时，fnOS 会
    在该目录及其全部子项上写入授权记录。若记录中未包含服务端账户，服务端
    即无法访问；且记录会继承至子项，因此顶层目录看似正常，其内的子目录与
    文件仍可能无法读取。

 B. 目录属主为其他账户（例如早期入库时创建目录的 trim.text-editor），且权限
    设置为仅属主可访问。服务端账户不属于属主，因而无法进入。

 本脚本分别检查上述两类情况，并以服务端账户的实际访问结果为准：仅在确实
 无法访问时才进行处理，可正常访问的条目不做任何修改。
─────────────────────────────────────────────────────────

──────────────── 修复方式 auto / strip / acl 的区别 ────────────────
 auto（推荐，默认）
   先清除 A 类授权记录；若仍无法访问，再为服务端账户追加 B 类读取权限。
   两种处理均不影响其他账户正常使用该目录。
   注意：清除授权记录后，该目录原有的 fnOS 共享设置会失效，如有需要须在
   fnOS 文件管理中重新设置。

 strip
   仅执行第一步：清除 A 类授权记录，不修改普通权限。
   适用于该目录无需共享、仅授权记录造成阻塞的情况。若清除后仍无法访问
   （属 B 类问题），脚本会提示改用 auto 或 acl。

 acl
   仅执行第二步：为服务端账户追加读取权限，不修改 A 类授权记录。
   对现有 fnOS 共享设置影响最小；但若阻塞原因是授权记录，追加 ACL 后仍
   可能无法访问。

 建议：不确定时使用 auto；不希望现有共享失效时，可先尝试 acl。
       所有操作仅涉及追加权限或清除授权记录，不会删除或修改影片文件。
─────────────────────────────────────────────────────────

──────────────────────── 使用说明 ────────────────────────
 1. 建议先选择「仅检测」，确认受影响的目录及原因；
 2. 再选择「自动修复」进行处理；
 3. 处理完成后返回客户端，重新执行「立即扫描」以确认。

 如需在 fnOS 中确认目录路径，可在「文件管理」中打开该目录，点击右上角
 「⋯」→「属性」→「位置」，复制显示的路径（无需添加引号）。
─────────────────────────────────────────────────────────

TXT
}

# 首次进入菜单时展示一次说明（以标记文件记录，避免重复打扰）
introduce_once() {
    marker_dir="${HOME:-/root}/.config"
    marker_file="$marker_dir/.fnos-media-acl-fix.intro-shown"
    [ -f "$marker_file" ] && return 0
    mkdir -p "$marker_dir" 2>/dev/null
    explain_background
    : > "$marker_file" 2>/dev/null
}

# ── 交互菜单 ────────────────────────────────────────────────────────────

# 当前使用的即为默认方式时，额外标注出来
default_hint() {
    [ "$MODE" = 'auto' ] && printf '    ← 默认方式'
}

mode_label() {
    case "$MODE" in
        auto) echo 'auto（推荐：先清除授权记录，仍不可访问时追加读取权限）' ;;
        strip) echo 'strip（仅清除授权记录，会丢失 fnOS 共享）' ;;
        acl) echo 'acl（仅追加读取权限，不影响 fnOS 共享）' ;;
    esac
    [ "$DRY_RUN" -eq 1 ] && printf '（预演模式：只输出不修改）'
}

ask_user() {
    echo "服务端账户即 NAS 上飞鲸影视服务端进程的运行账户，脚本会自动识别。"
    echo "仅在自动识别有误时修改，直接回车保持当前设置。"
    printf '服务端账户 [%s]: ' "$APP_USER"
    IFS= read -r answer
    if [ -n "$answer" ]; then APP_USER=$answer; fi
    if ! id "$APP_USER" >/dev/null 2>&1; then
        echo "系统中不存在账户 $APP_USER，保留原有设置"
        return 1
    fi
    echo "已设置为：$APP_USER"
}

run_targets() {
    list=$1
    old_ifs=$IFS
    IFS='
'
    for t in $list; do
        [ -n "$t" ] || continue
        checked=$((checked + 1))
        if is_dir "$t"; then
            scan_root "$t"
        else
            rc=0
            check_path "$t" "指定路径" || rc=$?
            note_result "$rc"
        fi
    done
    IFS=$old_ifs
}

ask_scan_root() {
    echo "请输入要处理的路径，可输入多行（目录或文件均可）："
    echo "  · 输入目录时，会检查该目录下的全部子目录与文件；输入文件时只检查该文件。"
    echo "  · 每个路径一行，路径无需加引号，可从 fnOS 文件管理的目录属性中复制。"
    echo "  · 全部输入完后，输入一个空行（直接回车）开始执行；输入 ! 查看说明。"
    targets=''
    while IFS= read -r line; do
        [ -z "$line" ] && break
        if [ "$line" = '!' ]; then explain_background; continue; fi
        if [ ! -e "$line" ]; then
            echo "路径不存在，已跳过：$line"
            continue
        fi
        targets="$targets
$line"
    done
    [ -n "$(printf '%s' "$targets" | tr -d ' \n')" ] || { echo "未输入任何路径，返回菜单。"; return 1; }
    run_targets "$targets"
}

menu() {
    introduce_once
    while :; do
        cat <<EOF

==================== 飞鲸影视 / fnOS 媒体权限修复 ====================
 服务端账户：$APP_USER
 修复方式：$(mode_label)$(default_hint)

   1) 仅检测：检查输入的目录/文件，列出服务端无法访问的条目（不做修改）
   2) 自动修复：检查输入的目录/文件，并修复其中无法访问的条目（推荐）
   3) 切换修复方式（auto / strip / acl），默认 auto 模式
   4) 查看说明：问题原因、三种修复方式的区别、使用建议
   5) 修改服务端账户（默认自动识别）
   0) 退出
 提示：1 和 2 都支持一次输入多行路径。先选 1 看原因，再选 2 自动修复。
====================================================================
EOF
        printf '请输入选项: '
        IFS= read -r choice || exit 0
        reset_counters
        case "$choice" in
            1) MODE=auto; LIST_ONLY=1; DRY_RUN=0; ask_scan_root; summarize ;;
            2) MODE=auto; LIST_ONLY=0; DRY_RUN=0; ask_scan_root; summarize ;;
            3)
                echo '  1) auto  —— 先清除 fnOS 授权记录，仍不可访问时追加读取权限（推荐）'
                echo '  2) strip —— 仅清除 fnOS 授权记录（会丢失 fnOS 共享）'
                echo '  3) acl   —— 仅追加读取权限（不影响 fnOS 共享）'
                echo '  输入 4 查看三种方式的完整区别。'
                printf '选择修复方式 [1/2/3/4]: '
                IFS= read -r m
                case "$m" in
                    1) MODE=auto; echo '已设为 auto（推荐）' ;;
                    2) MODE=strip; echo '已设为 strip（仅清除授权记录）' ;;
                    3) MODE=acl; echo '已设为 acl（仅追加读取权限）' ;;
                    4) explain_background ;;
                    *) echo '未修改' ;;
                esac ;;
            4) explain_background ;;
            5) ask_user ;;
            0|q|Q) echo '已退出'; exit 0 ;;
            *) echo '无效选项，请输入菜单前的编号。' ;;
        esac
        LIST_ONLY=0
    done
}

# ── 主流程 ──────────────────────────────────────────────────────────────

if [ "$HAS_ARGS" -eq 0 ]; then
    menu
fi

echo "（修复方式：$(mode_label)；服务端账户：$APP_USER）"

if [ "$INTERACTIVE" -eq 1 ]; then
    echo "请逐行输入待处理的目录或文件路径（每行一个，直接回车结束）："
    si_targets=''
    while IFS= read -r line; do
        [ -z "$line" ] && break
        si_targets="$si_targets
$line"
    done
    run_targets "$si_targets"
fi

run_targets "$FILES"
run_targets "$DIRS"

summarize
exit "$status"
