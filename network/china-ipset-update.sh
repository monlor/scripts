#!/bin/sh
# Update ipset entries for China mainland IPv4/IPv6 ranges. Safe to rerun.
# Supports: Linux, OpenWrt

set -eu

IPV4_URL="${IPV4_URL:-https://ispip.clang.cn/all_cn.txt}"
IPV6_URL="${IPV6_URL:-https://ispip.clang.cn/all_cn_ipv6.txt}"
CN_IPV4_SET="${CN_IPV4_SET:-cn_ipv4}"
CN_IPV6_SET="${CN_IPV6_SET:-cn_ipv6}"

SKIP_IPV6=0
SKIP_IPV4=0

usage() {
    cat <<'EOF'
Usage: china-ipset-update.sh [options]

Options:
  --ipv4-set NAME      Set the IPv4 ipset name (default: cn_ipv4)
  --ipv6-set NAME      Set the IPv6 ipset name (default: cn_ipv6)
  --ipv4-url URL       Override the IPv4 data source URL
  --ipv6-url URL       Override the IPv6 data source URL
  --skip-ipv4          Skip the IPv4 list update
  --skip-ipv6          Skip the IPv6 list update
  -h, --help           Show this help message

Environment variables:
  IPV4_URL, IPV6_URL, CN_IPV4_SET, CN_IPV6_SET override defaults.

Example:
  sh china-ipset-update.sh --ipv4-set my_cn --skip-ipv6
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ipv4-set)
            [ $# -ge 2 ] || { echo "Missing value for --ipv4-set" >&2; exit 1; }
            CN_IPV4_SET="$2"
            shift 2
            ;;
        --ipv6-set)
            [ $# -ge 2 ] || { echo "Missing value for --ipv6-set" >&2; exit 1; }
            CN_IPV6_SET="$2"
            shift 2
            ;;
        --ipv4-url)
            [ $# -ge 2 ] || { echo "Missing value for --ipv4-url" >&2; exit 1; }
            IPV4_URL="$2"
            shift 2
            ;;
        --ipv6-url)
            [ $# -ge 2 ] || { echo "Missing value for --ipv6-url" >&2; exit 1; }
            IPV6_URL="$2"
            shift 2
            ;;
        --skip-ipv4)
            SKIP_IPV4=1
            shift
            ;;
        --skip-ipv6|--no-ipv6)
            SKIP_IPV6=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unsupported flag: $1" >&2
            usage >&2
            exit 1
            ;;
        esac
done

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Required command not found: $1" >&2
        exit 1
    fi
}

download_to_file() {
    url="$1"
    dest="$2"

    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$url" -o "$dest"; then
            echo "Failed to download: $url" >&2
            return 1
        fi
        return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        if ! wget -qO "$dest" "$url"; then
            echo "Failed to download: $url" >&2
            return 1
        fi
        return 0
    fi

    echo "Install curl or wget to download the data list" >&2
    return 1
}

ensure_ipset() {
    set_name="$1"
    family="$2"

    if ipset list "$set_name" >/dev/null 2>&1; then
        ipset flush "$set_name"
    else
        if ! ipset create "$set_name" hash:net family "$family" hashsize 1024 maxelem 131072; then
            echo "Unable to create ipset set: $set_name" >&2
            return 1
        fi
    fi
}

load_list_into_ipset() {
    url="$1"
    set_name="$2"
    family="$3"

    tmp_file=$(mktemp /tmp/china_ipset.XXXXXX 2>/dev/null || printf '/tmp/china_ipset.%s' "$$")
    [ -e "$tmp_file" ] || : >"$tmp_file"
    trap 'rm -f "$tmp_file"' INT TERM EXIT HUP

    cleanup_tmp() {
        rm -f "$tmp_file"
        trap - INT TERM EXIT HUP
    }

    if ! download_to_file "$url" "$tmp_file"; then
        cleanup_tmp
        return 1
    fi

    if [ ! -s "$tmp_file" ]; then
        echo "Downloaded list is empty: $url" >&2
        cleanup_tmp
        return 1
    fi

    if ! ensure_ipset "$set_name" "$family"; then
        cleanup_tmp
        return 1
    fi

    added=0
    tab_char="$(printf '\t')"

    while IFS= read -r line || [ -n "$line" ]; do
        # Remove potential Windows carriage returns
        line=$(printf '%s' "$line" | tr -d '\r')

        case "$line" in
            ''|'#'* )
                continue
                ;;
        esac

        entry="$line"
        entry="${entry%%#*}"
        entry="${entry%%;*}"

        case "$entry" in
            *" "*) entry="${entry%% *}" ;;
        esac
        case "$entry" in
            *"$tab_char"* ) entry="${entry%%$tab_char*}" ;;
        esac

        if [ -z "$entry" ]; then
            continue
        fi

        if ipset add "$set_name" "$entry" -exist >/dev/null 2>&1; then
            added=$((added + 1))
        fi
    done < "$tmp_file"

    cleanup_tmp

    echo "Update complete: $set_name (family $family), imported $added entries"
}

require_command ipset

if [ "$SKIP_IPV4" -eq 0 ]; then
    load_list_into_ipset "$IPV4_URL" "$CN_IPV4_SET" inet || exit 1
fi

if [ "$SKIP_IPV6" -eq 0 ]; then
    if load_list_into_ipset "$IPV6_URL" "$CN_IPV6_SET" inet6; then
        :
    else
        echo "IPv6 update failed. Retry or use --skip-ipv6" >&2
        exit 1
    fi
fi

echo "All tasks complete."
