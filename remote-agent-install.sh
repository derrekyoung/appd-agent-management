#!/bin/bash

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

####### Connection Information #######
# Your remote hosts in the form of username@hostname
declare -a REMOTE_HOSTS=("ubuntu@demosim" \
"foobar@google.com")

# You must provide password or SSH key but **not both** at the same time. http://docs.fabfile.org/en/1.12/usage/execution.html#password-management
REMOTE_PASSWORD_PROMPT=true
# REMOTE_SSH_KEY="./archives/my-key.pem"


####### AppDyanamics Information #######
# Where to install AppDynamics
REMOTE_APPD_HOME="/opt/AppDynamics/"

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true

################################################################################

main() {
    local archive=$1 # Agent archive name
    declare CREDENTIALS="" # Global var to hold credentials

    validate-input "$@"
    validate-appd-home
    validate-hosts ${REMOTE_HOSTS[@]}
    validate-and-build-credentials

    startDate=$(date '+%Y-%m-%d %H:%M:%S')
    SECONDS=0
    log-info "Started:  $startDate"

    # Call Python Fabric to do remote management
    fab -f remote-agent-install.py --hosts "$REMOTE_HOSTS" "$CREDENTIALS" deploy_agent:archive="$archive",appd_home_dir="$REMOTE_APPD_HOME"

    # Clean up the compiled file
    rm remote-agent-install.pyc

    endTime=$(date '+%Y-%m-%d %H:%M:%S')
    duration=$SECONDS
    log-info "Finished: $endTime. Time elsapsed: $(($duration / 60)) min, $(($duration % 60)) sec"
}

validate-appd-home() {
    # Verify that REMOTE_APPD_HOME is set
    if [[ -z ${REMOTE_APPD_HOME+x} ]]; then
        log-error "You must set the remote AppDyanmics home directory"
        exit 1
    fi
}

validate-and-build-credentials() {
    # Verify that we have either REMOTE_SSH_KEY or REMOTE_PASSWORD_PROMPT set
    if [[ ! -z ${REMOTE_SSH_KEY+x} ]]; then
        if [ ! -f "$REMOTE_SSH_KEY" ]; then
            log-error "File not found, $REMOTE_SSH_KEY"
            exit 1
        fi

         CREDENTIALS="-i $REMOTE_SSH_KEY"

    elif [[ ! -z ${REMOTE_PASSWORD_PROMPT+x} ]]; then
         CREDENTIALS="--initial-password-prompt"

    else
        log-error "You must set the SSH key or password prompt"
        exit 1
    fi

    log-debug "CREDENTIALS=$CREDENTIALS"
}

validate-input() {
    # Check for arguments passed in
    if [[ $# -eq 0 ]] ; then
        echo -e "Usage:\n   ./`basename "$0"` <PATH_TO_AGENT_ARCHIVE> \n"
        exit 0
    fi

    if [ ! -f "$1" ]; then
        log-error "File not found, $1"
        exit 1
    fi
}

validate-hosts() {
    local hosts=${REMOTE_HOSTS[@]}
    # echo "All Hosts: ${REMOTE_HOSTS[@]}"

    # Verify that REMOTE_HOSTS is set
    if [[ -z ${REMOTE_HOSTS+x} ]]; then
        log-error "You must define the list of hosts"
        exit 1
    fi

    for host in "${REMOTE_HOSTS[@]}"
    do
        # echo "Testing $host"
        validate-host $host
    done
}

validate-host() {
    local userHostCombo=$1

    IFS='@' read username hostname <<< "$userHostCombo"
    # echo "username=$username, hostname=$hostname"

    ping-test $hostname
}

ping-test() {
    local hostname=$1

    count=$( ping -c 1 $hostname | grep icmp* | wc -l )
    if [ $count -eq 0 ]; then
      log-error "Unable to ping $hostname"
      exit 1
    else
      log-info "Successful ping to $hostname"
    fi
}

log-info() {
    echo -e "INFO:  $1"
}

log-debug() {
    if [ $DEBUG_LOGS = true ]; then
        echo -e "DEBUG: $1"
    fi
}

log-error() {
    echo -e "ERROR: \n       $1"
}

main "$@"
