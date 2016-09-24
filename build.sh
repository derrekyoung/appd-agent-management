#!/bin/bash
B_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
set -ea

################################################################################
#
# Build the project and create a zip.
#
# Version: __VERSION__
# Author(s): __AUTHORS__
#
################################################################################

VERSION="1.0-ALPHA"
AUTHORS="Derrek Young, Eli Rodriguez"



###############################################################################
# Do not edit below this line
###############################################################################

LOG_DIR="$B_DIR/logs"
SCRIPT_NAME=$(basename -- "$0" | cut -d"." -f1)
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"

DIST_DIR="$B_DIR/dist"
DISTRIBUTABLE_NAME="appd-agent-management.zip"

declare -a FILES=("README.md" \
    "build.sh" \
    "download.sh" \
    "local-agent-install.sh" \
    "newbies-start-here.sh" \
    "remote-agent-install.sh" \
    "conf/agent-configs/sample.properties" \
    "conf/remote-hosts/sample.json" \
    "utils/fabfile.py" \
    "utils/latest-appdynamics-version.txt" \
    "utils/local-agent-config.sh" \
    "utils/offline-pip.sh" \
    "utils/utilities.sh")

copy-files() {
    for file in "${FILES[@]}"
    do
        # cp $file $ZIP_DIR/
        rsync -R "$file" "$DIST_DIR/"
    done
}

replace-build-variables() {
    for file in "${FILES[@]}"
    do
        # echo "$file"
        sed -i -e "s/DEBUG_LOGS=true/DEBUG_LOGS=false/g" "$file"
        sed -i -e "s/__VERSION__/$VERSION/g" "$file"
        sed -i -e "s/__AUTHORS__/$AUTHORS/g" "$file"

        # Differences between Mac and Linux. Mac doesn't know the '-e'
        if [[ -f "$file-e" ]]; then
            rm "$file-e"
        fi
    done
}

dist() {
    prepare-logs "$LOG_DIR" "$LOG_FILE"

    log-info "Building version $VERSION"

    # Remove the existing dist dir
    if [ -d "$DIST_DIR" ]; then
        log-info "Cleaning $DIST_DIR directory"
        rm -R "$DIST_DIR"
    fi

    # Make the dist dir
    if [ ! -d "$DIST_DIR" ]; then
        log-info "Making $DIST_DIR directory"
        mkdir -p "$DIST_DIR"
    fi

    copy-files

    cd "$DIST_DIR/"
    replace-build-variables

    log-info "Creating the Zip file..."
    zip -r "$DISTRIBUTABLE_NAME" *

    log-info "Finished $DIST_DIR/$DISTRIBUTABLE_NAME"
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
        echo -e "DEBUG: $1" | tee -a "$LOG_FILE"
    fi
}

log-info() {
    echo -e "INFO:  $1" | tee -a "$LOG_FILE"
}

log-warn() {
    echo -e "WARN:  $1" | tee -a "$LOG_FILE"
}

log-error() {
    echo -e "ERROR: \n       $1" | tee -a "$LOG_FILE"
}

dist
