#!/bin/bash
LAI_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# source "$LAI_DIR"/utils/local-agent-config.sh "silent"
# check-file-exists "$LAI_DIR/utils/local-agent-config.sh"
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
DEBUG_LOGS=true




################################################################################

LOG_DIR="$LAI_DIR/logs"
SCRIPT_NAME=$(basename -- "$0" | cut -d"." -f1)
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"

# The agent archive to install/upgrade. Best to pass this in as an argument
ARCHIVE=""

AGENT_CONFIG_FILE=""

CONTROLLER_HOST=""
CONTROLLER_PORT=""
CONTROLLER_SSL_ENABLED=""
CONTROLLER_ACCOUNT_NAME=""
CONTROLLER_ACCOUNT_ACCESS_KEY=""

ZONE=""
ZONE_SAAS="saas"
ZONE_ONPREM="onprem"

DEFAULT_SAAS_CONTROLLER_PORT="443"
DEFAULT_SAAS_CONTROLLER_SSL_ENABLED="true"
DEFAULT_ON_PREM_CONTROLLER_PORT="8090"
DEFAULT_ON_PREM_CONTROLLER_SSL_ENABLED="false"
DEFAULT_ON_PREM_CONTROLLER_ACCOUNT_NAME="customer1"

AGENT_CONF_DIR="$LAI_DIR/conf/agent-configs"
SAMPLE_AGENT_CONF="sample.properties"
REMOTE_HOSTS_CONF_DIR="$LAI_DIR/conf/remote-hosts"
SAMPLE_REMOTE_HOSTS_CONF="sample.json"

ACTION_CREATE="create"
ACTION_UPDATE="update"

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
    echo -e "    -c|--agentconfig= (Optional) Agent properties configuration file. Pass in 'silent' to skip the config."
    echo -e "    --help  Print usage"
}

main() {
    # We want to be able to test individual components so this will exit out if passed in 'test'
    if [[ "$1" == "silent" ]]; then
        TEST_MODE=true
        return
    fi

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
                ACTION="$ACTION_CREATE"
                agent-config-start
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

################################################################################
# Agent Startup/Shutdown
################################################################################
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

################################################################################
# Agent Configuration
agent-config-start() {
    lac_parse-args "$@"

    prepare-logs "$LOG_DIR" "$LOG_FILE"

    lac_prompt-for-args

    if [[ "$ACTION" == "$ACTION_UPDATE" ]]; then
        prompt-for-args-update
        update-agent-properties "$APPD_AGENT_HOME" "$AGENT_CONFIG_FILE"
    elif [[ "$ACTION" == "$ACTION_CREATE" ]]; then
        prompt-for-args-create
        create-agent-properties
    else
        log-error "Invalid option: '$ACTION'"
    fi
}

lac_parse-args() {
    # Grab arguments in case there are any
    for i in "$@"
    do
        case $i in
            -c=*|--config=*)
                AGENT_CONFIG_FILE="${i#*=}"

                if [[ ! -f "$AGENT_CONFIG_FILE" ]]; then
                    log-warn "Agent config file not found, $AGENT_CONFIG_FILE"
                    usage
                    exit 1
                fi

                shift # past argument=value
                ;;

            -h=*|--appdhome=*)
                APPD_AGENT_HOME="${i#*=}"
                shift # past argument=value
                ;;

            -t=*|--task=*)
                ACTION="${i#*=}"
                shift # past argument=value
                ;;

            -host=*|--host=*)
                CONTROLLER_HOST="${i#*=}"
                shift # past argument=value
                ;;

            -port=*|--port=*)
                CONTROLLER_PORT="${i#*=}"
                shift # past argument=value
                ;;

            -ssl=*|--ssl=*)
                CONTROLLER_SSL_ENABLED="${i#*=}"
                shift # past argument=value
                ;;

            -account=*|--account=*)
                CONTROLLER_ACCOUNT_NAME="${i#*=}"
                shift # past argument=value
                ;;

            -key=*|--key=*)
                CONTROLLER_ACCOUNT_ACCESS_KEY="${i#*=}"
                shift # past argument=value
                ;;

            *)
                log-error "Error parsing argument $i" >&2
                usage
                exit 1
            ;;
        esac
    done
}

lac_prompt-for-args() {
    local msg="Create or update?"

    while [[ -z "$ACTION" ]]
    do
        echo -e "$msg"
        echo -e "  1) Create a new agent config file"
        echo -e "  2) Update an existing agent config file"
      	read -p "" ACTION

		case "$ACTION" in
			1|create)
                ACTION="$ACTION_CREATE"
				;;
			2|update)
                ACTION="$ACTION_UPDATE"
				;;
			*)
                echo -e " "
				;;
		esac
	done
}

