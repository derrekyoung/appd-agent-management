#!/bin/bash

VERSION="1.0-BETA"




###############################################################################
# Do not edit below this line
###############################################################################

DIST_DIR="./dist"
DIST_TOP_FOLDER="appd-agent-management-$VERSION"
DISTRIBUTABLE_NAME="$DIST_TOP_FOLDER.zip"

copy-and-version-files() {
    local file="$1"
    local destination_dir="$2"
    local ver="$3"

    cp $file $destination_dir/$file-$ver.sh
}

copy-files() {
    local files=("README.md" \
        "download.sh" \
        "local-agent-install.sh" \
        "remote-agent-install.sh" \
        "remote-agent-install.py")

    for file in "${files[@]}"
    do
        cp $file $DIST_DIR/$DIST_TOP_FOLDER/
    done
}

dist() {
    if [ -d "$DIST_DIR" ]; then
        echo "Cleaning dist/ directory..."
        rm -R $DIST_DIR
    fi

    if [ ! -d "$DIST_DIR" ]; then
        echo "Making dist/ directory..."
        mkdir $DIST_DIR
    fi

    # Create a top-level folder for when unzipping the archive
    mkdir -p $DIST_DIR/$DIST_TOP_FOLDER

    copy-files

    echo "Creating the Zip file..."
    cd $DIST_DIR/
    zip -r $DISTRIBUTABLE_NAME $DIST_TOP_FOLDER/
}

dist
