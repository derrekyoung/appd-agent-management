#!/bin/bash

################################################################################
#
# Useful for automating downloads or downloading directly onto a server.
#
# Version: _VERSION_
# Author(s): _AUTHORS_
#
################################################################################

# You can choose to set your variables here or you can pass in the the variables
# via command line. Or you will be prompted for the values if nothing is set.
EMAIL=""
PASSWORD=""
URL=""
DOWNLOAD_HOME="./archives"


################################################################################
# Do Not Edit Below This Line
################################################################################

ARCHIVE_NAME=""

usage() {
    echo "Usage: $0 [-e=email] [-p=password] [-u=URL]"
    echo "Download AppDynamics software."
    echo "    -e= AppDynamics username"
    echo "    -p= AppDynamics password"
    echo "    -u= AppDynamics download URL"
    echo "Pass in zero artuments to be prompted for input or set the variables at the top of this script to have default variables."
}

main() {
    parse-args "$@"
    prompt-for-credentials
    build-url
    download
}

build-url() {
    while [[ -z "$URL" ]]
    do
        echo -n "Enter the AppDynamics download URL: "
        read -r URL
    done

    # Get everything after the last slash
    ARCHIVE_NAME=$(echo "$URL" | sed 's:.*/::')
}

download() {
    echo "Downloading $URL as $EMAIL"

    if [ ! -d "$DOWNLOAD_HOME" ]; then
        mkdir "$DOWNLOAD_HOME"
    fi

    cd "$DOWNLOAD_HOME"

    curl -c cookies.txt -d "username=$EMAIL&password=$PASSWORD" https://login.appdynamics.com/sso/login/
    curl -L -O -b cookies.txt $URL

    rm cookies.txt

    echo -e "SUCCESS: Agent downloaded to $DOWNLOAD_HOME/$ARCHIVE_NAME"
}

parse-args() {
    # Grab arguments in case there are any
    for i in "$@"
    do
        case $i in
            -e=*|--email=*)
                EMAIL="${i#*=}"
                shift # past argument=value
                ;;
            -p=*|--password=*)
                PASSWORD="${i#*=}"
                shift # past argument=value
                ;;
            -u=*|--url=*)
                URL="${i#*=}"
                shift # past argument=value
                ;;
            *)
                echo "Error parsing argument $1" >&2
                usage
                exit 1
            ;;
        esac
    done
}

prompt-for-credentials() {
    # if email empty then prompt
    if [[ -z "$EMAIL" ]]; then
        echo -n "Enter your AppDynamics email address: "
        read -r EMAIL
    fi

    # if password empty then prompt
    if [[ -z "$PASSWORD" ]]; then
        echo -n "Enter your AppDynamics password: "
        # read -s PASSWORD
        unset PASSWORD
        while IFS= read -p "$prompt" -r -s -n 1 char
        do
            if [[ $char == $'\0' ]]
            then
                break
            fi
            prompt='*'
            PASSWORD+="$char"
        done
        echo
    fi
}

main "$@"
