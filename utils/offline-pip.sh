#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
set -ea

################################################################################
#
# 2 part install of Pip packages for offline/closed networks
#
# Version: __VERSION__
# Author(s): __AUTHORS__
#
################################################################################

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true

################################################################################
# Do Not Edit Below This Line
################################################################################

PACKAGE_NAME=""
PIP_CACHE="pip-cache"
ARCHIVE_NAME="$PACKAGE_NAME-$PIP_CACHE.tgz"
MODE=""
MODE_DOWNLOAD="download"
MODE_INSTALL="install"

usage() {
    echo -e "Utility script to download and (offline) install Python Fabric."
    echo -e "This is a 2 part process:"
    echo -e "   1) Download the dependencies from a server that has internet access."
    echo -e "   2) Install $PACKAGE_NAME with dependencies\n"
    echo -e "Usage: $0 {download,install} {pip package name}"
    echo -e "\nArguments:"
    echo -e "    download   Download Fabric and dependencies"
    echo -e "    install    Offline install fabric with dependencies"
    echo -e "    {pip package} The name of the Pip package, e.g. fabric"
    echo -e "    --help  Print usage"
}

main() {
    parse-args "$@"

    if [[ "$MODE" == "$MODE_INSTALL" ]]; then
        install
    elif [[ "$MODE" == "$MODE_DOWNLOAD" ]]; then
        download
    else
        usage
        exit 1
    fi
}

parse-args() {
    local tmpMode="$1"
    local tmpPackage="$2"

    if [[ "$tmpMode" == "install" ]]; then
        MODE="$MODE_INSTALL"
    elif [[ "$tmpMode" == "download" ]]; then
        MODE="$MODE_DOWNLOAD"
    else
        log-error "Error parsing argument $tmpMode" >&2
        usage
        exit 1
    fi

    if [[ -z "$tmpPackage" ]]; then
        log-error "Required: You must pass in a Pip package name" >&2
        usage
        exit 1
    else
        PACKAGE_NAME="$tmpPackage"
        ARCHIVE_NAME="$PACKAGE_NAME-$PIP_CACHE.tgz"
    fi
}

# Download and package dependencies
# https://pip.pypa.io/en/latest/user_guide/#installing-from-local-packages
download() {
    local pip=$(which pip)
    if [[ -z "$pip" ]]; then
        log-error "Pip is required to download the dependencies. Exiting."
        exit 1
    fi

    log-info "Downloading $PACKAGE_NAME and dependencies"

    if [[ -d "$PIP_CACHE" ]]; then
        rm -rf "$PIP_CACHE"
    fi

    mkdir -p "$PIP_CACHE"
    cp "$DIR"/$0 "$PIP_CACHE"

    cd "$PIP_CACHE"
    curl -O https://bootstrap.pypa.io/get-pip.py
    cd "$DIR"

    log-info "Downloading Pip dependencies"
    pip install --download ./"$PIP_CACHE" wheel > /dev/null 2>&1
    pip install --download ./"$PIP_CACHE" setuptools > /dev/null 2>&1
    pip install --download ./"$PIP_CACHE" pip > /dev/null 2>&1
    pip install --download ./"$PIP_CACHE" fabric > /dev/null 2>&1

    log-info "Creating archive: $ARCHIVE_NAME"
    tar -cvzf "$ARCHIVE_NAME" "$PIP_CACHE"

    rm -rf "$PIP_CACHE"

    log-info "SUCCESS: $PACKAGE_NAME depencies downloaded and compressed into $ARCHIVE_NAME \n"
    log-info "Next steps:"
    log-info "  1) Transfer $ARCHIVE_NAME and this script to the destination server."
    log-info "  2) Execute $0 install $PACKAGE_NAME \n\n"
}

install() {
    if [[ ! -f "$ARCHIVE_NAME" ]]; then
        log-error "Error installing $PACKAGE_NAME. File not found: $ARCHIVE_NAME"
        exit 1
    fi

    local isPip=$(is-pip-installed)
    log-debug "isPip=$isPip"

    if [[ "$isPip" == "true" ]]; then
        install-with-pip
    else
        install-without-pip
    fi

    log-info "SUCCESS: $PACKAGE_NAME installed from $ARCHIVE_NAME"
}

is-pip-installed() {
    local result=$(type -p pip)
    if [[ ! -z "$result" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Is PIP installed? Install from local dependencies
# https://pip.pypa.io/en/latest/user_guide/#installing-from-local-packages
install-with-pip() {
    log-info "Installing with existing Pip"

    tar xvfz "$ARCHIVE_NAME"
    pip install --no-index --find-links ./"$PIP_CACHE" "$PACKAGE_NAME"
}

# No, PIP is not installed. Install from local dependencies. Requires sudo on Ubuntu, probably su on RHEL
# Requires Python to be installed
# https://pip.pypa.io/en/latest/installing/
install-without-pip() {
    log-info "Installing with get-pip.py"

    tar -xzvf fabric-pip-cache.tgz; \
    sudo python ./"$PIP_CACHE"/get-pip.py --no-index --find-links=./"$PIP_CACHE"
}

################################################################################
# Logging
prepare-logs() {
    local logDir="$1"
    local logFile="$2"

    mkdir -p "$logDir"

    if [[ -f "$logFile" ]]; then
        rm -f "$logFile"
    fi
}

log-debug() {
    if [[ $DEBUG_LOGS = true ]]; then
        echo -e "DEBUG: $1"
    fi
}

log-info() {
    echo -e "INFO:  $1"
}

log-warn() {
    echo -e "WARN:  $1"
}

log-error() {
    echo -e "ERROR: \n       $1"
}

main "$@"
