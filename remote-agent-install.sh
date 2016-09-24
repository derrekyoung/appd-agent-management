#!/bin/bash
RAI_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$RAI_DIR"/utils/utilities.sh
check-file-exists "$RAI_DIR/utils/utilities.sh"
source "$RAI_DIR"/utils/local-agent-config.sh "test"
check-file-exists "$RAI_DIR/utils/local-agent-config.sh"
set -ea

################################################################################
#
# Utility script to deploy AppDynamics agents onto remote servers via Python Fabric.
#
# Requirements:
#   - Install Python Fabric on the machine that will run this script. *Not* required the remote servers.
#     http://www.fabfile.org/installing.html
#   - Access to local-agent-install.sh in this same directory
#
# Version: __VERSION__
# Author(s): __AUTHORS__
#
################################################################################

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true

# Where to install AppDynamics
REMOTE_APPD_HOME="/opt/AppDynamics"



###############################################################################
# Do not edit below this line
###############################################################################

SCRIPTS_ZIP_FILE="$RAI_DIR/dist/appd-agent-management.zip"

LOG_DIR="$RAI_DIR/logs"
SCRIPT_NAME=$(basename -- "$0" | cut -d"." -f1)
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"

# An optional configuration file for agent properties (controller-info.xml, analytics-agent.properties
AGENT_CONFIG_FILE=""

# Environment deployment config
ENV=""

# The agent archive to install/upgrade. Best to pass this in as an argument
ARCHIVE=""

usage() {
    echo -e "Install/upgrade AppDynamics agents on remote systems."
    echo -e "Usage: $0"
    echo -e "\nOptional params:"
    echo -e "    -e|--environment= Deployment environment config"
    echo -e "    -a|--archive= Agent archive"
    echo -e "    -c|--config= (optional) Agent properties configuration file"
    echo -e "    --help  Print usage"
}

main() {
    prepare-logs "$LOG_DIR" "$LOG_FILE"

    rai_parse-args "$@"
    rai_prompt-for-args
    rai_validate-args

    # Build the archive so we can upload it later
    /bin/bash ./build.sh > /dev/null 2>&1

    # Start the process
    local startDate=$(date '+%Y-%m-%d %H:%M:%S')
    SECONDS=0
    log-info "Started:  $startDate"

    local ENV_FILE=$(get-remote-hosts-file "$ENV")

    # Call Python Fabric to do remote management
    fab --fabfile ./utils/fabfile.py \
        set_env:"$ENV_FILE" \
        check_host \
        prep:archive="$ARCHIVE",scripts="$SCRIPTS_ZIP_FILE" \
        install:archive="$ARCHIVE",config="$AGENT_CONFIG_FILE" \
        cleanup:archive="$ARCHIVE",config="$AGENT_CONFIG_FILE" \
        | tee -a "$LOG_FILE"

    # Clean up the compiled file
    rm -f "$RAI_DIR"/utils/fabfile.pyc

    # Finished
    local endTime=$(date '+%Y-%m-%d %H:%M:%S')
    local duration="$SECONDS"
    log-info "Finished: $endTime. Time elsapsed: $(($duration / 60)) min, $(($duration % 60)) sec"
}

rai_parse-args() {
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
            -c=*|--config=*)
                AGENT_CONFIG_FILE="${i#*=}"
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
}

rai_prompt-for-args() {
    # if empty then prompt
    while [[ -z "$ENV" ]]
    do
        list-known-remote-hosts-configs
        log-info "Enter the environment config name: "
        read -r ENV

        local ENV_FILE=$(get-remote-hosts-file "$ENV")
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
        echo ""
        log-info "Do you wish to update remote agent properties? Enter the agent config name or leave blank:"
        list-known-agent-configs

        log-info "Which agent config file?"
        read -r AGENT_CONFIG_FILE

        if [[ -f "$AGENT_CONFIG_FILE" ]]; then
            log-debug "Agent config file='$AGENT_CONFIG_FILE'"
        else
            AGENT_CONFIG_FILE=$(get-agent-config-file "$AGENT_CONFIG_FILE")
            if [[ -f "$AGENT_CONFIG_FILE" ]]; then
                log-debug "Agent config file='$AGENT_CONFIG_FILE'"
            else
                AGENT_CONFIG_FILE=""
            fi
        fi

        if [[ ! -f "$AGENT_CONFIG_FILE" ]]; then
            log-warn "Agent config file not found, $AGENT_CONFIG_FILE"
            AGENT_CONFIG_FILE=""
        fi
    fi
}

list-known-remote-hosts-configs() {
    local configFiles=$(list-all-remote-hosts-configs)
    configFiles=$(get-everything-after-last-slash "$configFiles")
    configFiles=$(drop-properties-extension "$configFiles")
    configFiles=$(echo "$configFiles" | grep -v sample)

    if [[ "$configFiles" ]]; then
        log-info "\nAvailable remote hosts configuration files:"

        echo -e "$configFiles" | while read line; do
            echo -e "  - $line"
        done
    fi
}

list-all-remote-hosts-configs() {
    list-all-files "$REMOTE_HOSTS_CONF_DIR"
}

get-remote-hosts-file() {
    local env="$1"
    local envFile="./conf/remote-hosts/$env.json"

    echo "$envFile"
}

rai_validate-args() {
    local ENV_FILE=$(get-remote-hosts-file "$ENV")
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

main "$@"