prompt-for-args-create() {
    local port=""
    local customer=""

    echo -e " "

    while [[ -z "$ZONE" ]]
    do
        local msg="Where is your controller? "
        echo -e "$msg"
        echo -e "  1) SaaS (aka hosted by AppDynamics)"
        echo -e "  2) On Premises (aka you installed it)"
      	read -p "" ZONE

		case "$ZONE" in
			1|saas|SaaS)
                ZONE="$ZONE_SAAS"
				;;
			2|prem|onprem|OnPrem)
                ZONE="$ZONE_ONPREM"
				;;
			*)
                echo -e " "
				;;
		esac
    done

    if [[ "$ZONE" == "$ZONE_SAAS" ]]; then
        CONTROLLER_PORT="$DEFAULT_SAAS_CONTROLLER_PORT"
        CONTROLLER_SSL_ENABLED="$DEFAULT_SAAS_CONTROLLER_SSL_ENABLED"

    elif [[ "$ZONE" == "$ZONE_ONPREM" ]]; then
        CONTROLLER_ACCOUNT_NAME="$DEFAULT_ON_PREM_CONTROLLER_ACCOUNT_NAME"
        CONTROLLER_PORT="$DEFAULT_ON_PREM_CONTROLLER_PORT"
        CONTROLLER_SSL_ENABLED="$DEFAULT_ON_PREM_CONTROLLER_SSL_ENABLED"
    fi

    # Prompt for controller info
    while [[ -z "$CONTROLLER_HOST" ]]
    do
        echo -e "Enter your AppDynamics Controller hostname: "
        read -r CONTROLLER_HOST

        # remove http/s, trailing slash, trim whitespace
    done

    while [[ -z "$CONTROLLER_PORT" ]]
    do
        echo -e "Enter your AppDynamics Controller port: "
        read -r CONTROLLER_PORT

        # trim whitespace
    done

    while [[ -z "$CONTROLLER_SSL_ENABLED" ]]
    do
        echo -e "Is your AppDynamics Controller ssl enabled? "
        read -r CONTROLLER_SSL_ENABLED

        # trim whitespace
    done

    while [[ -z "$CONTROLLER_ACCOUNT_NAME" ]]
    do
        echo -e "Enter your AppDynamics Controller account name: "
        read -r CONTROLLER_ACCOUNT_NAME

        # trim whitespace
    done

    while [[ -z "$CONTROLLER_ACCOUNT_ACCESS_KEY" ]]
    do
        echo -e "Enter your AppDynamics Controller access key: "
        read -r CONTROLLER_ACCOUNT_ACCESS_KEY

        # trim whitespace
    done
}

create-agent-properties() {
    log-debug "create-agent-properties()"

    local tmp=$(echo "$CONTROLLER_HOST" | cut -d"." -f1)
    local newPropsFile="$tmp.properties"

    local PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    cd "$AGENT_CONF_DIR"

    # Copy the sample props, rename
    cp "$SAMPLE_AGENT_CONF" "$newPropsFile"

    # Update the props in that properties file
    update-value-in-property-file-with-validation "$newPropsFile" "controller-host" "$CONTROLLER_HOST"
    update-value-in-property-file-with-validation "$newPropsFile" "controller-port" "$CONTROLLER_PORT"
    update-value-in-property-file-with-validation "$newPropsFile" "controller-ssl-enabled" "$CONTROLLER_SSL_ENABLED"
    update-value-in-property-file-with-validation "$newPropsFile" "account-name" "$CONTROLLER_ACCOUNT_NAME"
    update-value-in-property-file-with-validation "$newPropsFile" "account-access-key" "$CONTROLLER_ACCOUNT_ACCESS_KEY"

    cd "$PWD"

    AGENT_CONFIG_FILE="$AGENT_CONF_DIR/$newPropsFile"

    echo ""
    log-info "Created agent configuration file at $AGENT_CONF_DIR/$newPropsFile"
}

prompt-for-args-update() {
    # if empty then prompt
    while [[ -z "$AGENT_CONFIG_FILE" ]]
    do
        list-known-agent-configs

        log-info "Enter the agent properties file to update: "
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
    done

    log-debug "Contents of $AGENT_CONFIG_FILE:"
    log-debug "$(cat $AGENT_CONFIG_FILE)"

    # if empty then prompt
    while [[ -z "$APPD_AGENT_HOME" ]]
    do
        log-info "Enter the AppDyanmics home/install directory: "
        read -r APPD_AGENT_HOME

        if [[ ! -z "$APPD_AGENT_HOME" ]] && [[ ! -d "$APPD_AGENT_HOME" ]]; then
            log-warn "Directory not found: $APPD_AGENT_HOME"
            APPD_AGENT_HOME=""
        fi
    done
}

