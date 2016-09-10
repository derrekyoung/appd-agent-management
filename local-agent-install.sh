#!/bin/bash

source ./local-agent-config.sh "test"

################################################################################
#
# Bash script to install/update/manage local agents. Will sync:
#   controller-info.xml
#   extensions
#   runbook automation scripts
#   analytics agent props
#
# Requirements:
#   - unzip utility installed
#   - user access to the AppDynamics Home directory, APPD_AGENT_HOME
#
# Version: _VERSION_
# Author(s): _AUTHORS_
#
################################################################################

# Install directory for the AppDynamics agents. The default is where ever you run this script.
APPD_AGENT_HOME="."

AGENT_CONFIG_FILE=""

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true




################################################################################

# The agent archive to install/upgrade. Best to pass this in as an argument
ARCHIVE=""

# Set to true if this is an agent upgrade
IS_UPGRADE=false

usage() {
    echo "Usage: $0 [-a=path to agent archive] [-h=AppD home]"
    echo "Install/upgrade AppDynamics agents."
    echo "Optional params:"
    echo "    -a|--archive= Agent archive"
    echo "    -h|--appdhome= Local AppDynamics home directory"
    echo "    -c|--agentconfig= (Optional) Agent properties configuration file"
    echo "Pass in zero artuments to be prompted for input or set the variables at the top of this script to have default variables."
}

main() {
    parse-args "$@"
    prompt-for-args
    validate-args

    log-info "Installing $ARCHIVE"

    # Create install dir if not exists
    if [ ! -d "$APPD_AGENT_HOME" ]; then
        log-debug "Creating APPD home, $APPD_AGENT_HOME"
        mkdir -p "$APPD_AGENT_HOME"
    fi

    # Build a bunch of file and directory names as GLOBAL variables
    set-file-and-directory-variables "$ARCHIVE"


    # Abort if the new agent install directory already exists
    if [ -d "$newAgentInstallDirectory" ]; then
        log-error "$newAgentInstallDirectory already exits. Aborting."
        exit 0
    fi


    log-info "Unzipping $ARCHIVE into $newAgentInstallDirectory"
    # Unzip the file
    unzip -q "$ARCHIVE" -d "$newAgentInstallDirectory"


    # Build a bunch of file and directory names as GLOBAL variables
    set-agent-version-path-variables


    # Uses global variables to both instances of copy-controller.xml
    copy-controller-info

    # Sync Machine Agent extensions in monitors/. Exclude HardwareMonitor, JavaHardwareMonitor, and analytics-agent
    copy-extensions

    # Sync runbook automation scripts in MACHINE_AGENT/local-scripts
	copy-local-scripts

    # Check for Analytics enabled and sync settings if Analytics is enabled
    sync-analytics-agent

    # Delete old symlink and create new one
    handle-symlink "$APPD_AGENT_HOME" "$fileAndVersionLowercase" "$SYMLINK"

    # Update agent settings if config file passed in
    update-agent-properties "$SYMLINK" "$AGENT_CONFIG_FILE"

    log-info "Agent install finished: $fileAndVersionLowercase"
}

parse-args() {
    # Grab arguments in case there are any
    for i in "$@"
    do
        case $i in
            -a=*|--archive=*)
                ARCHIVE="${i#*=}"
                shift # past argument=value
                ;;
            -h=*|--appdhome=*)
                APPD_AGENT_HOME="${i#*=}"
                shift # past argument=value
                ;;
            -c=*|--agentconfig=*)
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
    while [[ -z "$APPD_AGENT_HOME" ]]
    do
        log-info "Enter the remote AppDynamics home/install directory: "
        read -r APPD_AGENT_HOME
    done
}

validate-args() {
    log-debug "ARCHIVE=$ARCHIVE"
    check-file-exists "$ARCHIVE"

    log-debug "APPD_AGENT_HOME=$APPD_AGENT_HOME"
    # Verify that APPD_AGENT_HOME is set
    if [[ -z "$APPD_AGENT_HOME" ]]; then
        log-error "You must set the remote AppDynamics home directory"
        usage
        exit 1
    fi

    log-debug "AGENT_CONFIG_FILE=$AGENT_CONFIG_FILE"
    if [[ $(is-empty "$AGENT_CONFIG_FILE") == "false" ]]; then
        check-file-exists "$AGENT_CONFIG_FILE"
    fi
}

