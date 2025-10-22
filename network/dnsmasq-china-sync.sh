#!/bin/sh
# Download dnsmasq China domain lists with customizable upstream DNS servers.
# Supports: Linux, OpenWrt

set -eu

BASE_ACCELERATED_URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/refs/heads/master/accelerated-domains.china.conf"
BASE_APPLE_URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/refs/heads/master/apple.china.conf"

ACCELERATED_URL=${ACCELERATED_URL:-"${GH_PROXY:-}${BASE_ACCELERATED_URL}"}
APPLE_URL=${APPLE_URL:-"${GH_PROXY:-}${BASE_APPLE_URL}"}
OUTPUT_DIR=${OUTPUT_DIR:-"/etc/dnsmasq.d"}
DNS_IPV4=${DNS_IPV4:-"223.5.5.5"}
DNS_IPV6=${DNS_IPV6:-"2400:3200::1"}

SKIP_IPV6=0

print_usage() {
    cat <<'EOF'
Usage: dnsmasq-china-sync.sh [options]

Options:
  --output-dir DIR       Destination directory (default: /etc/dnsmasq.d)
  --dns-ipv4 ADDR        Override IPv4 DNS (default: 223.5.5.5)
  --dns-ipv6 ADDR        Override IPv6 DNS (default: 2400:3200::1)
  --no-ipv6              Do not generate IPv6 entries
  --accelerated-url URL  Override accelerated domains list URL
  --apple-url URL        Override Apple domains list URL
  -h, --help             Show this help message

Environment variables:
  OUTPUT_DIR, DNS_IPV4, DNS_IPV6, ACCELERATED_URL, APPLE_URL
  GH_PROXY             Optional GitHub proxy prefix (e.g. https://gh.monlor.com/)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --output-dir)
            [ $# -ge 2 ] || { echo "Missing value for --output-dir" >&2; exit 1; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --dns-ipv4)
            [ $# -ge 2 ] || { echo "Missing value for --dns-ipv4" >&2; exit 1; }
            DNS_IPV4="$2"
            shift 2
            ;;
        --dns-ipv6)
            [ $# -ge 2 ] || { echo "Missing value for --dns-ipv6" >&2; exit 1; }
            DNS_IPV6="$2"
            shift 2
            ;;
        --no-ipv6)
            SKIP_IPV6=1
            shift
            ;;
        --accelerated-url)
            [ $# -ge 2 ] || { echo "Missing value for --accelerated-url" >&2; exit 1; }
            ACCELERATED_URL="$2"
            shift 2
            ;;
        --apple-url)
            [ $# -ge 2 ] || { echo "Missing value for --apple-url" >&2; exit 1; }
            APPLE_URL="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unsupported option: $1" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

if [ "$SKIP_IPV6" -eq 1 ]; then
    DNS_IPV6=""
fi

if [ -z "$DNS_IPV4" ]; then
    echo "IPv4 DNS cannot be empty" >&2
    exit 1
fi

ensure_directory() {
    dir="$1"
    if [ ! -d "$dir" ]; then
        if ! mkdir -p "$dir"; then
            echo "Unable to create directory: $dir" >&2
            exit 1
        fi
    fi
}

download_to_file() {
    url="$1"
    dest="$2"
    full_url="$url"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$full_url" -o "$dest"; then
            return 0
        fi
        echo "Failed to download via curl: $full_url" >&2
    fi

    if command -v wget >/dev/null 2>&1; then
        if wget -qO "$dest" "$full_url"; then
            return 0
        fi
        echo "Failed to download via wget: $full_url" >&2
    fi

    echo "Unable to download list: $full_url" >&2
    return 1
}

apply_dns_overrides() {
    source_file="$1"
    destination_file="$2"

    awk -v placeholder="114.114.114.114" \
        -v ipv4="$DNS_IPV4" \
        -v ipv6="$DNS_IPV6" \
        'BEGIN { ipv6_enabled = (length(ipv6) > 0) }
        {
            if (index($0, placeholder) > 0 && $0 ~ /^server=/) {
                line = $0
                gsub(placeholder, ipv4, line)
                print line
                if (ipv6_enabled) {
                    line6 = line
                    sub(ipv4, ipv6, line6)
                    print line6
                }
            } else {
                print
            }
        }' "$source_file" > "$destination_file"
}

write_config() {
    url="$1"
    filename="$2"
    target="$OUTPUT_DIR/$filename"

    tmp_download=$(mktemp)
    tmp_processed=$(mktemp)

    cleanup() {
        rm -f "$tmp_download" "$tmp_processed"
    }
    trap cleanup EXIT INT TERM HUP

    if ! download_to_file "$url" "$tmp_download"; then
        cleanup
        exit 1
    fi

    if [ ! -s "$tmp_download" ]; then
        echo "Downloaded file is empty: $url" >&2
        cleanup
        exit 1
    fi

    apply_dns_overrides "$tmp_download" "$tmp_processed"

    if ! cat "$tmp_processed" > "$target"; then
        echo "Failed to write configuration: $target" >&2
        cleanup
        exit 1
    fi

    chmod 0644 "$target" 2>/dev/null || true

    cleanup
    trap - EXIT INT TERM HUP

    echo "Updated $target"
}

ensure_directory "$OUTPUT_DIR"

write_config "$ACCELERATED_URL" "accelerated-domains.china.conf"
write_config "$APPLE_URL" "apple.china.conf"

echo "dnsmasq China lists refreshed. Reload dnsmasq to apply changes."
