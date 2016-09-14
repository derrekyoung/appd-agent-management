#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR"/utils/utilities.sh

################################################################################
#
# Utility script to deploy AppDynamics agents onto remote servers via Python Fabric.
#
# Requirements:
#   - Install Python Fabric on the machine that will run this script. *Not* required the remote servers.
#     http://www.fabfile.org/installing.html
#   - Access to local-agent-install.sh in this same directory
#
# Version: _VERSION_
# Author(s): _AUTHORS_
#
################################################################################

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true

# Environment deployment config
ENV=""

# Where to install AppDynamics
REMOTE_APPD_HOME="/opt/AppDynamics"

# An optional configuration file for agent properties (controller-info.xml, analytics-agent.properties
AGENT_CONFIG_FILE=""


################################################################################

SCRIPTS_ZIP_FILE="./dist/appd-agent-management.zip"

# The agent archive to install/upgrade. Best to pass this in as an argument
ARCHIVE=""

usage() {
    echo "Usage: $0 [-e=environment] [-a=path to agent archive] [-h=AppD home]"
    echo "Install/upgrade AppDynamics agents."
    echo "Optional params:"
    echo "    -e|--environment= Deployment environment config"
    echo "    -a|--archive= Agent archive"
    echo "    -h|--appdhome= Remote AppDynamics home directory"
    echo "    -c|--config= (optional) Agent properties configuration file"
    echo "Pass in zero artuments to be prompted for input or set the variables at the top of this script to have default variables."
}

main() {
    parse-args "$@"
    prompt-for-args
    validate-args

    mkdir -p logs/

    /bin/bash ./build.sh > /dev/null 2>&1

    startDate=$(date '+%Y-%m-%d %H:%M:%S')
    SECONDS=0
    log-info "Started:  $startDate"

    local ENV_FILE=$(get-env-file "$ENV")

    # Call Python Fabric to do remote management
    fab --fabfile ./utils/fabfile.py \
        set_env:"$ENV_FILE" \
        check_host \
        prep:archive="$ARCHIVE",scripts="$SCRIPTS_ZIP_FILE" \
        install:archive="$ARCHIVE",config="$AGENT_CONFIG_FILE" \
        cleanup:archive="$ARCHIVE",config="$AGENT_CONFIG_FILE" \
        | tee logs/"$ENV-remote-install.log"

    # Clean up the compiled file
    rm -f fabfile.pyc

    endTime=$(date '+%Y-%m-%d %H:%M:%S')
    duration="$SECONDS"
    log-info "Finished: $endTime. Time elsapsed: $(($duration / 60)) min, $(($duration % 60)) sec"
}

parse-args() {
    # Grab arguments in case there are any
    for i in "$@"
    do
        case $i in
            -e=*|--environment=*)
                ENV="${i#*=}"
                shift # past argument=value
                ;;
            -a=*|--archive=*)
                ARCHIVE="${i#*=}"
                shift # past argument=value
                ;;
            -h=*|--appdhome=*)
                REMOTE_APPD_HOME="${i#*=}"
                shift # past argument=value
                ;;
            -c=*|--config=*)
                AGENT_CONFIG_FILE="${i#*=}"
                shift # past argument=value
                ;;
            *)
                log-error "Error parsing argument $1" >&2
                usage
                exit 1
            ;;
        esac
    done
}

prompt-for-args() {
    # if empty then prompt
    while [[ -z "$ENV" ]]
    do
        log-info "Enter the environment config name: "
        read -r ENV

        local ENV_FILE=$(get-env-file "$ENV")
        if [[ ! -f "$ENV_FILE" ]]; then
            log-warn "Environment file not found, $ENV_FILE"
            ENV=""
        fi
    done

    # if empty then prompt
    while [[ -z "$ARCHIVE" ]]
    do
        log-info "Enter the path to the AppDynamics agent archive: "
        read -r ARCHIVE

        if [[ ! -f "$ARCHIVE" ]]; then
            log-warn "Archive file not found, $ARCHIVE"
            ARCHIVE=""
        fi
    done

    # if empty then prompt
    while [[ -z "$REMOTE_APPD_HOME" ]]
    do
        log-info "Enter the remote AppDyanmics home/install directory: "
        read -r REMOTE_APPD_HOME
    done

    if [[ ! -f "$AGENT_CONFIG_FILE" ]]; then
        log-info "Do you wish to update agent properties? Enter the agent config file name or leave blank:"
        read -r AGENT_CONFIG_FILE

        if [[ ! -f "$AGENT_CONFIG_FILE" ]]; then
            log-warn "Agent config file not found, $AGENT_CONFIG_FILE"
            AGENT_CONFIG_FILE=""
        fi
    fi
}

get-env-file() {
    local env="$1"
    local envFile="./conf/remote-hosts/$env.json"

    echo "$envFile"
}

validate-args() {
    local ENV_FILE=$(get-remote-hosts "$ENV")
    if [[ ! -f "$ENV_FILE" ]]; then
        log-error "Environment file not found, $ENV_FILE"
        usage
        exit 1
    fi

    if [[ ! -f "$ARCHIVE" ]]; then
        log-error "Archive file not found, $ARCHIVE"
        usage
        exit 1
    fi

    # Verify that REMOTE_APPD_HOME is set
    if [[ -z "$REMOTE_APPD_HOME" ]]; then
        log-error "You must set the remote AppDyanmics home directory"
        exit 1
    fi
}

get-remote-hosts() {
    local name="$1"
    local cfg="./conf/remote-hosts/$name.json"
    echo "$cfg"
}

main "$@"
