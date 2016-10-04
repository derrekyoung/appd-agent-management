#!/bin/bash
LAI_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$LAI_DIR"/utils/local-agent-config.sh "test"
check-file-exists "$LAI_DIR/utils/local-agent-config.sh"
set -ae

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
# Version: __VERSION__
# Author(s): __AUTHORS__
#
################################################################################

# Install directory for the AppDynamics agents
APPD_AGENT_HOME="$LAI_DIR/agents"

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=false




################################################################################

LOG_DIR="$LAI_DIR/logs"
SCRIPT_NAME=$(basename -- "$0" | cut -d"." -f1)
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"

# The agent archive to install/upgrade. Best to pass this in as an argument
ARCHIVE=""

# The agent configuration properties file
# AGENT_CONFIG_FILE=""

# # Set to true if this is an agent upgrade
# IS_UPGRADE=false

usage() {
    echo -e "Install/upgrade AppDynamics agents on the local system."
    echo -e "Usage: $0"
    echo -e "\nOptional params:"
    echo -e "    -a|--archive= Agent archive"
    echo -e "    -h|--appdhome= Local AppDynamics home directory"
    echo -e "    -c|--agentconfig= (Optional) Agent properties configuration file"
    echo -e "    --help  Print usage"
}

main() {
    prepare-logs "$LOG_DIR" "$LOG_FILE"

    # Start the process
    local startDate=$(date '+%Y-%m-%d %H:%M:%S')
    SECONDS=0
    log-info "Started:  $startDate"

    lai_parse-args "$@"
    lai_prompt-for-args

    # Get us back here
    cd "$LAI_DIR"
    lai_validate-args

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


    # Unzip the file
    log-info "Unzipping $ARCHIVE into $newAgentInstallDirectory"
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

    start-agent "$SYMLINK"

    local endTime=$(date '+%Y-%m-%d %H:%M:%S')
    local duration="$SECONDS"
    log-info "Finished: $endTime. Time elsapsed: $(($duration / 60)) min, $(($duration % 60)) sec"
    
    log-info "FINISHED: Installed $fileAndVersionLowercase into $SYMLINK"
}

lai_parse-args() {
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

lai_prompt-for-args() {
    # if empty then prompt
    while [[ -z "$ARCHIVE" ]]
    do
        log-info "Enter the path to the AppDynamics agent archive: "
        read -r ARCHIVE

        if [[ ! -f "$ARCHIVE" ]]; then
            log-warn "Archive file not found: $ARCHIVE"
            ARCHIVE=""
        fi
    done

    # if empty then prompt
    while [[ -z "$APPD_AGENT_HOME" ]]
    do
        log-info "Enter the AppDynamics home/install directory: "
        read -r APPD_AGENT_HOME
    done


    # if empty then prompt
    while [[ -z "$AGENT_CONFIG_FILE" ]]
    do
        echo -e "Set agent configuration?"
        echo -e "  1) Install/update with a new agent config file"
        echo -e "  2) Don't modify agent configs:"
        echo -e "     - If new install, use blank configs"
        echo -e "     - If upgrade, keep existing configs"
        echo -e "  3) Exit"
      	read -p "" option

		case "$option" in
			1|create)
                # Calling this from $LAI_DIR/utils/local-agent-config.sh
                agent-config-start -t=create
				;;
			2|update)
                AGENT_CONFIG_FILE="silent"
				;;
			3|exit)
                echo ""
                log-info "Exiting..."
                exit 0
				;;
			*)
                echo -e " "
				;;
		esac
    done
}

