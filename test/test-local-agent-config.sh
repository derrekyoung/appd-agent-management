#!/bin/bash

# Put the script into test mode and surpress log output
source ../local-agent-config.sh "test"

# Set up the test variables
APPD_AGENT_HOME="./tmp"
DEBUG_LOGS=false

# Files to test upon
ANALYTICS_AGENT_PROPERTIES="$APPD_AGENT_HOME/analytics-agent.properties"
ANALYTICS_MONITOR_XML="$APPD_AGENT_HOME/analytics-monitor.xml"
JAVA_AGENT_PROPERTIES="$APPD_AGENT_HOME/java-agent.properties"
JAVA_CONTROLLER_INFO_XML="$APPD_AGENT_HOME/java-controller-info.xml"
MACHINE_CONTROLLER_INFO_XML="$APPD_AGENT_HOME/machine-controller-info.xml"
AGENT_CONFIG_SAMPLE_PROPERTIES_1="$APPD_AGENT_HOME/agent-config-sample1.properties"
AGENT_CONFIG_SAMPLE_PROPERTIES_2="$APPD_AGENT_HOME/agent-config-sample2.properties"




##############################################################################
# Tasks to setup the environment for the next test
setup-test() {

    # Create APPD_AGENT_HOME if not exists
    if [ ! -d "$APPD_AGENT_HOME" ]; then
        mkdir $APPD_AGENT_HOME
    fi

    cp ./resources/*.properties $APPD_AGENT_HOME
    cp ./resources/*.xml $APPD_AGENT_HOME

    # Helpful output
    echo "TESTING: $1()"
}

# Tasks to clean the environment for the next test
teardown-test() {
    # Remove APPD_AGENT_HOME
    if [ -d "$APPD_AGENT_HOME" ]; then
        rm -rf $APPD_AGENT_HOME
    fi

    echo " "
}

test_equals() {
    local expected="$1"
    local actual="$2"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "PASS: '$expected'"
        return 0
    else
        echo -e ">>FAIL:\n  Expected: '$expected'\n  Actual:   '$actual'"
        return 1
    fi
}

##############################################################################
# Reusable unit tests
test-read-value-in-property-file() {
    local file="$1"
    local property="$2"
    local propertyValue="$3"

    result=$(read-value-in-property-file "$file" "$property")
    test_equals "$propertyValue" "$result"
}

test-update-value-in-property-file() {
    local file="$1"
    local property="$2"
    local propertyValue="$3"

    # echo "file=$file, property=$property, propertyValue=$propertyValue"

    local result=$(update-value-in-property-file "$file" "$property" "$propertyValue")
    # echo "result=$result"

    test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "$property" "$propertyValue"
}

test-read-value-in-xml-file() {
    local file="$1"
    local property="$2"
    local propertyValue="$3"

    result=$(read-value-in-xml-file "$file" "$property")
    test_equals "$propertyValue" "$result"
}

test-update-value-in-xml-file() {
    local file="$1"
    local property="$2"
    local propertyValue="$3"

    # echo "file=$file, property=$property, propertyValue=$propertyValue"

    local result=$(update-value-in-xml-file "$file" "$property" "$propertyValue")
    # echo "result=$result"

    test-read-value-in-xml-file "$file" "$property" "$propertyValue"
}


##############################################################################
setup-test "utilities"

test_equals $(is-empty "foo") "false"
test_equals $(is-empty "") "true"
test_equals $(is-empty " ") "true"
test_equals $(is-empty "   ") "true"

teardown-test
##############################################################################

##############################################################################
setup-test "read-value-in-property-file"

test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "analytics.agent.enabled" "true"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.endpoint" "https://analytics.api.appdynamics.com:443"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accountName" "global_customerFooBar"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accessKey" "1234-asdf-1234-asdf-1234-asdf"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyHost" "proxyServer"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyPort" "789"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyUsername" "userProxy"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyPassword" "passProxy"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "foobar.property.commentedout" ""
test-read-value-in-property-file "$JAVA_AGENT_PROPERTIES" "foobar.property.commentedout" ""
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_1" "controller-host" "mycontroller.example.com"
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_1" "controller-port" "443"
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_1" "controller-ssl-enabled" "true"
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_1" "account-name" "bar_customer1"
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_1" "account-access-key" "bar-1234-bar-1234-bar-1234-bar"
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_2" "http.event.proxyHost" ""
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_2" "http.event.proxyPort" ""
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_2" "http.event.proxyUsername" ""
test-read-value-in-property-file "$AGENT_CONFIG_SAMPLE_PROPERTIES_2" "http.event.proxyPassword" ""

teardown-test
##############################################################################



##############################################################################
setup-test "update-value-in-property-file"

test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.endpoint" "asdf"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.endpoint" "https://asdf.example.com:7890"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accountName" "asdf1"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accessKey" "asdf2"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyHost" "asdf3"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyPort" "asdf4"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyUsername" "asdf5"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyPassword" "asdf6"
test-update-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyPassword" "foo%%foo"

teardown-test
##############################################################################


##############################################################################
setup-test "read-value-in-xml-file"

test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-host" "foobar.saas.appdynamics.com"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-port" "001122"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-ssl-enabled" "true"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "application-name""fooApp"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "tier-name" "fooTier"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "node-name" "fooNode"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "account-name" "fooAccount"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "account-access-key" "fooKey-fooKey-fooKey-fooKey-fooKey"
test-read-value-in-xml-file "$MACHINE_CONTROLLER_INFO_XML" "machine-path" "fooMachinePathz"
test-read-value-in-xml-file "$ANALYTICS_MONITOR_XML" "enabled" "false"

teardown-test
##############################################################################



#############################################################################
setup-test "update-value-in-xml-file"

test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-host" "bazhost"
test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-port" "baz2468"
test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-ssl-enabled" "baz"
test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "application-name""bazzApp"
test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "tier-name" "bazzTier"
test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "node-name" "bazzNode"
test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "account-name" "bazzAccount"
test-update-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "account-access-key" "bazzKey-bazzKey-bazzKey-bazzKey-bazzKey"
test-update-value-in-xml-file "$MACHINE_CONTROLLER_INFO_XML" "machine-path" "bazzMachinePathz"
test-update-value-in-xml-file "$ANALYTICS_MONITOR_XML" "enabled" "baz"
test-update-value-in-xml-file "$ANALYTICS_MONITOR_XML" "enabled" "foo%%foo"
test-update-value-in-xml-file "$ANALYTICS_MONITOR_XML" "enabled" "foo//foo"
test-update-value-in-xml-file "$ANALYTICS_MONITOR_XML" "enabled" "foo/foo"

teardown-test
#############################################################################



#############################################################################
setup-test "update-controller-info"

# Run the update and validate that it updated
update-controller-info-file "$JAVA_CONTROLLER_INFO_XML" "$AGENT_CONFIG_SAMPLE_PROPERTIES_1"

test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-host" "mycontroller.example.com"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-port" "443"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "controller-ssl-enabled" "true"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "account-name" "bar_customer1"
test-read-value-in-xml-file "$JAVA_CONTROLLER_INFO_XML" "account-access-key" "bar-1234-bar-1234-bar-1234-bar"

teardown-test
#############################################################################



#############################################################################
setup-test "update-analytics-agent-monitor-xml"

# Run the update and validate that it updated
update-analytics-agent-monitor-xml "$ANALYTICS_MONITOR_XML" "$AGENT_CONFIG_SAMPLE_PROPERTIES_1"
test-read-value-in-xml-file "$ANALYTICS_MONITOR_XML" "enabled" "true"

update-analytics-agent-monitor-xml "$ANALYTICS_MONITOR_XML" "$AGENT_CONFIG_SAMPLE_PROPERTIES_2"
test-read-value-in-xml-file "$ANALYTICS_MONITOR_XML" "enabled" "blerg"

teardown-test
#############################################################################



#############################################################################
setup-test "update-analytics-agent-props"
# DEBUG_LOGS=true

# Run the update and validate that it updated
update-analytics-agent-props "$ANALYTICS_AGENT_PROPERTIES" "$AGENT_CONFIG_SAMPLE_PROPERTIES_1"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.endpoint" "https://bar.api.appdynamics.com:443"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accountName" "global_customerBar"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accessKey" "1234-bar-1234-bar-1234-bar"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyHost" "proxyServerBar"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyPort" "789Bar"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyUsername" "userProxyBar"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.proxyPassword" "passProxyBar"

# Run the update and validate that it updated
update-analytics-agent-props "$ANALYTICS_AGENT_PROPERTIES" "$AGENT_CONFIG_SAMPLE_PROPERTIES_2"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.endpoint" "https://blerg.api.appdynamics.com:443"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accountName" "global_customerblerg"
test-read-value-in-property-file "$ANALYTICS_AGENT_PROPERTIES" "http.event.accessKey" "1234-blerg-1234-blerg-1234-blerg"

teardown-test
#############################################################################
