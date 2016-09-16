#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR"/utilities.sh
set -ea

################################################################################
#
# Bash script to update configs for agents. Including
#   controller-info.xml
#   analytics agent props
#
# Requirements:
#   - user access to the AppDynamics Home directory, APPD_AGENT_HOME
#
# Version: _VERSION_
# Author(s): _AUTHORS_
#
################################################################################

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true



################################################################################
#   Do Not Edit Below This Line
################################################################################

# Maybe this was overwritten
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Install directory for the AppDynamics agents. The default is where ever you run this script.
APPD_AGENT_HOME=""

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

AGENT_CONF_DIR="$DIR/../conf/agent-configs"
SAMPLE_AGENT_CONF="sample.properties"
REMOTE_HOSTS_CONF_DIR="$DIR/../conf/remote-hosts"
SAMPLE_REMOTE_HOSTS_CONF="sample.json"

ACTION_CREATE="create"
ACTION_UPDATE="update"

usage() {
    echo "Usage: $0 [-t={create,update}] [-c=Path to config file] [-h=AppD home]"
    echo "Install/upgrade AppDynamics agents."
    echo "Optional params:"
    echo "    -t|--task= {create,update} The action to take: create new agent config file, update an agent in place"
    echo "    -c|--config= Agent properties configuration file"
    echo "    -h|--home= Local AppDynamics home directory"
    echo "Pass in zero artuments to be prompted for input or set the variables at the top of this script to have default variables."
}

# Turning on test mode will surpress all log statements
TEST_MODE=false

main() {
    # We want to be able to test individual components so this will exit out if passed in 'test'
    if [[ "$1" == "test" ]]; then
        TEST_MODE=true
        return
    fi

    agent-config-start "$@"
}

agent-config-start() {
    parse-args "$@"
    prompt-for-args

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

parse-args() {
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

prompt-for-args() {
    local msg="Create or update?"

    while [[ -z "$ACTION" ]]
    do
        echo "$msg"
        echo "  1) Create a new agent config file"
        echo "  2) Update an existing agent config file"
      	read -p "" ACTION

		case "$ACTION" in
			1|create)
                ACTION="$ACTION_CREATE"
				;;
			2|update)
                ACTION="$ACTION_UPDATE"
				;;
			*)
                echo " "
				;;
		esac
	done
}

prompt-for-args-create() {
    local port=""
    local customer=""

    echo " "

    while [[ -z "$ZONE" ]]
    do
        local msg="Where is your controller? "
        echo "$msg"
        echo "  1) SaaS (aka hosted by AppDynamics)"
        echo "  2) On Premises (aka you installed it)"
      	read -p "" ZONE

		case "$ZONE" in
			1|saas|SaaS)
                ZONE="$ZONE_SAAS"
				;;
			2|prem|onprem|OnPrem)
                ZONE="$ZONE_ONPREM"
				;;
			*)
                echo " "
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

    log-info "Created agent configuration file at $AGENT_CONF_DIR/$newPropsFile"
}

prompt-for-args-update() {
    # if empty then prompt
    while [[ -z "$AGENT_CONFIG_FILE" ]]
    do
        log-info "Enter the agent properties file: "
        read -r AGENT_CONFIG_FILE

        local ENV_FILE="$AGENT_CONFIG_FILE"
        if [[ ! -f "$AGENT_CONFIG_FILE" ]]; then
            log-warn "Agent config file not found, $AGENT_CONFIG_FILE"
            AGENT_CONFIG_FILE=""
        fi
    done

    # if empty then prompt
    while [[ -z "$APPD_AGENT_HOME" ]]
    do
        log-info "Enter the remote AppDyanmics home/install directory: "
        read -r APPD_AGENT_HOME
    done
}

update-agent-properties() {
    local agentHome="$1"
    local agentConfig="$2"

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

list-all-remote-hosts-configs() {
    list-all-files "$REMOTE_HOSTS_CONF_DIR"
}

list-all-remote-hosts-configs() {
    list-all-files "$AGENT_CONF_DIR"
}

list-all-files() {
    local dir="$1"
    local result=$(find "$dir" -maxdepth 1 -type f)

    echo "$result"
}

# Execute the main function and get started
main "$@"
