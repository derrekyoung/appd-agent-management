#!/bin/bash

################################################################################
#
# Useful for automating downloads or downloading directly onto a server.
#
################################################################################

# You can choose to set your variables here or you can pass in the the variables
# via command line. Or you will be prompted for the values if nothing is set.
EMAIL=""
PASSWORD=""
URL=""



################################################################################

usage() {
    echo "Usage: $0 [-e=email] [-p=password] [-u=URL]"
    echo "Download AppDynamics software."
    echo "    -e= AppDynamics username"
    echo "    -p= AppDynamics password"
    echo "    -u= AppDynamics download URL"
    echo "Pass in zero artuments to be prompted for input or set the variables at the top of this script to have default variables."
}

download() {
    echo "Downloading $URL as $EMAIL"

    curl -c cookies.txt -d "username=$EMAIL&password=$PASSWORD" https://login.appdynamics.com/sso/login/
    curl -L -O -b cookies.txt $URL

    rm cookies.txt
}

prompt-for-credentials() {
    # if email empty then prompt
    if [[ -z "$EMAIL" ]]; then
        echo -n "Enter your AppDynamics email address: "
        read EMAIL
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

    if [[ -z "$URL" ]]; then
        echo -n "Enter the AppDynamics download URL: "
        read URL
    fi
}


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

prompt-for-credentials
download
