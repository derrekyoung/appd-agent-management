#!/bin/bash

###############################################################################
#
# Script to help those brand new to AppDynamics.
#
# Usage:
#   ./start-here.sh
#
###############################################################################


# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true



###############################################################################
# Do not edit below this line
###############################################################################

source ./utils/utilities.sh

# AGENT_MANAGEMENT_VERSION="0.7-BETA"
LATEST_APPD_VERSION=""

EMAIL=""
PASSWORD=""

CONTROLLER_HOST=""
CONTROLLER_PORT=""
CONTROLLER_SSL_ENABLED=""
ACCOUNT_NAME=""
ACCOUNT_ACCESS_KEY=""

DEFAULT_SAAS_CONTROLLER_PORT="443"
DEFAULT_SAAS_CONTROLLER_SSL_ENABLED="true"
DEFAULT_ON_PREM_CONTROLLER_PORT="8090"
DEFAULT_ON_PREM_CONTROLLER_SSL_ENABLED="false"

AGENT_CONFIG_FILE=""

DOWNLOAD_SCRIPT="./download.sh"
INSTALL_SCRIPT="./local-agent-install.sh"

main() {
    show-prerequisites

    set-latest-appd-version
    prompt-for-args

    # download-agent-management-suite

    create-agent-config

    echo -e "\nReady to download and locally install your Java and Machine agents"
    echo -e "Press enter to continue"
    read -p ""

    download-java-agent
    install-java-agent

    download-machine-agent
    install-machine-agent

    # download-database-agent
    # install-database-agent

    echo -e ""
    echo -e "AppDynamics downloaded and installed the Java and Machine agents."
    echo -e ""
    echo -e "Follow these instructions to complete the process and configure your application:"
    echo -e "Java agent: "
    echo -e "   1) Add '-javaagent:$(pwd)/agents/javaagent/javagent.jar' to the startup script of your Java application server"
    echo -e "   2) Restart your app server"
    echo -e "   3) Then use your app and drive traffic through it"
    echo -e "   4) You should start seeing metrics in your Controller"
    echo -e "   https://docs.appdynamics.com/display/PRO42/Instrument+Java+Applications"
    echo -e ""
    echo -e "Machine agent:"
    echo -e "   1) You should immediately start seeing metrics in your Controller"
    echo -e "   https://docs.appdynamics.com/display/PRO42/Install+the+Standalone+Machine+Agent"
    echo -e ""
    echo -e "Thank you and enjoy! \n"
}

show-prerequisites() {
    clear
    echo " "
    echo -e "Welcome to AppDynamics! "
    echo -e "Before we start, there are a few minor prerequisites:"
    echo -e "  * Username for AppDynamics.com"
    echo -e "  * Password for AppDynamics.com"
    echo -e "  * Login credentials to an AppDynamics Controller"
    echo -e ""

    local msg="Do you want to continue? [yes/no]"

    while [[ true ]]
    do
    	echo "1) Yes, continue. I'm ready!"
        echo "2) No, let's do this another time."
      	read -p "$msg: " option

		case "$option" in
			1|y|yes)
                echo -e "Let's begin...\n"
                break
				;;
			2|n|no)
                echo -e "\nGoodbye. Hope to see you again soon.\n";
                exit 0
                ;;
			*)
				echo " "
				echo "$msg: "
				;;
		esac
	done
}

prompt-for-args() {
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

    # Prompt for controller info
    # controller-host
    # account-name
    # account-access-key
    while [[ -z "$CONTROLLER_HOST" ]]
    do
        echo -n "Enter your AppDynamics Controller hostname: "
        read -r CONTROLLER_HOST

        # remove http/s, trailing slash, trim whitespace
    done

    while [[ -z "$ACCOUNT_NAME" ]]
    do
        echo -n "Enter your AppDynamics Controller account name: "
        read -r ACCOUNT_NAME

        # trim whitespace
    done

    while [[ -z "$ACCOUNT_ACCESS_KEY" ]]
    do
        echo -n "Enter your AppDynamics Controller access key: "
        read -r ACCOUNT_ACCESS_KEY

        # trim whitespace
    done

    # controller-port
    # controller-ssl-enabled
}

