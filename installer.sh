#!/bin/bash

GITHUB_USER="Arian7s"
GITHUB_REPO="subextractorlite"
VERSION_FILE="version.txt"
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

get_python_version() {
    if ! command_exists python3; then
        echo "python3 is not installed" >&2
        return 1
    fi
    python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
}

get_latest_version() {
    local url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}/${VERSION_FILE}"
    if command_exists curl; then
        curl -sL "$url" | tr -d '\n\r'
    elif command_exists wget; then
        wget -qO- "$url" | tr -d '\n\r'
    else
        echo "curl or wget is required" >&2
        return 1
    fi
}

reboot_device() {
    echo "[+] Rebooting device in 5 seconds..."
    sleep 5

    if command_exists systemctl; then
        systemctl reboot
    elif command_exists reboot; then
        reboot
    elif [ -x /sbin/reboot ]; then
        /sbin/reboot
    elif [ -x /usr/sbin/reboot ]; then
        /usr/sbin/reboot
    else
        echo b > /proc/sysrq-trigger 2>/dev/null || killall -9 enigma2 2>/dev/null
    fi
}

main() {
    echo "=========================================="
    echo "  SubExtractorLite Installer for Enigma2"
    echo "=========================================="

    local ARCH
    ARCH=$(get_architecture) || exit 1
    echo "[+] Detected architecture: $ARCH"

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
    local IPK_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/v${VERSION}/${IPK_NAME}"

    echo "[+] IPK file: $IPK_NAME"

    echo "[+] Updating package lists..."
    opkg update

    echo "[+] Installing python3-pillow..."
    opkg install python3-pillow

    echo "[+] Installing dvbsnoop..."
    opkg install dvbsnoop

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
    echo "=========================================="

    reboot_device
}

main "$@"