# This will set a bunch fo GLOBAL variables
set-file-and-directory-variables() {
    # FooBar-1.2.3.zip becomes FooBar-1.2.3
    inputFileNameOnly=$(basename "$ARCHIVE")
    log-debug "inputFileNameOnly=$inputFileNameOnly"

    # FooBar-1.2.3 becomes foobar-1.2.3
    fileAndVersionLowercase=$(echo "$inputFileNameOnly" | awk '{print tolower($0)}' | sed -e 's/.zip//g')
    log-debug "fileAndVersionLowercase=$fileAndVersionLowercase"

    # foobar-1.2.3 becomes foobar
    fileNameOnly=$(echo "$fileAndVersionLowercase" | awk -F'-' '{print $1}')
    log-debug "fileNameOnly=$fileNameOnly"

    # Directory at ./foobar-1.2.3
    newAgentInstallDirectory="$APPD_AGENT_HOME/$fileAndVersionLowercase"
    log-debug "newAgentInstallDirectory=$newAgentInstallDirectory"

    # Directory/symlink at ./foobar
    oldAgentInstallDirectory="$APPD_AGENT_HOME/$fileNameOnly"
    log-debug "oldAgentInstallDirectory=$oldAgentInstallDirectory"

    SYMLINK="$APPD_AGENT_HOME/$fileNameOnly"
    log-debug "SYMLINK=$SYMLINK"

    if [[ -d "$oldAgentInstallDirectory" ]]; then
        IS_UPGRADE=true
    else
        IS_UPGRADE=false
    fi
}

set-agent-version-path-variables() {
    newAgentVersionPath=""
	oldAgentVersionPath=""
	# Ver the version directory
	log-debug "Setting the version directory"
    if [ -f "$newAgentInstallDirectory/machineagent.jar" ] || [ -f "$newAgentInstallDirectory/db-agent.jar" ]; then
		# log-debug "Machine or DB agent"
		newAgentVersionPath=$(ls -d "$newAgentInstallDirectory")
        log-debug "New MA/DB agent version directory newAgentVersionPath=$newAgentVersionPath"

        if [ -d "$oldAgentInstallDirectory" ]; then
    		oldAgentVersionPath=$(ls -d "$oldAgentInstallDirectory")
        	log-debug "Old MA/DB agent version directory oldAgentVersionPath=$oldAgentVersionPath"
        fi
	else
		newAgentVersionPath=$(ls -d "$newAgentInstallDirectory"/ver*)
        log-debug "New Java agent version directory newAgentVersionPath=$newAgentVersionPath"

		if [ -d "$oldAgentInstallDirectory" ]; then
			# echo "oldAgentInstallDirectory $oldAgentInstallDirectory"
			oldAgentVersionPath=$(ls -d "$oldAgentInstallDirectory"/ver*)
        	log-debug "Old Java agent version directory oldAgentVersionPath=$oldAgentVersionPath"
		fi
	fi
}

copy-file() {
    local fileName=$1
    local sourceDir=$2
    local destDir=$3

    if [ -f "$sourceDir/$fileName" ]; then
        log-info "Copying $fileName from $sourceDir to $destDir"
        cp -a "$destDir/$fileName" "$destDir/$fileName.bak"
        cp "$sourceDir/$fileName" "$destDir/$fileName"
    else
        log-debug "File not found: $sourceDir/$fileName"
    fi
}

copy-agent-properties-file() {
    if [ -d "$oldAgentInstallDirectory/conf" ]; then
        copy-file "agent.properties" "$oldAgentInstallDirectory/conf" "$newAgentInstallDirectory/conf"
    fi

    # Copy existing AGENT_HOME/verNNN/conf/controller-info.xml
    if [ -d "$oldAgentVersionPath/conf" ]; then
        copy-file "agent.properties" "$oldAgentVersionPath/conf" "$newAgentVersionPath/conf"
    fi
}

