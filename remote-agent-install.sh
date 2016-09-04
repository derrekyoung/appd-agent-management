#!/bin/bash

################################################################################
#
# Helper script to deploy AppDynamics agents onto remote servers via Python Fabric.
#
################################################################################

# Connection information
REMOTE_HOSTS=""
REMOTE_USERNAME=""
REMOTE_PASSWORD="" # must provide password or SSH key
REMOTE_SSH_KEY=""

# Where to install AppDynamics
REMOTE_APPD_HOME="/opt/AppDynamics/"


################################################################################

main() {
    local archive=$1

    startDate=$(date '+%Y-%m-%d %H:%M:%S')
    SECONDS=0
    echo "Started:  $startDate"

    # Call Python Fabric to do remote management
    fab -f remote-agent-install.py deploy_agent:archive="$archive",appd_home_dir="$REMOTE_APPD_HOME"

    rm remote-agent-install.pyc

    endTime=$(date '+%Y-%m-%d %H:%M:%S')
    duration=$SECONDS
    echo "Finished: $endTime. Time elsapsed: $(($duration / 60)) min, $(($duration % 60)) sec"
}


# Check for arguments passed in
if [[ $# -eq 0 ]] ; then
    echo -e "Usage:\n   ./`basename "$0"` <PATH_TO_AGENT_ARCHIVE> \n"
    exit 0
fi

if [ ! -f "$1" ]; then
    echo "ERROR: File not found, $1"
    exit 1
fi

main "$@"