lai_validate-args() {
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
    if [[ $(is-empty "$AGENT_CONFIG_FILE") == "false" ]] && [[ "$AGENT_CONFIG_FILE" != "silent" ]]; then
        check-file-exists "$AGENT_CONFIG_FILE"
    fi

    if [[ ${ARCHIVE: -4} != ".zip" ]]; then
        log-error "Sorry, only zip files supported at this time. Aborting"
        exit 1
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

    # if [[ -d "$oldAgentInstallDirectory" ]]; then
    #     IS_UPGRADE=true
    # else
    #     IS_UPGRADE=false
    # fi
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

start-agent() {
    local agentDir="$1"

    local controllerInfoXML="$agentDir/conf/controller-info.xml"
    if [[ $(is-file-exists "$controllerInfoXML") == "false" ]]; then
        log-error "File not found: $controllerInfoXML"
    fi

    local controllerHost=$(read-value-in-xml-file "$controllerInfoXML" "controller-host")
    if [[ $(is-empty "$controllerHost") == "true" ]]; then
        log-info "Controller host info not set. Not starting agent"
    fi

    if [[ "$agentDir" == *dbagent* ]]; then
        stop-dbagent
        start-dbagent "$agentDir"
    elif [[ "$agentDir" == *machineagent* ]]; then
        stop-machineagent
        start-machineagent "$agentDir"
    fi
}

start-dbagent() {
    local agentDir="$1"

    local java=`find "$agentDir/jre" -name java -type f 2> /dev/null | head -n 1 2>/dev/null`
    if [[ ! -z "$JAVA_HOME" ]] && [[ ! -z "$JAVA_HOME/bin/java" ]]; then
        java="$JAVA_HOME/bin/java"
    else
        java=$(which java)
    fi

    log-info "Starting the Database agent with $java $($java -version)"

    nohup $java -Dappdynamics.agent.uniqueHostId="$HOSTNAME" -Ddbagent.name="$HOSTNAME" -jar $agentDir/db-agent.jar > /dev/null 2>&1 &
}

stop-dbagent() {
    local process="db-agent.jar"

    local running=$(ps -ef | grep "$process" | grep -v grep| awk '{print $2}')
    if [[ -z "$running" ]]; then
        log-debug "$process is NOT running"
        return
    fi

    log-info "Stopping the Database agent"

    # Grab all processes. Grep for db-agent. Remove the grep process. Get the PID. Then do a kill on all that.
    kill -9 $running > /dev/null 2>&1
}

start-machineagent() {
    local agentHome="$1"

    local java=`find "$agentHome/jre" -name java -type f 2> /dev/null | head -n 1 2>/dev/null`
    if [ ! -z "$java" ]; then
        # Use bundled JRE by default
        :
    elif [ ! -z "$JAVA_HOME/bin/java" ]; then
        java="$JAVA_HOME/bin/java"
    else
        java=$(which java)
    fi

    log-info "Starting the Machine agent with $java $($java -version)"

    # Remove the Analytics agent PID
    rm -f "$agentHome"/monitors/analytics-agent/analytics-agent.id

    # Start the machine agent
    nohup $java -Dappdynamics.agent.uniqueHostId="$HOSTNAME" -jar $agentHome/machineagent.jar > /dev/null 2>&1 &
}

stop-machineagent() {
    local process="machineagent.jar"

	# NOTE: This will kill all machine agents on the system, might not want to do that? Check for exact match with version being installed?
	#       This will only work if the path to the machineagent.jar is fully qualified...and that will only happen if the startup script does this
	#       The fix will be to update process="$1/mach...." and pass "$agentHome" to the stop-machineagent line.
	#        This also applies to dbagent stop section.
    local running=$(ps -ef | grep "$process" | grep -v grep | awk '{print $2}')
    if [[ -z "$running" ]]; then
        log-debug "$process is NOT running"
        return
    fi

    log-info "Stopping the Machine agent"

	# TODO: We need to use just a kill without -9 to let the machine agent shutdown any extensions it might be running.  For example, HardwareMonitor scripts.
	#       We can try a regular kill and check if it's still running after a set amount of seconds, then do a kill -9
    # Grab all processes. Grep for db-agent. Remove the grep process. Get the PID. Then do a kill on all that.
    kill -9 $running > /dev/null 2>&1
}

# Execute the main function and get started
main "$@"
