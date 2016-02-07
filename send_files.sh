#!/bin/bash

DIR_SEP_PATTERN="_!_"   # DO NOT USE ANY CHARACTER THAT NEEDS TO BE ESCAPED FOR USE IN REGULAR EXPRESSION SUBSTITUTION (i.e. + or *)
SIG_CLI_DIR="./"    	# Specify the absolute path for the directory in which the SigCLI resides

OUTPUT_DIR=$1

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="./manifest"
fi

pushd $OUTPUT_DIR > /dev/null
MANIFEST_DIR=$(pwd)
TOTAL_NUM_FILES=$(ls | wc -l)
popd > /dev/null

LOG_FILE=$(dirname "${MANIFEST_DIR}")/$(basename "${MANIFEST_DIR}")"_log"
STATUS_FILE=$(dirname "${MANIFEST_DIR}")/$(basename "${MANIFEST_DIR}")"_status"

echo
echo "Total number of Manifest files to transfer: $TOTAL_NUM_FILES"
echo

pushd $SIG_CLI_DIR > /dev/null
for F in $MANIFEST_DIR/*
do

    TARGET_PATH="${F/$MANIFEST_DIR\//}"
    TARGET_PATH="${TARGET_PATH//$DIR_SEP_PATTERN//}"

    SIGCLI_OUTPUT=$(./sigcli -d upload -r udp "@$F" "sig://$TARGET_PATH")
    echo "$SIGCLI_OUTPUT" >> $LOG_FILE

    MATCH="UNKNOWN"
    DATE=$(date +"%T")
    REGEX=".+State: ([A-Z]+).+Protocol.+"
    if [[ $SIGCLI_OUTPUT =~ $REGEX ]]; then
        MATCH=${BASH_REMATCH[1]}
    fi

    STATUS="$DATE    $MATCH   $F"

    echo $STATUS
    echo $STATUS >> "$STATUS_FILE"

done
popd > /dev/null

echo
