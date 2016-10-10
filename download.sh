#!/bin/bash
DL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
set -ea

################################################################################
#
# Useful for automating downloads or downloading directly onto a server.
#
# Version: __VERSION__
# Author(s): __AUTHORS__
#
################################################################################

# You can choose to set your variables here or you can pass in the the variables
# via command line. Or you will be prompted for the values if nothing is set.
EMAIL=""

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true

################################################################################
# Do Not Edit Below This Line
################################################################################

LOG_DIR="$DL_DIR/logs"
SCRIPT_NAME=$(basename -- "$0" | cut -d"." -f1)
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"

DOWNLOAD_HOME="$DL_DIR/archives"
LATEST_APPD_VERSION=""
PASSWORD=""
URL=""

DESIRED_VERSION=""
DESIRED_TYPE=""
DESIRED_OS=""
DESIRED_BITNESS=""
DESIRED_FORMAT=""

# Maybe this was overwritten
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

usage() {
    echo -e "Download AppDynamics software including agents and platform components. Pass in no artuments to be prompted for input."
    echo -e "Usage: $0"
    echo -e "\nOptional arguments:"
    echo -e "    -e=|--email=  AppDynamics username"
    echo -e "    -p=|--password=  AppDynamics password"
    echo -e "    -v=|--version=  Version, default to the latest version"
    echo -e "    -t=|--type=  Type of software {$PARAM_DATABASE, $PARAM_JAVA, $PARAM_MACHINE, $PARAM_PHP, $PARAM_DOTNET, $PARAM_APACHE, $PARAM_ANALYTICS, $PARAM_MOBILE, $PARAM_CPLUSPLUS, $PARAM_CONTROLLER, $PARAM_EUM, $PARAM_EVENTS_SERVICE}"
    echo -e "    -o=|--os=  JVM type or OS type {$PARAM_SUN, $PARAM_IBM, $PARAM_LINUX, $PARAM_WINDOWS, $PARAM_OSX, $PARAM_ANDROID, $PARAM_IOS}"
    echo -e "    -b=|--bitness=  Bitness {$PARAM_32BIT, $PARAM_64BIT}"
    echo -e "    -f=|--format=  Format {$PARAM_ZIP, $PARAM_RPM}"
    echo -e "    --help  Print usage"
}

main() {
    # We want to be able to test individual components so this will exit out if passed in 'test'
    if [[ "$1" == "test" ]]; then
        return
    fi

    prepare-logs "$LOG_DIR" "$LOG_FILE"

    # Start the process
    local startDate=$(date '+%Y-%m-%d %H:%M:%S')
    SECONDS=0
    log-info "Started:  $startDate"

    parse-args "$@"
    prompt-for-credentials

    if [[ -z "$DESIRED_VERSION" ]]; then
        set-latest-appd-version
        prompt-for-version
    fi

    prompt-for-type
    prompt-for-details

    build-url

    replace-url

    download

    local endTime=$(date '+%Y-%m-%d %H:%M:%S')
    local duration="$SECONDS"
    log-info "Finished: $endTime. Time elsapsed: $(($duration / 60)) min, $(($duration % 60)) sec"
}

download() {
    log-info "User: $EMAIL"
    log-info "Downloading: $URL"

    if [[ -z "$URL" ]]; then
        log-error "URL is empty. Aborting."
        exit 1
    fi

    # Get everything after the last slash
    ARCHIVE_NAME=$(get-everything-after-last-slash "$URL")

    if [ ! -d "$DOWNLOAD_HOME" ]; then
        mkdir "$DOWNLOAD_HOME"
    fi

    local dir="$DL_DIR"

    cd "$DOWNLOAD_HOME"

    curl -c cookies.txt -f -d "username=$EMAIL&password=$PASSWORD" https://login.appdynamics.com/sso/login/

    # TODO: Validate the login worked

    curl -L -O -b cookies.txt "$URL"
    # TODO: error check successful download
    rm -f cookies.txt

	# Change permissions if the download is a shell script.
    if [ "${ARCHIVE_NAME##*.}" == "sh" ]; then
		log-info "Changing permissions for $ARCHIVE_NAME ..."
		echo chmod 755 $ARCHIVE_NAME
		chmod 755 $ARCHIVE_NAME
    fi

    cd "$DL_DIR"

    log-info "\nAgent downloaded to $DOWNLOAD_HOME/$ARCHIVE_NAME\n"
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
            --help*)
                usage
                exit 0
                ;;
            *)
                log-error "Error parsing argument $1" >&2
                usage
                exit 1
            ;;
        esac
    done

    log-debug "parse-args() EMAIL=$EMAIL, DESIRED_VERSION=$DESIRED_VERSION, DESIRED_TYPE=$DESIRED_TYPE, DESIRED_OS=$DESIRED_OS, DESIRED_BITNESS=$DESIRED_BITNESS, DESIRED_FORMAT=$DESIRED_FORMAT"
}