# Download the script suite
download-agent-management-suite() {
    local archive="appd-agent-management.zip"
    local url="https://github.com/derrekyoung/appd-agent-management/releases/download/latest/$archive"

    log-info "Downloading the scripts from $url"

    curl -LOk $url
    unzip "$archive"
    chmod u+x *.sh

    log-info "Cleaning up $archive"
    rm -f "$archive"
}

# Create an agent/controller config file based on the input received
create-agent-config() {
    log-debug "Creating agent config"
}


# Download the Java agent
download-java-agent() {
    log-info "Downloading the Java agent, version $LATEST_APPD_VERSION"
    /bin/bash "$DOWNLOAD_SCRIPT" -e="$EMAIL" -p="$PASSWORD" -t="java" -v="$LATEST_APPD_VERSION" -o="sun"
}

install-java-agent() {
    local archive=$(find ./archives -name 'AppServerAgent*' | sort | tail -1)

    log-info "Installing the Java agent"
    /bin/bash "$INSTALL_SCRIPT" -a="$archive" -c="$AGENT_CONFIG_FILE" > /dev/null 2>&1

    log-info "SUCCESS: Java agent installed\n"
}


# Download the Machine agent (Linux vs OSX)
download-machine-agent() {
    log-info "Downloading the Machine agent, version $LATEST_APPD_VERSION (this might take a while)"

    local os=$(get-operating-system)

    /bin/bash "$DOWNLOAD_SCRIPT" -e="$EMAIL" -p="$PASSWORD" -t="machine" -v="$LATEST_APPD_VERSION" -o="$os" -b="64" -f="zip"
}

install-machine-agent() {
    local archive=$(find ./archives -name 'machineagent*' | sort | tail -1)

    log-info "Installing the Machine agent"
    /bin/bash "$INSTALL_SCRIPT" -a="$archive" -c="$AGENT_CONFIG_FILE" > /dev/null 2>&1

    log-info "SUCCESS: Machine agent installed\n"
}


# Download the Database agent
download-database-agent() {
    log-info "Downloading the Database agent, version $LATEST_APPD_VERSION"

    /bin/bash "$DOWNLOAD_SCRIPT" -e="$EMAIL" -p="$PASSWORD" -t="database" -v="$LATEST_APPD_VERSION"
}

install-database-agent() {
    local archive=$(find ./archives -name 'dbagent*' | sort | tail -1)

    log-info "Installing the Database agent"
    /bin/bash "$INSTALL_SCRIPT" -a="$archive" -c="$AGENT_CONFIG_FILE" > /dev/null 2>&1

    log-info "SUCCESS: Database agent installed\n"
}


# Print instructions and links
# Instructions on how to instrument Java, -javaagent:
# Machine agent
# Set up DB agent, link to docs

get-operating-system() {
    local os=""
    if [ "$(uname)" == "Darwin" ]; then
        # Do something under Mac OS X platform
        os="osx"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        # Do something under GNU/Linux platform
        os="linux"
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
        # Do something under Windows NT platform
        log-error "Windows is not supported"
        exit 1
    fi

    echo "$os"
}

set-latest-appd-version() {
    local fileName="latest-appdynamics-version.txt"
    local url="https://raw.githubusercontent.com/derrekyoung/appd-agent-management/master/utils/$fileName"
    local version=""

    curl -LOks --connect-timeout 5 $url
    if [ 0 -eq $? ]; then
        version=$(cat "$fileName")

        log-debug "Got version from GitHub: $version"

        rm -f "$fileName"
    fi

    if [[ "$version" != 4.* ]]; then
        version=$(cat ./utils/"$fileName")
        log-debug "Got version from file: $version"
    fi

    LATEST_APPD_VERSION="$version"

    log-debug "Latest known version: $version"
}

# Execute the main function and get started
main "$@"
