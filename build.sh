#!/bin/bash

VERSION="0.8-BETA"
AUTHORS="Derrek Young, Eli Rodriguez"



###############################################################################
# Do not edit below this line
###############################################################################

declare -a FILES=("README.md" \
    "download.sh" \
    "fabfile.py" \
    "local-agent-install.sh" \
    "local-agent-config.sh" \
    "start-here.sh" \
    "remote-agent-install.sh" \
    "conf/agent-configs/sample.properties" \
    "conf/remote-hosts/sample.json" \
    "utils/latest-appdynamics-version.txt" \
    "utils/utilities.sh" \
    "utils/version.txt")

PARENT_DIR="."
DIST_DIR="./dist"
DIST_TOP_FOLDER="appd-agent-management"
# ZIP_DIR="$DIST_DIR"
DISTRIBUTABLE_NAME="$DIST_TOP_FOLDER.zip"


copy-files() {
    for file in "${FILES[@]}"
    do
        # cp $file $ZIP_DIR/
        rsync -R $file $DIST_DIR/
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
    echo -e "INFO:  Building version $VERSION"

    # Remove the existing dist dir
    if [ -d "$DIST_DIR" ]; then
        echo "INFO:  Cleaning dist/ directory"
        rm -R $DIST_DIR
    fi

    # Make the dist dir
    if [ ! -d "$DIST_DIR" ]; then
        echo "INFO:  Making dist/ directory"
        mkdir -p $DIST_DIR
    fi

    # Create a top-level folder for unzipping the archive
    # echo "INFO:  Making $ZIP_DIR"
    # mkdir -p $ZIP_DIR

    copy-files

    cd $DIST_DIR/
    replace-build-variables

    echo "INFO:  Creating the Zip file..."
    zip -r $DISTRIBUTABLE_NAME *

    echo "INFO:  Finished $DIST_DIR/$DISTRIBUTABLE_NAME"
}

dist
