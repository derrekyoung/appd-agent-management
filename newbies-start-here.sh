#!/bin/bash
SH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SH_DIR"/utils/utilities.sh
SH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SH_DIR"/utils/local-agent-config.sh "test"
set -ea

###############################################################################
#
# Script to help those brand new to AppDynamics.
#
# Usage:
#   ./newbies-start-here.sh
#
# curl -LOk https://github.com/derrekyoung/appd-agent-management/releases/download/latest/appd-agent-management.zip \
# && unzip appd-agent-management.zip -d AppDynamics \
# && cd AppDynamics \
# && chmod u+x *.sh \
# && /bin/bash ./newbies-start-here.sh
#
###############################################################################

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true


###############################################################################
# Do not edit below this line
###############################################################################

LATEST_APPD_VERSION=""
EMAIL=""
PASSWORD=""

# Maybe this was overwritten
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOWNLOAD_SCRIPT="$SH_DIR/download.sh"
INSTALL_SCRIPT="$SH_DIR/local-agent-install.sh"
# AGENT_CONFIG_SCRIPT="$SH_DIR/utils/local-agent-config.sh"

main() {
    show-prerequisites

    prompt-for-credentials
    agent-config-start -t="create"
    cd "$SH_DIR"

    set-latest-appd-version

    echo ""
    log-info "Ready to download and locally install your Java and Machine agents"
    log-info "Press enter to continue"
    read -p ""

    download-java-agent
    install-java-agent

    download-machine-agent
    install-machine-agent

    # download-database-agent
    # install-database-agent

    echo -e ""
    echo -e "Hooray! AppDynamics downloaded and installed the Java and Machine agents."
    echo -e ""
    echo -e "Follow these instructions to complete the process and configure your application:"
    echo -e "Java agent: "
    echo -e "   1) Add '-javaagent:$(pwd)/agents/javaagent/javagent.jar' to the startup script of your Java application server"
    echo -e "   2) Restart your app server"
    echo -e "   3) Then open your app and push some traffic through it"
    echo -e "   4) You should start seeing metrics in your Controller"
    echo -e "   https://docs.appdynamics.com/display/PRO42/Instrument+Java+Applications"
    echo -e ""
    echo -e "Machine agent:"
    echo -e "   1) You should immediately see metrics in your Controller"
    echo -e "   https://docs.appdynamics.com/display/PRO42/Install+the+Standalone+Machine+Agent"
    echo -e ""
    echo -e "Thank you and enjoy! \n"
}

show-prerequisites() {
    clear
    echo " "
    echo -e "Welcome to AppDynamics! "
    echo -e "Before we start, there are a few minor prerequisites:"
    echo -e "  * Email address for AppDynamics.com"
    echo -e "  * Password for AppDynamics.com"
    echo -e "  * Your AppDynamics Controller host name"
    echo -e "  * Your AppDynamics Controller account name"
    echo -e "  * Your AppDynamics Controller account access key"
    echo -e "  * 'curl' command needs to be installed on this host"
    echo -e ""

    local msg="Do you want to continue? [yes/no]"

    while [[ true ]]
    do
        echo "$msg"
    	echo "  1) Yes, continue. I'm ready!"
        echo "  2) No, let's do this another time."
      	read -p "" option

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
				;;
		esac
	done
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

# # Download the script suite
# download-agent-management-suite() {
#     local archive="appd-agent-management.zip"
#     local url="https://github.com/derrekyoung/appd-agent-management/releases/download/latest/$archive"
#
#     log-info "Downloading the scripts from $url"
#
#     curl -LOk $url
#     unzip "$archive"
#     chmod u+x *.sh
#
#     log-info "Cleaning up $archive"
#     rm -f "$archive"
# }


# Download the Java agent
download-java-agent() {
    log-info "Downloading the Java agent, version $LATEST_APPD_VERSION"
    /bin/bash "$DOWNLOAD_SCRIPT" -e="$EMAIL" -p="$PASSWORD" -t="java" -v="$LATEST_APPD_VERSION" -o="sun"
    log-info "SUCCESS: Java agent downloaded\n"
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
    log-info "SUCCESS: Machine agent downloaded\n"
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
    log-info "SUCCESS: Database agent downloaded\n"
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

    log-info "Checking for the latest version of AppDynamics"

    set +e
    curl -LOks --connect-timeout 5 $url
    if [[ 0 -eq $? ]]; then
        version=$(cat "$fileName")

        log-debug "Got version from GitHub: $version"

        rm -f "$fileName"
    fi
    set -e

    if [[ "$version" != 4.* ]]; then
        version=$(cat ./utils/"$fileName")
        log-debug "Got version from file: $version"
    fi

    LATEST_APPD_VERSION="$version"

    log-info "Latest known version of AppDynamics: $version"
}

# Execute the main function and get started
main "$@"
