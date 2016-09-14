#!/bin/bash

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

# Install directory for the AppDynamics agents. The default is where ever you run this script.
APPD_AGENT_HOME="."

AGENT_CONFIG_FILE=""

# Flag to toggle debug logging. Values= true|false
DEBUG_LOGS=true




################################################################################
#   Do Not Edit Below This Line
################################################################################

usage() {
    echo "Usage: $0 [-e=environment] [-a=path to agent archive] [-h=AppD home]"
    echo "Install/upgrade AppDynamics agents."
    echo "Optional params:"
    echo "    -c|--config= Agent properties configuration file"
    echo "    -h|--home= Local AppDynamics home directory"
    echo "Pass in zero artuments to be prompted for input or set the variables at the top of this script to have default variables."
}

# Turning on test mode will surpress all log statements
TEST_MODE=false

declare -a CONTROLLER_INFO_XML_ELEMENTS=( "controller-host" \
    "controller-port" \
    "controller-ssl-enabled" \
    "account-name" \
    "account-access-key" \
    "application-name" \
    "tier-name" \
    "node-name"
)

main() {
    # We want to be able to test individual components so this will exit out if passed in 'test'
    if [[ "$1" == "test" ]]; then
        TEST_MODE=true
        return
    fi

    parse-args "$@"
    prompt-for-args
    validate-args

    update-agent-properties
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

    for element in "${CONTROLLER_INFO_XML_ELEMENTS[@]}"
    do
        local prop="$element"
        local value=$(read-value-in-property-file "$agentPropsFile" "$prop")
        local result=""

        # Update prop if not empty
        if [[ $(is-empty "$value") == "false" ]]; then
            log-debug "Setting $prop=$value"

            result=$(update-value-in-xml-file "$xmlFile" "$prop" "$value")

            log-debug "After update, $prop=$result"
        fi
    done

    if [[ "$value" != "$result" ]]; then
        log-warn "Failed to update element $prop. Expected: '$value'. Actual: '$result'"
    fi

    if [[ -f "$xmlFile-e" ]]; then
        rm "$xmlFile-e"
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
    fi

    if [[ "$value" != "$result" ]]; then
        log-warn "Failed to update element $element. Expected: '$value'. Actual: '$result'"
    fi

    if [[ -f "$xmlFile-e" ]]; then
        rm "$xmlFile-e"
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

    if [[ -f "$analyticsAgentPropsFile-e" ]]; then
        rm "$analyticsAgentPropsFile-e"
    fi
}

update-analytics-agent-property() {
    local propsFile="$1"
    local agentConfigFile="$2"
    local prop="$3"
    local value=$(read-value-in-property-file "$agentConfigFile" "$prop")
    local result=""

    # Update prop if not empty
    if [[ $(is-empty "$value") == "false" ]]; then
        log-debug "Setting $prop=$value"

        result=$(update-value-in-property-file "$propsFile" "$prop" "$value")

        # log-debug "After update, $prop=$result"
    fi

    if [[ "$value" != "$result" ]]; then
        log-warn "Failed to update property $prop. Expected: '$value'. Actual: '$result'"
    fi
}

read-value-in-property-file() {
    local file="$1"
    local property="$2"

    local propertyValue=$(grep -v '^$\|^\s*\#' "$file" | grep "$property=" | awk -F= '{print $2}')
    # log-debug "$property=$propertyValue in $file"

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

read-value-in-xml-file() {
    local file="$1"
    local property="$2"

    local regexFind="<$property>"
    local propertyValue=$(grep "$regexFind" "$file" | awk -F\> '{print $2}' | awk -F\< '{print $1}')

    # log-debug "$property=$propertyValue in $file"

    echo "$propertyValue"
}

update-value-in-xml-file() {
    local file="$1"
    local property="$2"
    local propertyValue="$3"

    local regexFind="<$property>.*<\/$property>"
    local regexReplace="<$property>$propertyValue<\/$property>"

    # echo "$property=$propertyValue in $file"
    # log-debug "$property=$propertyValue in $file"

    if [[ "$propertyValue" == *"%"* ]]; then
        sed -i -e "s=$regexFind=$regexReplace=g" "$file"
    else
        sed -i -e "s%$regexFind%$regexReplace%g" "$file"
    fi

    local result=$(read-value-in-xml-file "$file" "$property")
    echo "$result"
}

parse-args() {
    # Grab arguments in case there are any
    for i in "$@"
    do
        case $i in
            -c=*|--config=*)
                AGENT_CONFIG_FILE="${i#*=}"
                shift # past argument=value
                ;;
            -h=*|--appdhome=*)
                APPD_AGENT_HOME="${i#*=}"
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

validate-args() {
    if [[ ! -f "$AGENT_CONFIG_FILE" ]]; then
        log-warn "Agent config file not found, $AGENT_CONFIG_FILE"
        usage
        exit 1
    fi

    # Verify that APPD_AGENT_HOME is set
    if [[ -z "$APPD_AGENT_HOME" ]]; then
        log-error "You must set the remote AppDynamics home directory"
        exit 1
    fi
}

log-debug() {
    if [[ $DEBUG_LOGS = true ]]; then
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
        log-error "File not found: $1"
        exit 1
    fi
}

# Execute the main function and get started
main "$@"
