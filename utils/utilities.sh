#!/bin/bash

################################################################################
# String Manipulation
trim-whitespace() {
    local input="$1"
    local result=$("$input" | sed 's/^ *//g' | sed 's/ *$//g')

    echo "$result"
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
# Logging
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
