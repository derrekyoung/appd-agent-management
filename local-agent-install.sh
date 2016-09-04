#!/bin/bash

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

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true




################################################################################

main() {
    local inputFile="$1"
    log-info "Installing $inputFile"

    # validate-arguments "$@"
    check-file-exists "$inputFile"

    # Create install dir if not exists
    if [ ! -d "$APPD_AGENT_HOME" ]; then
        mkdir -p "$APPD_AGENT_HOME"
    fi

    # Build a bunch of file and directory names as GLOBAL variables
    set-file-and-directory-variables "$inputFile"


    # Abort if the new agent install directory already exists
    if [ -d "$newAgentInstallDirectory" ]; then
        log-error "$newAgentInstallDirectory already exits. Aborting."
        exit 0
    fi


    log-info "Unzipping $inputFile into $newAgentInstallDirectory"
    # Unzip the file
    unzip -q "$inputFile" -d "$newAgentInstallDirectory"

    # Uses global variables to both instances of copy-controller.xml
    copy-controller-info


    # Sync Machine Agent extensions in monitors/. Exclude HardwareMonitor, JavaHardwareMonitor, and analytics-agent
    copy-extensions

    # Sync runbook automation scripts in MACHINE_AGENT/local-scripts
	copy-local-scripts

    # Check for Analytics enabled and sync settings if Analytics is enabled
    sync-analytics-agent

    # Delete old symlink and create new one
    handle-symlink "$fileAndVersionLowercase" "$fileNameOnly"
}

display_usage() {
	echo -e "Usage:\n$0 [agent filename] \n"
}