prompt-for-args-choose-agent-config() {
    # if empty then prompt
    while [[ -z "$AGENT_CONFIG_FILE" ]]
    do
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
    done

    log-debug "Contents of $AGENT_CONFIG_FILE:"
    log-debug "$(cat $AGENT_CONFIG_FILE)"
}

update-agent-properties() {
    local agentHome="$1"
    local agentConfig="$2"

    log-debug "update-agent-properties(): agentHome=$agentHome, agentConfig=$agentConfig"

    if [[ $(is-empty "$agentConfig") == "true" ]]; then
        log-info "No agent config file passed in. Keeping existing agent configs"
        return
    fi

    if [[ $(is-file-exists "$agentConfig") == "false" ]]; then
        log-warn "Agent config file does not exist: $agentConfig"
        return
    fi

    update-controller-info-file "$agentHome/conf/controller-info.xml" "$agentConfig"

    # Is this a machine agent? Update
    if [[ -d "$agentHome/monitors/analytics-agent/" ]]; then
        update-analytics-agent "$agentHome/monitors/analytics-agent/monitor.xml" "$agentHome/monitors/analytics-agent/conf/analytics-agent.properties" "$agentConfig"
    else
        log-debug "Analytics agent not applicable"
    fi
}

# Update values in controller-info.xml
update-controller-info-file() {
    local xmlFile="$1"
    local agentPropsFile="$2"

    log-info "Updating controller-info.xml with agent props. xmlFile=$xmlFile, agentPropsFile=$agentPropsFile"

    check-file-exists "$xmlFile"
    check-file-exists "$agentPropsFile"

    update-agent-xml-file "$xmlFile" "$agentPropsFile" "controller-host"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "controller-port"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "controller-ssl-enabled"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "account-name"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "account-access-key"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "application-name"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "tier-name"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "node-name"
    update-agent-xml-file "$xmlFile" "$agentPropsFile" "sim-enabled"
}

update-agent-xml-file() {
    local xmlFile="$1"
    local agentConfigFile="$2"
    local prop="$3"

    local value=$(read-value-in-property-file "$agentPropsFile" "$prop")
    local result=""

    # Update prop if not empty
    if [[ $(is-empty "$value") == "false" ]]; then
        log-debug "Setting $prop=$value"

        result=$(update-value-in-xml-file "$xmlFile" "$prop" "$value")

        log-debug "After update, $prop=$result"

        if [[ "$value" != "$result" ]]; then
            log-warn "Failed to update element $prop. Expected: '$value'. Actual: '$result'"
        fi
    fi

    if [[ -f "$xmlFile-e" ]]; then
        rm -f "$xmlFile-e"
    fi
}

update-analytics-agent() {
    local monitorXmlFile="$1"
    local analyticsAgentPropsFile="$2"
    local agentConfigurationPropertiesFile="$3"

    log-info "Updating Analytics agent properties with agent props. monitorXmlFile=$monitorXmlFile, analyticsAgentPropsFile=$analyticsAgentPropsFile, agentPropsFile=$agentPropsFile"

    check-file-exists "$monitorXmlFile"
    check-file-exists "$analyticsAgentPropsFile"
    check-file-exists "$agentConfigurationPropertiesFile"

    # Update monitors.xml
    update-analytics-agent-monitor-xml "$monitorXmlFile" "$agentConfigurationPropertiesFile"

    # Exit if not enabled=true
    local value=$(read-value-in-xml-file "$monitorXmlFile" "enabled")

    if [[ "$value" == "false" ]]; then
        log-info "Analytics is disabled"
        return
    fi

    # Update analytics-agent.properties
    update-analytics-agent-props "$analyticsAgentPropsFile" "$agentConfigurationPropertiesFile"
}

update-analytics-agent-monitor-xml() {
    local xmlFile="$1"
    local agentConfigFile="$2"

    check-file-exists "$xmlFile"
    check-file-exists "$agentConfigFile"

    log-debug "Updating Analytics agent properties with agent props. xmlFile=$xmlFile, agentConfigFile=$agentConfigFile"

    local element="enabled"
    local prop="analytics.agent.enabled"
    local value=$(read-value-in-property-file "$agentConfigFile" "$prop")
    local result=""

    # Update prop if not empty
    if [[ $(is-empty "$value") == "false" ]]; then
        log-debug "Setting $prop=$value"

        result=$(update-value-in-xml-file "$xmlFile" "$element" "$value")

        log-debug "After update, $prop=$result"

        if [[ "$value" != "$result" ]]; then
            log-warn "Failed to update element $element. Expected: '$value'. Actual: '$result'"
        fi
    fi

    if [[ -f "$xmlFile-e" ]]; then
        rm -f "$xmlFile-e"
    fi
}