build-url() {
    log-debug "build-url() EMAIL=$EMAIL, DESIRED_VERSION=$DESIRED_VERSION, DESIRED_TYPE=$DESIRED_TYPE, DESIRED_OS=$DESIRED_OS, DESIRED_BITNESS=$DESIRED_BITNESS, DESIRED_FORMAT=$DESIRED_FORMAT"

    # Java agent
    if [[ "$DESIRED_TYPE" == "$PARAM_JAVA" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_IBM" ]]; then
        URL="$URL_JAVA_AGENT_IBM"

    elif [[ "$DESIRED_TYPE" == "$PARAM_JAVA" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_SUN" ]]; then
        URL="$URL_JAVA_AGENT_SUN"
    fi

    # Machine agent
    if [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_RPM" ]]; then
        URL="$URL_MACHINE_AGENT_LINUX_32_RPM_NOJRE"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_RPM" ]]; then
        URL="$URL_MACHINE_AGENT_LINUX_64_RPM_NOJRE"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_ZIP" ]]; then
        URL="$URL_MACHINE_AGENT_LINUX_32_ZIP"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_ZIP" ]]; then
        URL="$URL_MACHINE_AGENT_LINUX_64_ZIP"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_UNIVERSAL" ]]; then
        URL="$URL_MACHINE_AGENT_UNIVERSAL_NOJRE"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_OSX" ]]; then
        URL="$URL_MACHINE_AGENT_OSX_64_ZIP"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_SUN" ]]; then
        URL="$URL_MACHINE_AGENT_SOLARIS_64_ZIP"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_MACHINE_AGENT_WINDOWS_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MACHINE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_MACHINE_AGENT_WINDOWS_64"
    fi

    # DB agent
    if [[ "$DESIRED_TYPE" == "$PARAM_DATABASE" ]]; then
        URL="$URL_DATABASE_AGENT"
    fi

    # Mobile
    if [[ "$DESIRED_TYPE" == "$PARAM_MOBILE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_IOS" ]]; then
        URL="$URL_MOBILE_AGENT_IOS"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MOBILE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_ANDROID" ]]; then
        URL="$URL_MOBILE_AGENT_ANDROID"
    fi

    # .NET agent
    if [[ "$DESIRED_TYPE" == "$PARAM_DOTNET" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_DOTNET_AGENT_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_DOTNET" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_DOTNET_AGENT_64"
    fi

    # PHP agent
    if [[ "$DESIRED_TYPE" == "$PARAM_PHP" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_ZIP" ]]; then
        URL="$URL_PHP_AGENT_LINUX_32_ZIP"

    elif [[ "$DESIRED_TYPE" == "$PARAM_PHP" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_RPM" ]]; then
        URL="$URL_PHP_AGENT_LINUX_32_RPM"

    elif [[ "$DESIRED_TYPE" == "$PARAM_PHP" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_ZIP" ]]; then
        URL="$URL_PHP_AGENT_OSX_64_ZIP"

    elif [[ "$DESIRED_TYPE" == "$PARAM_PHP" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]] \
    && [[ "$DESIRED_FORMAT" == "$PARAM_RPM" ]]; then
        URL="$URL_PHP_AGENT_LINUX_64_RPM"

    elif [[ "$DESIRED_TYPE" == "$PARAM_PHP" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_OSX" ]]; then
        URL="$URL_DOTNET_AGENT_64"
    fi

    # Apache agent
    if [[ "$DESIRED_TYPE" == "$PARAM_APACHE" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_APACHE_AGENT_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_APACHE" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_APACHE_AGENT_64"
    fi

    # Analytics agent
    if [[ "$DESIRED_TYPE" == "$PARAM_ANALYTICS" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_ANALYTICS_AGENT_WINDOWS_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_ANALYTICS" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_ANALYTICS_AGENT_WINDOWS_64"

    elif [[ "$DESIRED_TYPE" == "$PARAM_ANALYTICS" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_UNIVERSAL" ]]; then
        URL="$URL_ANALYTICS_AGENT_UNIVERSAL"
    fi

    # Mobile agent
    if [[ "$DESIRED_TYPE" == "$PARAM_MOBILE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_IOS" ]]; then
        URL="$URL_MOBILE_AGENT_IOS"

    elif [[ "$DESIRED_TYPE" == "$PARAM_MOBILE" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_ANDROID" ]]; then
        URL="$URL_MOBILE_AGENT_ANDROID"
    fi

    # C++ agent
    if [[ "$DESIRED_TYPE" == "$PARAM_CPLUSPLUS" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_CPP_AGENT_LINUX_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_CPLUSPLUS" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_CPP_AGENT_LINUX_64"

    elif [[ "$DESIRED_TYPE" == "$PARAM_CPLUSPLUS" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_CPP_AGENT_WINDOWS_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_CPLUSPLUS" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_CPP_AGENT_WINDOWS_64"
    fi

    # Controller
    if [[ "$DESIRED_TYPE" == "$PARAM_CONTROLLER" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_CONTROLLER_LINUX_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_CONTROLLER" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_CONTROLLER_LINUX_64"

    elif [[ "$DESIRED_TYPE" == "$PARAM_CONTROLLER" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_32BIT" ]]; then
        URL="$URL_CONTROLLER_WINDOWS_32"

    elif [[ "$DESIRED_TYPE" == "$PARAM_CONTROLLER" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]] \
    && [[ "$DESIRED_BITNESS" == "$PARAM_64BIT" ]]; then
        URL="$URL_CONTROLLER_WINDOWS_64"

    elif [[ "$DESIRED_TYPE" == "$PARAM_CONTROLLER" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_OSX" ]]; then
        URL="$URL_CONTROLLER_WINDOWS_64"
    fi

    # Events Service
    if [[ "$DESIRED_TYPE" == "$PARAM_EVENTS_SERVICE" ]]; then
        URL="$URL_EVENTS_SERVICE"
    fi

    # EUM
    if [[ "$DESIRED_TYPE" == "$PARAM_EUM" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_LINUX" ]]; then
        URL="$URL_EUM_SERVER_LINUX_64"

    elif [[ "$DESIRED_TYPE" == "$PARAM_EUM" ]] \
    && [[ "$DESIRED_OS" == "$PARAM_WINDOWS" ]]; then
        URL="$URL_EUM_SERVER_WINDOWS_64"
    fi

    log-debug "Determined URL='$URL'"
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

    log-debug "Version=$DESIRED_VERSION"
}

prompt-for-type() {
    local msg="What kind of software?"

    while [[ -z "$DESIRED_TYPE" ]]
    do
        echo "$msg "
        echo "Agents:"
    	echo "   1) Java agent"
        echo "   2) .NET agent"
        echo "   3) Machine agent"
    	echo "   4) Database agent"
        echo "   5) PHP agent"
    	echo "   6) Analytics agent"
    	echo "   7) Mobile agent"
    	echo "   8) Apache Web agent"
    	echo "   9) C++ agent"
        echo "Platform:"
    	echo "   10) Controller"
    	echo "   11) EUM"
    	echo "   12) Events Service"

      	read -p "" option

		case "$option" in
			1|java)
                DESIRED_TYPE="$PARAM_JAVA"
				;;
			2|.NET|.net|dotnet|dotNet)
                DESIRED_TYPE="$PARAM_DOTNET"
				;;
			3|machine)
                DESIRED_TYPE="$PARAM_MACHINE"
				;;
            4|database)
                DESIRED_TYPE="$PARAM_DATABASE"
				;;
			5|php|PHP)
                DESIRED_TYPE="$PARAM_PHP"
				;;
			6|analytics)
                DESIRED_TYPE="$PARAM_ANALYTICS"
				;;
			7|mobile)
                DESIRED_TYPE="$PARAM_MOBILE"
				;;
			8|apache|webagent)
                DESIRED_TYPE="$PARAM_APACHE"
				;;
			9|cpp|c++|cplusplus)
                DESIRED_TYPE="$PARAM_CPLUSPLUS"
				;;
			10|controller)
                DESIRED_TYPE="$PARAM_CONTROLLER"
				;;
			11|eum)
                DESIRED_TYPE="$PARAM_EUM"
				;;
			12|events|eventsservice)
                DESIRED_TYPE="$PARAM_EVENTS_SERVICE"
				;;
			*)
				;;
		esac
	done

    log-debug "DESIRED_TYPE=$DESIRED_TYPE"
}

prompt-for-details() {
    prompt-for-java-agent
    prompt-for-machine-agent
    prompt-for-database-agent
    prompt-for-dotNet-agent
    prompt-for-php-agent
    prompt-for-analytics-agent
    prompt-for-apache-agent
    prompt-for-mobile-agent
    prompt-for-cplusplus-agentsdk

    prompt-for-controller
    prompt-for-events-service
    prompt-for-end-user-monitoring

    log-debug "URL=$URL"
}

################################################################################
# Agents
prompt-for-java-agent() {
    if [[ "$DESIRED_TYPE" = "$PARAM_JAVA" ]]; then
        local msg="What kind of Java agent?"

        while [[ -z "$DESIRED_OS" ]]
        do
            echo "$msg"
    		echo "   1) Sun JVM"
            echo "   2) IBM JVM"
    	  	read -p "" option

    		case "$option" in
    			1)
                    # URL="$URL_JAVA_AGENT_SUN"
                    DESIRED_OS="$PARAM_SUN"
    				;;
    			2)
                    # URL="$URL_JAVA_AGENT_IBM"
                    DESIRED_OS="$PARAM_IBM"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-machine-agent() {
    if [[ "$DESIRED_TYPE" = "$PARAM_MACHINE" ]]; then
        local msg="What kind of Machine agent?"

        while [[ -z "$DESIRED_OS" ]] || [[ -z "$DESIRED_BITNESS" ]] || [[ -z "$DESIRED_FORMAT" ]]
        do
            echo "$msg"
    		echo "   1) Linux 64-bit JRE bundle"
            echo "   2) Linux 64-bit RPM, no JRE"
            echo "   3) Linux 32-bit JRE bundle"
            echo "   4) Linux 32-bit RPM, no JRE"
    	  	echo "   5) OS X 64-bit JRE bundle"
            echo "   6) Solaris  64-bit JRE bundle"
            echo "   7) Windows 64-bit JRE bundle"
            echo "   8) Windows 32-bit JRE bundle"
            echo "   9) Universal, no JRE"
            read -p "$msg: " option

    		case "$option" in
    			1)
                    # URL="$URL_MACHINE_AGENT_LINUX_64_ZIP"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_FORMAT="$PARAM_ZIP"
    				;;
    			2)
                    # URL="$URL_MACHINE_AGENT_LINUX_64_RPM_NOJRE"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_FORMAT="$PARAM_RPM"
    				;;
    			3)
                    # URL="$URL_MACHINE_AGENT_LINUX_32_ZIP"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_32BIT"
                    DESIRED_FORMAT="$PARAM_ZIP"
    				;;
    			4)
                    # URL="$URL_MACHINE_AGENT_LINUX_32_RPM_NOJRE"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_32BIT"
                    DESIRED_FORMAT="$PARAM_RPM"
    				;;
    			5)
                    # URL="$URL_MACHINE_AGENT_OSX_64_ZIP"
                    DESIRED_OS="$PARAM_OSX"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_FORMAT="$PARAM_ZIP"
    				;;
    			6)
                    # URL="$URL_MACHINE_AGENT_SOLARIS_64_ZIP"
                    DESIRED_OS="$PARAM_SUN"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_FORMAT="$PARAM_ZIP"
    				;;
    			7)
                    # URL="$URL_MACHINE_AGENT_WINDOWS_64"
                    DESIRED_OS="$PARAM_WINDOWS"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_FORMAT="$PARAM_ZIP"
    				;;
    			8)
                    # URL="$URL_MACHINE_AGENT_WINDOWS_32"
                    DESIRED_OS="$PARAM_WINDOWS"
                    DESIRED_BITNESS="$PARAM_32BIT"
                    DESIRED_FORMAT="$PARAM_ZIP"
    				;;
    			9)
                    # URL="$URL_MACHINE_AGENT_UNIVERSAL_NOJRE"
                    DESIRED_OS="$PARAM_UNIVERSAL"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_FORMAT="$PARAM_ZIP"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-database-agent() {
    if [[ "$DESIRED_TYPE" == "$PARAM_DATABASE" ]]; then
        URL="$URL_DATABASE_AGENT"
    fi
}

prompt-for-dotNet-agent() {
    if [[ "$DESIRED_TYPE" == "$PARAM_DOTNET" ]]; then
        local msg="What kind of .NET agent"

        while [[ -z "$DESIRED_BITNESS" ]]
        do
            echo "$msg"
    		echo "   1) Windows 64-bit"
            echo "   2) Windows 32-bit"
    	  	read -p "$msg: " option

    		case "$option" in
    			1)
                    # URL="$URL_DOTNET_AGENT_64"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			2)
                    # URL="$URL_DOTNET_AGENT_32"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-php-agent() {
    if [[ "$DESIRED_TYPE" == "$PARAM_PHP" ]]; then
        local msg="What kind of PHP agent"

        while [[ -z "$DESIRED_OS" ]] || [[ -z "$DESIRED_BITNESS" ]] || [[ -z "$DESIRED_FORMAT" ]]
        do
            echo "$msg"
    		echo "   1) Linux 64-bit"
            echo "   2) Linux 64-bit, RPM"
            echo "   3) Linux 32-bit"
            echo "   4) Linux 32-bit, RPM"
            echo "   5) OSX 64-bit Linux Zip"
    	  	read -p "$msg: " option

    		case "$option" in
                1)
                    # URL="$URL_PHP_AGENT_LINUX_64_ZIP"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_FORMAT="$PARAM_ZIP"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			2)
                    # URL="$URL_PHP_AGENT_LINUX_64_RPM"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_FORMAT="$PARAM_RPM"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
                3)
                    # URL="$URL_PHP_AGENT_LINUX_32_ZIP"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_FORMAT="$PARAM_ZIP"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
    			4)
                    # URL="$URL_PHP_AGENT_LINUX_32_RPM"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_FORMAT="$PARAM_RPM"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
    			5)
                    # URL="$URL_PHP_AGENT_OSX_64_ZIP"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_FORMAT="$PARAM_ZIP"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-analytics-agent() {
    if [[ "$DESIRED_TYPE" == "$PARAM_ANALYTICS" ]]; then
        local msg="What kind of standalone Analytics agent?"

        while [[ -z "$DESIRED_OS" ]] || [[ -z "$DESIRED_BITNESS" ]]
        do
            echo "$msg"
    		echo "   1) Universal, no JRE"
    		echo "   2) Windows 64-bit, with JRE"
            echo "   3) Windows 32-bit, with JRE"
            read -p "" option

    		case "$option" in
    			1)
                    # URL="$URL_ANALYTICS_AGENT_UNIVERSAL"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_OS="$PARAM_UNIVERSAL"
    				;;
    			2)
                    # URL="$URL_ANALYTICS_AGENT_WINDOWS_64"
                    DESIRED_BITNESS="$PARAM_64BIT"
                    DESIRED_OS="$PARAM_WINDOWS"
    				;;
    			2)
                    # URL="$URL_ANALYTICS_AGENT_WINDOWS_32"
                    DESIRED_BITNESS="$PARAM_32BIT"
                    DESIRED_OS="$PARAM_WINDOWS"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-apache-agent() {
    if [[ "$DESIRED_TYPE" == "$PARAM_APACHE" ]]; then
        local msg="What kind of Apache agent?"

        while [[ -z "$DESIRED_OS" ]] || [[ -z "$DESIRED_BITNESS" ]]
        do
            echo "$msg"
    		echo "   1) Linux 64-bit"
    		echo "   2) Linux 32-bit"
            read -p "" option

    		case "$option" in
    			1)
                    # URL="$URL_APACHE_AGENT_64"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			2)
                    # URL="$URL_APACHE_AGENT_32"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-mobile-agent() {
    if [[ "$DESIRED_TYPE" == "$PARAM_MOBILE" ]]; then
        log-debug "prompt-for-mobile-agent"

        local msg="What kind of Mobile agent?"

        while [[ -z "$DESIRED_OS" ]]
        do
            echo "$msg"
    		echo "   1) iOS"
    		echo "   2) Android"
            read -p "" option

    		case "$option" in
    			1)
                    # URL="$URL_MOBILE_AGENT_IOS"
                    DESIRED_OS="$PARAM_IOS"
    				;;
    			2)
                    # URL="$URL_MOBILE_AGENT_ANDROID"
                    DESIRED_OS="$PARAM_ANDROID"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-cplusplus-agentsdk() {
    if [[ "$DESIRED_TYPE" == "$PARAM_CPLUSPLUS" ]]; then
        local msg="What kind of C++ agent?"

        while [[ -z "$DESIRED_OS" ]] || [[ -z "$DESIRED_BITNESS" ]]
        do
            echo "$msg"
    		echo "   1) Linux 64-bit"
            echo "   2) Linux 32-bit"
            echo "   3) Windows 64-bit"
    		echo "   4) Windows 32-bit"
            read -p "" option

    		case "$option" in
    			1)
                    # URL="$URL_CPP_AGENT_LINUX_64"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			2)
                    # URL="$URL_CPP_AGENT_LINUX_32"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
                3)
                    # URL="$URL_CPP_AGENT_WINDOWS_64"
                    DESIRED_OS="$PARAM_WINDOWS"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			4)
                    # URL="$URL_CPP_AGENT_WINDOWS_32"
                    DESIRED_OS="$PARAM_WINDOWS"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}


################################################################################
# Platform
prompt-for-controller() {
    if [[ "$DESIRED_TYPE" == "$PARAM_CONTROLLER" ]]; then
        local msg="What kind of Controller installer?"

        while [[ -z "$DESIRED_OS" ]] || [[ -z "$DESIRED_BITNESS" ]]
        do
            echo "$msg"
    		echo "   1) Linux 64-bit"
            echo "   2) Linux 32-bit"
            echo "   3) Windows 64-bit"
    		echo "   4) Windows 32-bit"
            echo "   5) OSX 64-bit"
            read -p "" option

    		case "$option" in
    			1)
                    # URL="$URL_CONTROLLER_LINUX_64"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			2)
                    # URL="$URL_CONTROLLER_LINUX_32"
                    DESIRED_OS="$PARAM_LINUX"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
    			3)
                    # URL="$URL_CONTROLLER_WINDOWS_64"
                    DESIRED_OS="$PARAM_WINDOWS"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			4)
                    # URL="$URL_CONTROLLER_WINDOWS_32"
                    DESIRED_OS="$PARAM_WINDOWS"
                    DESIRED_BITNESS="$PARAM_32BIT"
    				;;
    			5)
                    # URL="$URL_CONTROLLER_OSX_64"
                    DESIRED_OS="$PARAM_OSX"
                    DESIRED_BITNESS="$PARAM_64BIT"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