copy-controller-info() {
    # Copy existing AGENT_HOME/conf/controller-info.xml
    if [ -d "$oldAgentInstallDirectory/conf" ]; then
        copy-file "controller-info.xml" "$oldAgentInstallDirectory/conf" "$newAgentInstallDirectory/conf"
        copy-file "custom-interceptors.xml" "$oldAgentInstallDirectory/conf" "$newAgentInstallDirectory/conf"
    fi

    # Copy existing AGENT_HOME/verNNN/conf/controller-info.xml
    if [ -d "$oldAgentVersionPath/conf" ]; then
        copy-file "controller-info.xml" "$oldAgentVersionPath/conf" "$newAgentVersionPath/conf"
        copy-file "custom-activity-correlation.xml" "$oldAgentVersionPath/conf" "$newAgentVersionPath/conf"
    fi
}

# Sync Machine Agent extensions in monitors/. Exclude HardwareMonitor, JavaHardwareMonitor, and analytics-agent
copy-extensions() {
    if [ -d "$oldAgentInstallDirectory/monitors/" ]; then
        dirs=$(ls -d "$oldAgentInstallDirectory"/monitors/*)
        for dir in $dirs
        do
            if [[ $dir != *"analytics-agent"* ]] \
            && [[ $dir != *"JavaHardwareMonitor"* ]] \
            && [[ $dir != *"HardwareMonitor"* ]] \
            && [[ $dir != *"ServerMonitoringPro"* ]]; then
                local basenameDir=$(basename "$dir")
                log-info "Copying extension from $oldAgentInstallDirectory/monitors/$basenameDir/ to $newAgentInstallDirectory/monitors/$basenameDir/"
                cp -R "$oldAgentInstallDirectory/monitors/$basenameDir/" "$newAgentInstallDirectory/monitors/$basenameDir/"
            fi
        done
    fi
}

copy-local-scripts() {
    # Sync runbook automation scripts in MACHINE_AGENT/local-scripts
	if [ -d "$oldAgentInstallDirectory/local-scripts/" ]; then
		log-info "Copying local-scripts from $oldAgentInstallDirectory/local-scripts/* to $newAgentInstallDirectory/local-scripts/"
		cp -R "$oldAgentInstallDirectory/local-scripts/." "$newAgentInstallDirectory/local-scripts/"
	fi
}

sync-analytics-agent() {
    if [ -d "$oldAgentInstallDirectory/monitors/analytics-agent/" ]; then
        # log-debug "Checking if Analytics Agent is enabled"

        pathToOrigAnalyticsMonitorConfig="$oldAgentInstallDirectory/monitors/analytics-agent/monitor.xml"
        log-debug "pathToOrigAnalyticsMonitorConfig=$pathToOrigAnalyticsMonitorConfig"

        local machineAgentAnalyticsIsSet=$(is-machine-analytics-enabled "$pathToOrigAnalyticsMonitorConfig")
        log-debug "Analytics Agent enabled=$machineAgentAnalyticsIsSet"


        if [ "$machineAgentAnalyticsIsSet" == "true" ]; then
            log-info "Analytics is enabled. Copying existing Analytics Agent props"


            local pathToOrigAnalyticsProperties="$oldAgentInstallDirectory/monitors/analytics-agent/conf/analytics-agent.properties"
            log-debug "pathToOrigAnalyticsProperties=$pathToOrigAnalyticsProperties"

            local pathToNewAnalyticsMonitorConfig="$newAgentInstallDirectory/monitors/analytics-agent/monitor.xml"
            log-debug "pathToNewAnalyticsMonitorConfig=$pathToNewAnalyticsMonitorConfig"

            local pathToNewAnalyticsProperties="$newAgentInstallDirectory/monitors/analytics-agent/conf/analytics-agent.properties"
            log-debug "pathToNewAnalyticsProperties=$pathToNewAnalyticsProperties"


            local machineAgentAnalyticsEndPoint=$(grep 'http.event.endpoint=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsEndPoint=$machineAgentAnalyticsEndPoint"

            local machineAgentAnalyticsAccountName=$(grep 'http.event.accountName=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsAccountName=$machineAgentAnalyticsAccountName"

            local machineAgentAnalyticsAccessKey=$(grep 'http.event.accessKey=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsAccessKey=$machineAgentAnalyticsAccessKey"


            local machineAgentAnalyticsProxyHost=$(grep 'http.event.proxyHost=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsProxyHost=$machineAgentAnalyticsProxyHost"

            local machineAgentAnalyticsProxyPort=$(grep 'http.event.proxyPort=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsProxyPort=$machineAgentAnalyticsProxyPort"

            local machineAgentAnalyticsProxyUsername=$(grep 'http.event.proxyUsername=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsProxyUsername=$machineAgentAnalyticsProxyUsername"

            local machineAgentAnalyticsProxyPassword=$(grep 'http.event.proxyPassword=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsProxyPassword=$machineAgentAnalyticsProxyPassword"


			# Using sed to update the new config files with appropriate values taken from the original machine agent configs
			log-info "Updating the Analytics Agent configs"

			sed -i -e "s%http.event.endpoint=.*%http.event.endpoint=$machineAgentAnalyticsEndPoint%g" "$pathToNewAnalyticsProperties"
			sed -i -e "s/http.event.accountName=.*/http.event.accountName=$machineAgentAnalyticsAccountName/g" "$pathToNewAnalyticsProperties"
			sed -i -e "s/http.event.accessKey=.*/http.event.accessKey=$machineAgentAnalyticsAccessKey/g" "$pathToNewAnalyticsProperties"
			sed -i -e "s/http.event.proxyHost=.*/http.event.proxyHost=$machineAgentAnalyticsProxyHost/g" "$pathToNewAnalyticsProperties"
			sed -i -e "s/http.event.proxyPort=.*/http.event.proxyPort=$machineAgentAnalyticsProxyPort/g" "$pathToNewAnalyticsProperties"
			sed -i -e "s/http.event.proxyUsername=.*/http.event.proxyUsername=$machineAgentAnalyticsProxyUsername/g" "$pathToNewAnalyticsProperties"
			sed -i -e "s/http.event.proxyPassword=.*/http.event.proxyPassword=$machineAgentAnalyticsProxyPassword/g" "$pathToNewAnalyticsProperties"

			sed -i -e "s/<enabled>.*<\/enabled>/<enabled>true<\/enabled>/g" "$pathToNewAnalyticsMonitorConfig"

            if [[ -f "$pathToNewAnalyticsProperties-e" ]]; then
                rm -rf "$pathToNewAnalyticsProperties-e"
            fi
        fi
    fi
}

function is-machine-analytics-enabled() {
    local analyticsAgentIsSet=$(grep '<enabled>' "$pathToOrigAnalyticsMonitorConfig" | awk -F\> '{print $2}' | awk -F\< '{print $1}')

    echo "$analyticsAgentIsSet"
}

handle-symlink() {
    local parentDirectory="$1"
    local directory="$2"
    local link="$3"

    # Remove existing symlink
    if [ -d "$link" ]; then
        log-debug "Removing existing symlink $link"
        rm "$link"
    fi

    # Create the symlink
    log-info "Creating symlink from $directory/ to $link/"
    ln -s "$directory" "$link"
}

log-debug() {
    if [ "$DEBUG_LOGS" = true ]; then
        echo -e "DEBUG: $1"
    fi
}

log-info() {
    echo -e "INFO:  $1"
}

log-warn() {
    echo -e "WARN:  $1"
}

log-error() {
    echo -e "ERROR: \n       $1"
}

is-file-exists() {
    if [ ! -f "$1" ]; then
        echo "false"
    else
        echo "true"
    fi
}

is-empty() {
    local value="$1"

    if [[ -z "${value// }" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Return exit code 0 if file is found, 1 if not found.
check-file-exists() {
    if [[ $(is-file-exists "$1") == "false" ]]; then
        echo -e "ERROR: \n       File not found: $1"
        exit 1
    fi
}

# Execute the main function and get started
main "$@"