update-analytics-agent-props() {
    local analyticsAgentPropsFile="$1"
    local agentConfigFile="$2"

    check-file-exists "$analyticsAgentPropsFile"
    check-file-exists "$agentConfigFile"

    update-analytics-agent-property "$analyticsAgentPropsFile" "$agentConfigFile" "http.event.endpoint"
    update-analytics-agent-property "$analyticsAgentPropsFile" "$agentConfigFile" "http.event.accountName"
    update-analytics-agent-property "$analyticsAgentPropsFile" "$agentConfigFile" "http.event.accessKey"
    update-analytics-agent-property "$analyticsAgentPropsFile" "$agentConfigFile" "http.event.proxyHost"
    update-analytics-agent-property "$analyticsAgentPropsFile" "$agentConfigFile" "http.event.proxyPort"
    update-analytics-agent-property "$analyticsAgentPropsFile" "$agentConfigFile" "http.event.proxyUsername"
    update-analytics-agent-property "$analyticsAgentPropsFile" "$agentConfigFile" "http.event.proxyPassword"
}

update-analytics-agent-property() {
    local propsFile="$1"
    local agentConfigFile="$2"
    local prop="$3"
    local value=$(read-value-in-property-file "$agentConfigFile" "$prop")
    local result=""

    # Update prop if not empty
    if [[ $(is-empty "$value") == "false" ]]; then
        update-value-in-property-file-with-validation "$propsFile" "$prop" "$value"
    fi
}

get-everything-after-last-slash() {
    local path="$1"
    local result=$(echo "$path" | sed 's:.*/::')
    echo "$result"
}

drop-properties-extension() {
    local str="$1"
    local result=$(echo "$str" | cut -d'.' -f1)
    echo "$result"
}

list-all-agent-configs() {
    list-all-files "$AGENT_CONF_DIR"
}

list-all-files() {
    local dir="$1"
    local result=$(find "$dir" -maxdepth 1 -type f)

    echo "$result"
}

list-known-agent-configs() {
    local configFiles=$(list-all-agent-configs)
    configFiles=$(get-everything-after-last-slash "$configFiles")
    configFiles=$(drop-properties-extension "$configFiles")
    configFiles=$(echo "$configFiles" | grep -v sample)

    if [[ "$configFiles" ]]; then
        log-info "\nAvailable agent configuration files:"

        echo -e "$configFiles" | while read line; do
            echo -e "  - $line"
        done
    fi
}

get-agent-config-file() {
    local env="$1"
    local envFile="$LAI_DIR/conf/agent-configs/$env.properties"

    echo "$envFile"
}

################################################################################
# Properties Files
read-value-in-property-file() {
    local file="$1"
    local property="$2"

    local propertyValue=$(grep -v '^$\|^\s*\#' "$file" | grep "$property=" | awk -F= '{print $2}')

    echo "$propertyValue"
}

update-value-in-property-file() {
    local file="$1"
    local property="$2"
    local propertyValue="$3"

    if [[ "$propertyValue" == *"%"* ]]; then
        # echo "percent sign"
        sed -i -e "s/$property=.*/$property=$propertyValue/g" "$file"
    else
        # echo "no percent sign"
        sed -i -e "s%$property=.*%$property=$propertyValue%g" "$file"
    fi

    local result=$(read-value-in-property-file "$file" "$property")
    echo "$result"
}

update-value-in-property-file-with-validation() {
    local propsFile="$1"
    local prop="$2"
    local value="$3"
    local result=""

    log-debug "Setting $prop=$value"

    result=$(update-value-in-property-file "$propsFile" "$prop" "$value")

    # log-debug "After update, $prop=$result"

    if [[ "$value" != "$result" ]]; then
        log-warn "Failed to update property $prop. Expected: '$value'. Actual: '$result'"
    fi

    if [[ -f "$propsFile-e" ]]; then
        rm -f "$propsFile-e"
    fi
}

################################################################################
# XML Files
read-value-in-xml-file() {
    local file="$1"
    local property="$2"

    local regexFind="<$property>"
    local propertyValue=$(grep "$regexFind" "$file" | awk -F\> '{print $2}' | awk -F\< '{print $1}')

    echo "$propertyValue"
}

update-value-in-xml-file() {
    local file="$1"
    local property="$2"
    local propertyValue="$3"

    local regexFind="<$property>.*<\/$property>"
    local regexReplace="<$property>$propertyValue<\/$property>"

    if [[ "$propertyValue" == *"%"* ]]; then
        sed -i -e "s=$regexFind=$regexReplace=g" "$file"
    else
        sed -i -e "s%$regexFind%$regexReplace%g" "$file"
    fi

    local result=$(read-value-in-xml-file "$file" "$property")
    echo "$result"
}

################################################################################
# Validation
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
        log-error "File not found: $1"
        exit 1
    fi
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

# Execute the main function and get started
main "$@"
