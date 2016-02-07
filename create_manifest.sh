#!/bin/bash

DIR_SEP_PATTERN="_!_"   # DO NOT USE ANY CHARACTER THAT NEEDS TO BE ESCAPED FOR USE IN REGULAR EXPRESSION SUBSTITUTION (i.e. + or *)
PARALLELISM=3   # Specify the number of manifest subsets to create from the files specified by INPUT_DIR


INPUT_DIR=$1
OUTPUT_DIR=$2


if [[ -z "$INPUT_DIR" ]]; then
  INPUT_DIR="./"
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="./manifest"
fi

if [ ! -d $OUTPUT_DIR ]; then
    mkdir -p $OUTPUT_DIR
else
    echo "Error - The output directory '$OUTPUT_DIR' is exists. Please specify another directory name."
    exit 1
fi

pushd $OUTPUT_DIR > /dev/null
MANIFEST_DIR=$(pwd)
popd > /dev/null

PARENT_DIR=$( dirname "${INPUT_DIR}" )
SOURCE_DIR=$( basename "${INPUT_DIR}" )

echo
echo -n "Creating manifest files in '$MANIFEST_DIR' "

COUNTER=0

pushd $PARENT_DIR > /dev/null
find $SOURCE_DIR -type f -print | while read FILE; do
    DIR=$( dirname "${FILE}" )
    MANIFEST_FILE="${DIR//\//$DIR_SEP_PATTERN}"

    echo $(pwd)/$FILE >> "$MANIFEST_DIR/$MANIFEST_FILE"

    let COUNTER++
    if [ $COUNTER -gt 50 ]
      then
        echo -n "."
        let COUNTER=0
    fi
done
popd > /dev/null

echo
echo
echo "Distributing manifests for parallel execution"

COUNTER=0

for F in $MANIFEST_DIR/*
do

    TMP=$MANIFEST_DIR"_$COUNTER"    
    if [ ! -d $TMP ]; then
        echo "  Creating directory '$TMP'  -  Use 'send_files.sh $TMP' to transfer files specified in '$(basename $TMP)' manifests."
        mkdir -p $TMP
    fi

    cp "$F" "$TMP" > /dev/null

    let COUNTER=COUNTER+1
    if [ $COUNTER -ge $PARALLELISM ]
        then
            let COUNTER=0
    fi

done

echo

rm -rf $OUTPUT_DIR
