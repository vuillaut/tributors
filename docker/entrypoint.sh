#!/bin/bash

set -e

printf "Found files in workspace:\n"
ls

# GITHUB_REPOSITORY is required for actions
if [ -z "${GITHUB_REPOSITORY}" ]; then
    printf "GitHub Repository (GITHUB_REPOSITORY) environment variable is required for generation.\n"
    exit 1
fi

# GITHUB_TOKEN is recommended
if [ -z "${GITHUB_TOKEN}" ]; then
    printf "Warning, you might want to export GITHUB_TOKEN to increase API limits.\n"
else
    export PRIVATE_TOKEN="${GITHUB_TOKEN}"
fi


# Define the log level
export LOG_LEVEL="${INPUT_LOG_LEVEL}"

# Determine if we are running each parser
RUN_ALLCONTRIB="false"
RUN_ZENODO="false"
RUN_CODEMETA="false"

if [ "${INPUT_PARSERS}" == "all" ]; then
    RUN_ALLCONTRIB="true"
    RUN_ZENODO="true"
    RUN_CODEMETA="true"
elif [ "${INPUT_PARSERS}" == "unset" ]; then

    # If unset, files have to already exist
    if [ -f "${INPUT_ALLCONTRIB_FILE}" ]; then
        RUN_ALLCONTRIB="true"
    fi
    if [ -f "${INPUT_ZENODO_FILE}" ]; then
        RUN_ZENODO="true"
    fi
    if [ -f "${INPUT_CODEMETA_FILE}" ]; then
        RUN_CODEMETA="true"
    fi
elif [[ "${INPUT_PARSERS}" == *"codemeta"* ]]; then
    RUN_CODEMETA="true"
elif [[ "${INPUT_PARSERS}" == *"zenodo"* ]]; then
    RUN_ZENODO="true"
elif [[ "${INPUT_PARSERS}" == *"allcontrib"* ]]; then
    RUN_ALLCONTRIB="true"
fi

# First update via a lookup, if specified
if [ ! -z "${INPUT_UPDATE_LOOKUP}" ]; then
    tributors update-lookup "${INPUT_UPDATE_LOOKUP}" --mailmap-file "${INPUT_MAILMAP_FILE}" --allcontrib-file "${INPUT_ALLCONTRIB_FILE}" --zenodo-file "${INPUT_ZENODO_FILE}" --codemeta-file "${INPUT_CODEMETA_FILE}" --skip-users "${INPUT_SKIP_USERS}"
fi

# Update the user:
printf "Run zenodo: ${RUN_ZENODO}\n"
printf "Run allcontrib: ${RUN_ALLCONTRIB}\n"
printf "Run codemeta: ${RUN_CODEMETA}\n"

# The .all-contributorsrc is required, generate headless if doesn't exist
if [ ! -f "${INPUT_ALLCONTRIB_FILE}" ] && [ "${RUN_ALLCONTRIB}" == "true" ]; then
    printf "Generating ${INPUT_ALLCONTRIB_FILE} for ${GITHUB_REPOSITORY}\n"
    tributors init allcontrib --skip-users "${INPUT_SKIP_USERS}"
    cat "${INPUT_ALLCONTRIB_FILE}"
else
    printf "${INPUT_ALLCONTRIB_FILE} already exists.\n"
fi

# If a Zenodo DOI is set, use it to init the repository
if [ ! -z "${INPUT_ZENODO_DOI}" ] && [ "${RUN_ZENODO}" == "true" ]; then
    if [ "$INPUT_FORCE" == "true" ]; then
        tributors init zenodo --doi "${INPUT_ZENODO_DOI}" --zenodo-file "${INPUT_ZENODO_FILE}" --force --skip-users "${INPUT_SKIP_USERS}"
    else
        tributors init zenodo --doi "${INPUT_ZENODO_DOI}" --zenodo-file "${INPUT_ZENODO_FILE}" --skip-users "${INPUT_SKIP_USERS}"
    fi
fi

# Update all types request
COMMAND="tributors update ${INPUT_PARSERS} --thresh ${INPUT_THRESHOLD} --skip-users ${INPUT_SKIP_USERS}"
if [ ! -z "${INPUT_ALLCONTRIB_TYPE}" ] && [ "${RUN_ALLCONTRIB}" == "true" ]; then
    COMMAND="${COMMAND} --allcontrib-type ${INPUT_ALLCONTRIB_TYPE}"
fi
if [ "${RUN_CODEMETA}" == "true" ]; then
    COMMAND="${COMMAND} --codemeta-file ${INPUT_CODEMETA_FILE}"
fi

echo $COMMAND

# First time might just create content
$COMMAND

# Run twice to get additional metadata
if [ "${INPUT_RUN_TWICE:-true}" == "true" ]; then
    printf "Running twice to get additional updates...\n"
    $COMMAND
fi

# Finally, run all-contributors generate
if [ "${INPUT_ALLCONTRIB_SKIP_GENERATE}" == "false" ]; then
    printf "Running all-contributors generate\n"
    cli.js generate
fi
