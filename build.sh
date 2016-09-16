#!/bin/bash

VERSION="0.9-BETA"
AUTHORS="Derrek Young, Eli Rodriguez"



###############################################################################
# Do not edit below this line
###############################################################################

source ./utils/utilities.sh

# PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# TLD=""
DIST_DIR="./dist"
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
    "utils/utilities.sh" \
    "utils/version.txt")

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
        sed -i -e "s/_VERSION_/$VERSION/g" "$file"
        sed -i -e "s/_AUTHORS_/$AUTHORS/g" "$file"

        # Differences between Mac and Linux. Mac doesn't know the '-e'
        if [[ -f "$file-e" ]]; then
            rm "$file-e"
        fi
    done
}

dist() {
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

dist