prompt-for-events-service() {
    if [[ "$DESIRED_TYPE" == "$PARAM_EVENTS_SERVICE" ]]; then
        URL="$URL_EVENTS_SERVICE"
    fi
}

prompt-for-end-user-monitoring() {
    if [[ "$DESIRED_TYPE" == "$PARAM_EUM" ]]; then
        local msg="What kind of EUM installer?"

        while [[ -z "$DESIRED_OS" ]]
        do
            echo "$msg"
    		echo "   1) Linux 64-bit"
    		echo "   2) Windows 64-bit"
    		echo "   3) Geo Server"
            echo "   4) Geo Server Data File"
            read -p "" option

    		case "$option" in
    			1)
                    # URL="$URL_EUM_SERVER_LINUX_64"
                    DESIRED_OS="$PARAM_LINUX"
    				;;
    			2)
                    # URL="$URL_EUM_SERVER_WINDOWS_64"
                    DESIRED_OS="$PARAM_WINDOWS"
    				;;
    			3)
                    URL="$URL_EUM_GEO_SERVER"
                    DESIRED_OS="$PARAM_UNIVERSAL"
    				;;
    			4)
                    URL="$URL_EUM_GEO_SERVER_DATA"
                    DESIRED_OS="$PARAM_UNIVERSAL"
    				;;
    			*)
    				;;
    		esac
    	done
    fi
}

