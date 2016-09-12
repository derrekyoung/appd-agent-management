#!/bin/bash

VERSION="0.7-BETA"
AUTHORS="Derrek Young, Eli Rodriguez"



###############################################################################
# Do not edit below this line
###############################################################################

declare -a FILES=("README.md" \
    "download.sh" \
    "local-agent-install.sh" \
    "local-agent-config.sh" \
    "remote-agent-install.sh" \
    "fabfile.py" \
    "remote-config-sample.json"\
    "agent-config-sample.properties")

DIST_DIR="./dist"
DIST_TOP_FOLDER="appd-agent-management-$VERSION"
ZIP_DIR="$DIST_DIR/$DIST_TOP_FOLDER"
DISTRIBUTABLE_NAME="$DIST_TOP_FOLDER.zip"


copy-files() {
    for file in "${FILES[@]}"
    do
        cp $file $ZIP_DIR/
    done
}

replace-build-variables() {
    for file in "${FILES[@]}"
    do
        sed -i -e "s/DEBUG_LOGS=true/DEBUG_LOGS=false/g" "$ZIP_DIR/$file"
        sed -i -e "s/_VERSION_/$VERSION/g" "$ZIP_DIR/$file"
        sed -i -e "s/_AUTHORS_/$AUTHORS/g" "$ZIP_DIR/$file"

        # Differences between Mac and Linux. Mac doesn't know the '-e'
        if [[ -f "$ZIP_DIR/$file-e" ]]; then
            rm "$ZIP_DIR/$file-e"
        fi
    done
}

dist() {
    echo -e "INFO:  Building version $VERSION"

    # Remove the existing dist dir
    if [ -d "$DIST_DIR" ]; then
        echo "INFO:  Cleaning dist/ directory"
        rm -R $DIST_DIR
    fi

    # Make the dist dir
    if [ ! -d "$DIST_DIR" ]; then
        echo "INFO:  Making dist/ directory"
        mkdir $DIST_DIR
    fi

    # Create a top-level folder for unzipping the archive
    echo "INFO:  Making $ZIP_DIR"
    mkdir -p $ZIP_DIR

    copy-files

    replace-build-variables

    echo "INFO:  Creating the Zip file..."
    cd $DIST_DIR/$DIST_TOP_FOLDER/
    zip $DISTRIBUTABLE_NAME *

    echo "INFO:  Finished $ZIP_DIR/$DISTRIBUTABLE_NAME"
}

dist