# This will set a bunch fo GLOBAL variables
set-file-and-directory-variables() {
    # FooBar-1.2.3.zip becomes FooBar-1.2.3
    inputFileNameOnly=$(basename "$inputFile")
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

copy-controller-info() {
    #
    # Copy existing AGENT_HOME/conf/controller-info.xml
    #
    copy-file "controller-info.xml" "$oldAgentInstallDirectory/conf" "$newAgentInstallDirectory/conf"
    copy-file "custom-interceptors.xml" "$oldAgentInstallDirectory/conf" "$newAgentInstallDirectory/conf"

    #
    # Copy existing AGENT_HOME/verNNN/conf/controller-info.xml
    #
    # Get and set the agent version paths
    local newAgentVersionPath=""
	local oldAgentVersionPath=""
	# Ver the version directory
	log-debug "Setting the version directory"
    if [ -f "$newAgentInstallDirectory/machineagent.jar" ] || [ -f "$newAgentInstallDirectory/db-agent.jar" ]; then
		# log-debug "Machine or DB agent"
		newAgentVersionPath=$(ls -d $newAgentInstallDirectory)
        log-debug "New MA/DB agent version directory newAgentVersionPath=$newAgentVersionPath"

        if [ -d "$oldAgentInstallDirectory" ]; then
    		oldAgentVersionPath=$(ls -d $oldAgentInstallDirectory)
        	log-debug "Old MA/DB agent version directory oldAgentVersionPath=$oldAgentVersionPath"
        fi
	else
		newAgentVersionPath=$(ls -d $newAgentInstallDirectory/ver*)
        log-debug "New Java agent version directory newAgentVersionPath=$newAgentVersionPath"

		if [ -d "$oldAgentInstallDirectory" ]; then
			# echo "oldAgentInstallDirectory $oldAgentInstallDirectory"
			oldAgentVersionPath=$(ls -d $oldAgentInstallDirectory/ver*)
        	log-debug "Old Java agent version directory oldAgentVersionPath=$oldAgentVersionPath"
		fi
	fi

    copy-file "controller-info.xml" "$oldAgentVersionPath/conf" "$newAgentVersionPath/conf"
    copy-file "custom-activity-correlation.xml" "$oldAgentVersionPath/conf" "$newAgentVersionPath/conf"
}

# Sync Machine Agent extensions in monitors/. Exclude HardwareMonitor, JavaHardwareMonitor, and analytics-agent
copy-extensions() {
    if [ -d "$oldAgentInstallDirectory/monitors/" ]; then
        dirs=$(ls -d $oldAgentInstallDirectory/monitors/*)
        for dir in $dirs
        do
            if [[ $dir != *"analytics-agent"* ]] \
            && [[ $dir != *"JavaHardwareMonitor"* ]] \
            && [[ $dir != *"HardwareMonitor"* ]] \
            && [[ $dir != *"ServerMonitoringPro"* ]]; then
                local basenameDir=$(basename $dir)
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

        local pathToOrigAnalyticsMonitorConfig="$oldAgentInstallDirectory/monitors/analytics-agent/monitor.xml"
        log-debug "pathToOrigAnalyticsMonitorConfig=$pathToOrigAnalyticsMonitorConfig"

        local pathToOrigAnalyticsProperties="$oldAgentInstallDirectory/monitors/analytics-agent/conf/analytics-agent.properties"
        log-debug "pathToOrigAnalyticsProperties=$pathToOrigAnalyticsProperties"

        local pathToNewAnalyticsMonitorConfig="$newAgentInstallDirectory/monitors/analytics-agent/monitor.xml"
        log-debug "pathToNewAnalyticsMonitorConfig=$pathToNewAnalyticsMonitorConfig"

        local pathToNewAnalyticsProperties="$newAgentInstallDirectory/monitors/analytics-agent/conf/analytics-agent.properties"
        log-debug "pathToNewAnalyticsProperties=$pathToNewAnalyticsProperties"

        # local machineAgentAnalyticsIsSet=$(perl -ne '/<enabled>(.*)<\/enabled/ && print "$1";' "$pathToOrigAnalyticsMonitorConfig")
        local machineAgentAnalyticsIsSet=$(grep '<enabled>' "$pathToOrigAnalyticsMonitorConfig" | awk -F\> '{print $2}' | awk -F\< '{print $1}')
        log-info "Analytics Agent enabled=$machineAgentAnalyticsIsSet"


        if [ "$machineAgentAnalyticsIsSet" == "true" ]; then
            log-info "Analytics is enabled. Copying existing Analytics Agent props"

			# Using perl to pull the existing values from the configs
			# local machineAgentAnalyticsEndPoint=$(perl -ne '/^http.event.endpoint=(.*)/ && print "$1";' "$pathToOrigAnalyticsProperties")
            local machineAgentAnalyticsEndPoint=$(grep 'http.event.endpoint=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsEndPoint=$machineAgentAnalyticsEndPoint"

            # local machineAgentAnalyticsAccountName=$(perl -ne '/^http.event.accountName=(.*)/ && print "$1";' "$pathToOrigAnalyticsProperties")
            local machineAgentAnalyticsAccountName=$(grep 'http.event.accountName=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsAccountName=$machineAgentAnalyticsAccountName"

            # local machineAgentAnalyticsAccessKey=$(perl -ne '/^http.event.accessKey=(.*)/ && print "$1";' "$pathToOrigAnalyticsProperties")
            local machineAgentAnalyticsAccessKey=$(grep 'http.event.accessKey=' "$pathToOrigAnalyticsProperties"| awk -F= '{print $2}')
            log-debug "machineAgentAnalyticsAccessKey=$machineAgentAnalyticsAccessKey"


			# Using sed to update the new config files with appropriate values taken from the original machine agent configs
			log-info "Updating the Analytics Agent configs"

			sed -i.bak -e "s%http.event.endpoint=.*%http.event.endpoint=$machineAgentAnalyticsEndPoint%g" -e \
						  "s/http.event.accountName=.*/http.event.accountName=$machineAgentAnalyticsAccountName/g" -e \
						  "s/http.event.accessKey=.*/http.event.accessKey=$machineAgentAnalyticsAccessKey/g" \
						  "$pathToNewAnalyticsProperties"
			sed -i.bak -e "s/<enabled>.*<\/enabled>/<enabled>true<\/enabled>/g" "$pathToNewAnalyticsMonitorConfig"
        fi
    fi
}

handle-symlink() {
    local directory="$1"
    local symlink="$2"

    # Remove existing symlink
    if [ -d "$symlink" ]; then
        log-debug "Removing existing symlink $symlink"
        rm "$symlink"
    fi

    # Create the symlink
    log-info "Creating symlink from $fileAndVersionLowercase/ to $symlink/"
    ln -s "$directory" "$symlink"
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

# Return exit code 0 if file is found, 1 if not found.
check-file-exists() {
    if [ ! -f "$1" ]; then
        echo "ERROR: File not found, $1"
        exit 1
    fi
}

# Check for arguments passed in
[ $# -eq 0 ] && { display_usage; exit 1; }

# Execute the main function and get started
main "$@"
