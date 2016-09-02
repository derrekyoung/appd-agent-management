#!/bin/bash

source ./assert.sh
source ../local-agent-install.sh

# Set up the test variables
APPD_AGENT_HOME="./tmp"
DEBUG_LOGS=true

##############################################################################
# Tasks to setup the environment for the next test
setup-test()
{
    # Remove SERVER_HOME
    if [ -d "$APPD_AGENT_HOME" ]; then
        rm -rf $APPD_AGENT_HOME
    fi

    # Create SERVER_HOME exists
    if [ ! -d "$APPD_AGENT_HOME" ]; then
        mkdir $APPD_AGENT_HOME
    fi

    # Helpful output
    echo "TESTING: $1"
}

# Tasks to clean the environment for the next test
teardown-test()
{
    echo " "
}

##############################################################################
setup-test "copy-local-scripts"
main "./resources/machineagent-bundle-64bit-linux-4.2.2.1.zip"
main "./resources/machineagent-bundle-64bit-linux-4.2.5.1.zip"
assert "copy-local-scripts foobar.pem" "foobar"
# assert "get-alias-from-cert ./foo/foobar.pem" "foobar"
# assert "get-alias-from-cert ./foo/foobar.intermediate.pem" "foobar"
# assert "get-alias-from-cert " "Required: certificate file name"
# assert_raises "validate-file $KEYSTORE_BACKUP" 0
# assert_raises "validate-file $KEYSTORE_PATH" 1
teardown-test
