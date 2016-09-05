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

####### Connection Information
# Your remote hosts in the form of username@hostname
REMOTE_HOSTS="ubuntu@demosim"
# REMOTE_HOSTS="ubuntu@server1,appd@server2,jsmith@server3"

# You must provide password or SSH key but **not both** at the same time. http://docs.fabfile.org/en/1.12/usage/execution.html#password-management
REMOTE_PASSWORD_PROMPT=true
# REMOTE_SSH_KEY="./archives/my-key.pem"


####### AppDyanamics Information
# Where to install AppDynamics
REMOTE_APPD_HOME="/opt/AppDynamics/"



################################################################################

main() {
    validate-input "$@"

    local archive=$1 # Agent archive name
    declare CREDENTIALS="" # Global var to hold credentials

    validate-dependencies

    startDate=$(date '+%Y-%m-%d %H:%M:%S')
    SECONDS=0
    echo -e "Started:  $startDate"

    # Call Python Fabric to do remote management
    fab -f remote-agent-install.py --hosts "$REMOTE_HOSTS" "$CREDENTIALS" deploy_agent:archive="$archive",appd_home_dir="$REMOTE_APPD_HOME"

    # Clean up the compiled file
    rm remote-agent-install.pyc

    endTime=$(date '+%Y-%m-%d %H:%M:%S')
    duration=$SECONDS
    echo -e "Finished: $endTime. Time elsapsed: $(($duration / 60)) min, $(($duration % 60)) sec"
}

validate-dependencies() {
    # Verify that REMOTE_APPD_HOME is set
    if [[ -z ${REMOTE_APPD_HOME+x} ]]; then
        echo -e "ERROR:\n You must set the remote AppDyanmics home directory at the top of this script"
        exit 1
    fi

    # Verify that REMOTE_HOSTS is set
    if [[ -z ${REMOTE_HOSTS+x} ]]; then
        echo -e "ERROR:\n You must set the list of hosts at the top of this script"
        exit 1
    fi

    # Verify that we have either REMOTE_SSH_KEY or REMOTE_PASSWORD_PROMPT set
    if [[ ! -z ${REMOTE_SSH_KEY+x} ]]; then
        if [ ! -f "$REMOTE_SSH_KEY" ]; then
            echo -e "ERROR:\n   File not found, $REMOTE_SSH_KEY"
            exit 1
        fi

         CREDENTIALS="-i $REMOTE_SSH_KEY"

    elif [[ ! -z ${REMOTE_PASSWORD_PROMPT+x} ]]; then
         CREDENTIALS="--initial-password-prompt"

    else
        echo -e "ERROR:\n   You must set the SSH key or password prompt at the top of this script"
        exit 1
    fi
}

validate-input() {
    # Check for arguments passed in
    if [[ $# -eq 0 ]] ; then
        echo -e "Usage:\n   ./`basename "$0"` <PATH_TO_AGENT_ARCHIVE> \n"
        exit 0
    fi

    if [ ! -f "$1" ]; then
        echo -e "ERROR:\n File not found, $1"
        exit 1
    fi
}

main "$@"
