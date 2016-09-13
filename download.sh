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
LATEST_APPD_VERSION="4.2.6.0"

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true

################################################################################
# Do Not Edit Below This Line
################################################################################

source ./utils/utilities.sh

usage() {
    echo "Usage: $0 [-e=email] [-p=password] [-v=version] [[-t=type [-o=linux|osx] [-b=bitness] [-f=format]"
    echo "Download AppDynamics software."
    echo "    -e= AppDynamics username"
    echo "    -p= AppDynamics password"
    echo "    -v= Version, default to the latest version"
    echo "    -t= Type of software {java, database, machine}"
    echo "    -o= JVM type or OS type {sun, ibm, linux, osx}"
    echo "    -b= Bitness {32, 64}"
    echo "    -f= Format {zip, rpm}"
    echo "Pass in zero artuments to be prompted for input."
}

main() {
    parse-args "$@"
    prompt-for-credentials
    build-url
    prompt-for-version
    prompt-for-type
    prompt-for-details
    replace-url
    download
}

download() {
    log-info "Downloading $URL as $EMAIL"

    # Get everything after the last slash
    ARCHIVE_NAME=$(echo "$URL" | sed 's:.*/::')

    if [ ! -d "$DOWNLOAD_HOME" ]; then
        mkdir "$DOWNLOAD_HOME"
    fi

    cd "$DOWNLOAD_HOME"

    curl -c cookies.txt -d "username=$EMAIL&password=$PASSWORD" https://login.appdynamics.com/sso/login/
    curl -L -O -b cookies.txt $URL
    rm -f cookies.txt

    log-info "Agent downloaded to $DOWNLOAD_HOME/$ARCHIVE_NAME"
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
            -v=*|--version=*)
                DESIRED_VERSION="${i#*=}"
                shift # past argument=value
                ;;
            -t=*|--type=*)
                DESIRED_TYPE="${i#*=}"
                shift # past argument=value
                ;;
            -o=*|--os=*)
                DESIRED_OS="${i#*=}"
                shift # past argument=value
                ;;
            -b=*|--bitness=*)
                DESIRED_BITNESS="${i#*=}"
                shift # past argument=value
                ;;
            -f=*|--format=*)
                DESIRED_FORMAT="${i#*=}"
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

build-url() {
    if [[ "$DESIRED_TYPE" == "$PARAM_DATABASE" ]]; then
        URL="$URL_DATABASE_AGENT"
    fi

    if [[ "$DESIRED_TYPE" == "$PARAM_JAVA" ]]; then
        if [[ "$DESIRED_OS" == "$PARAM_IBM" ]]; then
            URL="$URL_JAVA_AGENT_IBM"
        elif [[ "$DESIRED_OS" == "$PARAM_SUN" ]]; then
            URL="$URL_JAVA_AGENT_SUN"
        fi
    fi

    if [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]]; then
        if [[ "$DESIRED_OS" == "$PARAM_LINUX" ]]; then
            if [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
                URL="$URL_MACHINE_AGENT_LINUX_32_ZIP"
            elif [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
                URL="$URL_MACHINE_AGENT_LINUX_64_ZIP"
            fi
        elif [[ "$DESIRED_OS" == "$PARAM_OSX" ]]; then
            URL="$URL_MACHINE_AGENT_OSX_64_ZIP"
        fi
    fi
}

prompt-for-credentials() {
    # if empty then prompt
    while [[ -z "$EMAIL" ]]
    do
        echo -n "Enter your AppDynamics email address: "
        read -r EMAIL
    done

    # if empty then prompt
    while [[ -z "$PASSWORD" ]]
    do
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
    done
}

prompt-for-version() {
    # if empty then prompt
    while [[ -z "$DESIRED_VERSION" ]]
    do
        echo -n "What version of AppDynamics? ($LATEST_APPD_VERSION) "
        read -r DESIRED_VERSION

        if [[ -z "$DESIRED_VERSION" ]]; then
            DESIRED_VERSION="$LATEST_APPD_VERSION"
        fi
    done

    # echo $DESIRED_VERSION
}

prompt-for-type() {
    local msg="What kind of software"

    while [[ -z "$DESIRED_TYPE" ]]
    do
    	echo "1) Database agent"
        echo "2) Java agent"
    	echo "3) Machine agent"
      	read -p "$msg: " option

		case "$option" in
			1)
                DESIRED_TYPE="$PARAM_DATABASE"
				;;
			2)
                DESIRED_TYPE="$PARAM_JAVA"
				;;
			3)
                DESIRED_TYPE="$PARAM_MACHINE"
				;;
			*)
				echo " "
				echo "$msg: "
				;;
		esac
	done

    # echo "DESIRED_TYPE=$DESIRED_TYPE"
}