################################################################################
# Utilities
set-latest-appd-version() {
    local fileName="latest-appdynamics-version.txt"
    local url="https://raw.githubusercontent.com/derrekyoung/appd-agent-management/master/utils/$fileName"
    local version=""

    log-info "Checking for the latest version of AppDynamics"

    curl -LOks --connect-timeout 5 $url
    if [[ 0 -eq $? ]]; then
        version=$(cat "$fileName")

        log-debug "Got version from GitHub: $version"

        rm -f "$fileName"
    fi

    if [[ "$version" != 4.* ]]; then
        version=$(cat ./utils/"$fileName")
        log-debug "Got version from utils/$fileName: $version"
    fi

    LATEST_APPD_VERSION="$version"

    log-debug "Latest known version of AppDynamics: $version"
}

replace-url() {
    log-debug "Replacing $VERSION_TOKEN with $DESIRED_VERSION"

    URL=$(echo "$URL" | sed -e s%$VERSION_TOKEN%$DESIRED_VERSION%g)
}

get-everything-after-last-slash() {
    local path="$1"
    #local result=$(echo "$path" | sed 's:.*/::')
    local result=${path##*/}
    echo "$result"
}

################################################################################
# Logging
prepare-logs() {
    local logDir="$1"
    local logFile="$2"

    mkdir -p "$logDir"

    if [[ -f "$logFile" ]]; then
        rm -f "$logFile"
    fi
}

log-debug() {
    if [[ $DEBUG_LOGS = true ]]; then
        echo -e "DEBUG: $1" | tee -a "$LOG_FILE"
    fi
}

log-info() {
    echo -e "INFO:  $1" | tee -a "$LOG_FILE"
}

log-warn() {
    echo -e "WARN:  $1" | tee -a "$LOG_FILE"
}

log-error() {
    echo -e "ERROR: \n       $1" | tee -a "$LOG_FILE"
}

################################################################################
# Constants
PARAM_DATABASE="database"
PARAM_JAVA="java"
PARAM_MACHINE="machine"
PARAM_PHP="php"
PARAM_DOTNET="net"
PARAM_APACHE="apache"
PARAM_ANALYTICS="analytics"
PARAM_MOBILE="mobile"
PARAM_CPLUSPLUS="cpp"
PARAM_CONTROLLER="controller"
PARAM_EUM="eum"
PARAM_EVENTS_SERVICE="events-service"

PARAM_IBM="ibm"
PARAM_SUN="sun"
PARAM_LINUX="linux"
PARAM_WINDOWS="windows"
PARAM_OSX="osx"
PARAM_IOS="ios"
PARAM_ANDROID="android"
PARAM_UNIVERSAL="universal"

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
URL_MACHINE_AGENT_LINUX_32_ZIP="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-32bit-linux-$VERSION_TOKEN.zip"
URL_MACHINE_AGENT_LINUX_64_ZIP="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-64bit-linux-$VERSION_TOKEN.zip"
URL_MACHINE_AGENT_UNIVERSAL_NOJRE="https://aperture.appdynamics.com/download/prox/download-file/machine/$VERSION_TOKEN/MachineAgent-$VERSION_TOKEN.zip"
URL_MACHINE_AGENT_OSX_64_ZIP="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-64bit-osx-$VERSION_TOKEN.zip"
URL_MACHINE_AGENT_WINDOWS_32="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-32bit-windows-$VERSION_TOKEN.zip"
URL_MACHINE_AGENT_WINDOWS_64="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-64bit-windows-$VERSION_TOKEN.zip"
URL_MACHINE_AGENT_SOLARIS_64_ZIP="https://aperture.appdynamics.com/download/prox/download-file/machine-bundle/$VERSION_TOKEN/machineagent-bundle-64bit-solaris-x64-$VERSION_TOKEN.zip"

URL_DATABASE_AGENT="https://aperture.appdynamics.com/download/prox/download-file/db/$VERSION_TOKEN/dbagent-$VERSION_TOKEN.zip"

URL_DOTNET_AGENT_32="https://aperture.appdynamics.com/download/prox/download-file/dotnet/$VERSION_TOKEN/dotNetAgentSetup-$VERSION_TOKEN.msi"
URL_DOTNET_AGENT_64="https://aperture.appdynamics.com/download/prox/download-file/dotnet/$VERSION_TOKEN/dotNetAgentSetup64-$VERSION_TOKEN.msi"

URL_PHP_AGENT_LINUX_32_RPM="https://aperture.appdynamics.com/download/prox/download-file/php-rpm/$VERSION_TOKEN/appdynamics-php-agent.i686.rpm"
URL_PHP_AGENT_LINUX_64_RPM="https://aperture.appdynamics.com/download/prox/download-file/php-rpm/$VERSION_TOKEN/appdynamics-php-agent.x86_64.rpm"
URL_PHP_AGENT_LINUX_32_ZIP="https://aperture.appdynamics.com/download/prox/download-file/php-tar/$VERSION_TOKEN/appdynamics-php-agent-x86-linux-$VERSION_TOKEN.tar.bz2"
URL_PHP_AGENT_LINUX_64_ZIP="https://aperture.appdynamics.com/download/prox/download-file/php-tar/$VERSION_TOKEN/appdynamics-php-agent-x64-linux-$VERSION_TOKEN.tar.bz2"
URL_PHP_AGENT_OSX_64_ZIP="https://aperture.appdynamics.com/download/prox/download-file/php-osx/$VERSION_TOKEN/appdynamics-php-agent-x64-osx-$VERSION_TOKEN.tar.bz2"

URL_APACHE_AGENT_32="https://aperture.appdynamics.com/download/prox/download-file/webserver-sdk/$VERSION_TOKEN/appdynamics-sdk-native-nativeWebServer-32bit-linux-$VERSION_TOKEN.tar.gz"
URL_APACHE_AGENT_64="https://aperture.appdynamics.com/download/prox/download-file/webserver-sdk/$VERSION_TOKEN/appdynamics-sdk-native-nativeWebServer-64bit-linux-$VERSION_TOKEN.tar.gz"

URL_ANALYTICS_AGENT_UNIVERSAL="https://aperture.appdynamics.com/download/prox/download-file/analytics/$VERSION_TOKEN/analytics-agent-$VERSION_TOKEN.zip"
URL_ANALYTICS_AGENT_WINDOWS_32="https://aperture.appdynamics.com/download/prox/download-file/analytics-bundle/$VERSION_TOKEN/analytics-agent-bundle-32bit-windows-$VERSION_TOKEN.zip"
URL_ANALYTICS_AGENT_WINDOWS_64="https://aperture.appdynamics.com/download/prox/download-file/analytics-bundle/$VERSION_TOKEN/analytics-agent-bundle-64bit-windows-$VERSION_TOKEN.zip"

URL_MOBILE_AGENT_IOS="https://aperture.appdynamics.com/download/prox/download-file/ios/$VERSION_TOKEN/iOSAgent-$VERSION_TOKEN.zip"
URL_MOBILE_AGENT_ANDROID="https://aperture.appdynamics.com/download/prox/download-file/android/$VERSION_TOKEN/AndroidAgent-$VERSION_TOKEN.zip"

URL_CPP_AGENT_LINUX_64="https://aperture.appdynamics.com/download/prox/download-file/cpp-sdk/$VERSION_TOKEN/appdynamics-sdk-native-64bit-linux-$VERSION_TOKEN.tar.gz"
URL_CPP_AGENT_LINUX_32="https://aperture.appdynamics.com/download/prox/download-file/cpp-sdk/$VERSION_TOKEN/appdynamics-sdk-native-32bit-linux-$VERSION_TOKEN.tar.gz"
URL_CPP_AGENT_WINDOWS_64="https://aperture.appdynamics.com/download/prox/download-file/cpp-sdk/$VERSION_TOKEN/appdynamics-sdk-native-64bit-windows-$VERSION_TOKEN.zip"
URL_CPP_AGENT_WINDOWS_32="https://aperture.appdynamics.com/download/prox/download-file/cpp-sdk/$VERSION_TOKEN/appdynamics-sdk-native-32bit-windows-$VERSION_TOKEN.zip"

URL_CONTROLLER_LINUX_32="https://aperture.appdynamics.com/download/prox/download-file/controller/$VERSION_TOKEN/controller_32bit_linux-$VERSION_TOKEN.sh"
URL_CONTROLLER_LINUX_64="https://aperture.appdynamics.com/download/prox/download-file/controller/$VERSION_TOKEN/controller_64bit_linux-$VERSION_TOKEN.sh"
URL_CONTROLLER_WINDOWS_32="https://aperture.appdynamics.com/download/prox/download-file/controller/$VERSION_TOKEN/controller_32bit_windows-$VERSION_TOKEN.exe"
URL_CONTROLLER_WINDOWS_64="https://aperture.appdynamics.com/download/prox/download-file/controller/$VERSION_TOKEN/controller_64bit_windows-$VERSION_TOKEN.exe"
URL_CONTROLLER_OSX_64="https://aperture.appdynamics.com/download/prox/download-file/controller/$VERSION_TOKEN/controller_64bit_mac-$VERSION_TOKEN.dmg"

URL_EVENTS_SERVICE="https://aperture.appdynamics.com/download/prox/download-file/events-service/$VERSION_TOKEN/events-service-$VERSION_TOKEN.zip"

URL_EUM_SERVER_LINUX_64="https://aperture.appdynamics.com/download/prox/download-file/euem-processor/$VERSION_TOKEN/euem-64bit-linux-$VERSION_TOKEN.sh"
URL_EUM_SERVER_WINDOWS_64="https://aperture.appdynamics.com/download/prox/download-file/euem-processor/$VERSION_TOKEN/euem-64bit-windows-$VERSION_TOKEN.exe"
URL_EUM_GEO_SERVER="https://aperture.appdynamics.com/download/prox/download-file/geo/$VERSION_TOKEN/GeoServer-$VERSION_TOKEN.zip"
URL_EUM_GEO_SERVER_DATA="https://aperture.appdynamics.com/download/prox/download-file/neustar/$VERSION_TOKEN/neustar-$VERSION_TOKEN.dat"


main "$@"
