#!/bin/bash

GITHUB_USER="Arian7s"
GITHUB_REPO="subextractorlite"
BRANCH="main"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

get_architecture() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        armv7l|armv7*) echo "armv7l" ;;
        aarch64|arm64)  echo "aarch64" ;;
        mipsel|mips)    echo "mipsel" ;;
        *)
            echo "Unsupported architecture: $arch" >&2
            return 1
            ;;
    esac
}

get_arch_dir() {
    case "$1" in
        armv7l) echo "arm" ;;
        aarch64) echo "aarch64" ;;
        mipsel) echo "mipsel" ;;
        *) echo "$1" ;;
    esac
}

get_python_version() {
    if ! command_exists python3; then
        echo "python3 is not installed" >&2
        return 1
    fi
    python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
}

get_latest_version() {
    local api_url="https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/contents/"
    local response
    if command_exists curl; then
        response=$(curl -sL "$api_url")
    elif command_exists wget; then
        response=$(wget -qO- "$api_url")
    else
        echo "curl or wget is required" >&2
        return 1
    fi

    local versions
    versions=$(echo "$response" | grep -o '"name": *"v[0-9.]*"' | sed 's/.*"v//;s/".*//')
    if [ -z "$versions" ]; then
        echo "Failed to fetch versions" >&2
        return 1
    fi

    local latest
    latest=$(echo "$versions" | sort -V | tail -n1)
    echo "$latest"
}

restart_enigma2() {
    echo "[+] Restarting Enigma2 in 5 seconds..."
    sleep 5

    if command_exists systemctl; then
        systemctl restart enigma2
    elif command_exists init; then
        init 4 && sleep 2 && init 3
    else
        killall -9 enigma2 2>/dev/null
    fi
}

main() {
    echo "=========================================="
    echo "  SubExtractorLite Installer for Enigma2"
    echo "=========================================="

    local ARCH
    ARCH=$(get_architecture) || exit 1
    echo "[+] Detected architecture: $ARCH"

    local ARCH_DIR
    ARCH_DIR=$(get_arch_dir "$ARCH")
    echo "[+] Architecture directory: $ARCH_DIR"

    local PY_VER
    PY_VER=$(get_python_version) || exit 1
    echo "[+] Detected Python version: $PY_VER"

    case "$PY_VER" in
        3.12|3.13|3.14) ;;
        *)
            echo "[-] Python $PY_VER is not supported. Supported: 3.12, 3.13, 3.14"
            exit 1
            ;;
    esac

    local VERSION
    VERSION=$(get_latest_version)
    if [ -z "$VERSION" ]; then
        echo "[-] Failed to fetch version"
        exit 1
    fi
    echo "[+] Version: $VERSION"

    local IPK_NAME="enigma2-plugin-extensions-subextractorlite_${VERSION}_${ARCH}_py${PY_VER}.ipk"
    local PY_DIR="python${PY_VER//./}"
    local IPK_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/refs/heads/${BRANCH}/v${VERSION}/${PY_DIR}/${ARCH_DIR}/${IPK_NAME}"

    echo "[+] IPK file: $IPK_NAME"
    echo "[+] Download URL: $IPK_URL"

    echo "[+] Updating package lists..."
    opkg update

    echo "[+] Installing python3-pillow..."
    opkg install python3-pillow

    local TMP_IPK="/tmp/${IPK_NAME}"
    echo "[+] Downloading $IPK_NAME ..."
    if command_exists curl; then
        curl -L -o "$TMP_IPK" "$IPK_URL"
    elif command_exists wget; then
        wget -O "$TMP_IPK" "$IPK_URL"
    else
        echo "[-] curl or wget is required"
        exit 1
    fi

    if [ ! -f "$TMP_IPK" ]; then
        echo "[-] Failed to download ipk file"
        exit 1
    fi

    echo "[+] Installing $IPK_NAME ..."
    opkg install "$TMP_IPK"

    local INSTALL_STATUS=$?
    if [ $INSTALL_STATUS -ne 0 ]; then
        echo "[-] Installation failed with status $INSTALL_STATUS"
        rm -f "$TMP_IPK"
        exit 1
    fi

    rm -f "$TMP_IPK"

    echo "=========================================="
    echo "  SubExtractorLite installed successfully"
    echo "  ByArian"
    echo "=========================================="

    restart_enigma2
}

main "$@"