prompt-for-details() {
    prompt-for-java
    prompt-for-machine
    prompt-for-database
    # echo "URL=$URL"
}

prompt-for-java() {
    if [[ "$DESIRED_TYPE" = "$PARAM_JAVA" ]]; then
        local msg="What kind of Java agent"

        while [[ -z "$URL" ]]
        do
    		echo "1) Sun JVM"
            echo "2) IBM JVM"
    	  	read -p "$msg: " option

    		case "$option" in
    			1)
                    URL="$URL_JAVA_AGENT_SUN"
    				;;
    			2)
                    URL="$URL_JAVA_AGENT_IBM"
    				;;
    			*)
    				echo " "
    				echo "$msg: "
    				;;
    		esac
    	done
    fi
}


prompt-for-machine() {
    if [[ "$DESIRED_TYPE" = "$PARAM_MACHINE" ]]; then
        local msg="What kind of Machine agent"

        while [[ -z "$URL" ]]
        do
    		echo "1) Linux, 64-bit, with JRE"
            echo "2) Linux, 32-bit, with JRE"
            echo "3) OS X, 64-bit, with JRE"
            echo "4) Linux, 64-bit, no JRE"
    	  	read -p "$msg: " option

    		case "$option" in
    			1)
                    URL="$URL_MACHINE_AGENT_LINUX_64_ZIP"
    				;;
    			2)
                    URL="$URL_MACHINE_AGENT_LINUX_32_ZIP"
    				;;
    			3)
                    URL="$URL_MACHINE_AGENT_OSX_64_ZIP"
    				;;
    			4)
                    URL="$URL_MACHINE_AGENT_UNIVERSAL_NOJRE"
    				;;
    			*)
    				echo " "
    				echo "$msg: "
    				;;
    		esac
    	done
    fi
}

prompt-for-database() {
    if [[ "$DESIRED_TYPE" == "$PARAM_DATABASE" ]]; then
        URL="$URL_DATABASE_AGENT"
    fi
}

replace-url() {
    # echo "replacing $URL with $VERSION_TOKEN"
    URL=$(echo "$URL" | sed -e s%$VERSION_TOKEN%$DESIRED_VERSION%g)
    # echo "Done. $URL"
}

DOWNLOAD_HOME="./archives"
PASSWORD=""
URL=""

DESIRED_VERSION=""
DESIRED_TYPE=""
DESIRED_OS=""
DESIRED_BITNESS=""
DESIRED_FORMAT=""

PARAM_DATABASE="database"
PARAM_JAVA="java"
PARAM_MACHINE="machine"
PARAM_IBM="ibm"
PARAM_SUN="sun"
PARAM_LINUX="linux"
PARAM_OSX="osx"
PARAM_32BIT="32"
PARAM_64BIT="64"
PARAM_ZIP="zip"
PARAM_RPM="rpm"

ARCHIVE_NAME=""

VERSION_TOKEN="__AGENT_VERSION__"

URL_JAVA_AGENT_IBM="https://aperture.appdynamics.com/download/prox/download-file/ibm-jvm/$VERSION_TOKEN/AppServerAgent-ibm-$VERSION_TOKEN.zip"
URL_JAVA_AGENT_SUN="https://aperture.appdynamics.com/download/prox/download-file/sun-jvm/$VERSION_TOKEN/AppServerAgent-$VERSION_TOKEN.zip"

URL_MACHINE_AGENT_LINUX_32_RPM_NOJRE="https://aperture.appdynamics.com/download/prox/download-file/machine/$VERSION_TOKEN/appdynamics-machine-agent-$VERSION_TOKEN-1.i386.rpm"
URL_MACHINE_AGENT_LINUX_64_RPM_NOJRE="https://aperture.appdynamics.com/download/prox/download-file/machine/$VERSION_TOKEN/appdynamics-machine-agent-$VERSION_TOKEN-1.x86_64.rpm"

URL_MACHINE_AGENT_UNIVERSAL_NOJRE="https://aperture.appdynamics.com/download/prox/download-file/machine/$VERSION_TOKEN/MachineAgent-$VERSION_TOKEN.zip"

URL_MACHINE_AGENT_LINUX_32_ZIP="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-32bit-linux-$VERSION_TOKEN.zip"
URL_MACHINE_AGENT_LINUX_64_ZIP="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-64bit-linux-$VERSION_TOKEN.zip"

URL_MACHINE_AGENT_OSX_64_ZIP="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-64bit-osx-$VERSION_TOKEN.zip"

URL_DATABASE_AGENT="https://aperture.appdynamics.com/download/prox/download-file/db/$VERSION_TOKEN/dbagent-$VERSION_TOKEN.zip"


main "$@"
