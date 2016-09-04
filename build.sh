#!/bin/bash

VERSION="0.2-BETA"
AUTHORS="Derrek Young, Eli Rodriguez"



###############################################################################
# Do not edit below this line
###############################################################################

FILES=("README.md" \
    "download.sh" \
    "local-agent-install.sh" \
    "remote-agent-install.sh" \
    "remote-agent-install.py")

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
        rm "$DIST_DIR/$DIST_TOP_FOLDER/$file-e" # This is hacky, but I'm not sure why SED is adding the -e. Doesn't work if I remove the -e
    done
}

dist() {
    if [ -d "$DIST_DIR" ]; then
        echo "INFO:  Cleaning dist/ directory"
        rm -R $DIST_DIR
    fi

    if [ ! -d "$DIST_DIR" ]; then
        echo "INFO:  Making dist/ directory"
        mkdir $DIST_DIR
    fi

    # Create a top-level folder for when unzipping the archive
    echo "INFO:  Making $ZIP_DIR"
    mkdir -p $ZIP_DIR

    copy-files

    replace-build-variables

    echo "INFO:  Creating the Zip file..."
    cd $DIST_DIR/
    zip -r $DISTRIBUTABLE_NAME $DIST_TOP_FOLDER/

    echo "INFO:  Finished. $ZIP_DIR/$DISTRIBUTABLE_NAME"
}

dist
