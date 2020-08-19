#!/usr/bin/env bash

# This file contains useful functions for tests
# of the sonar-scanner.

# Default values of environment variables
if [ -z "$SONARQUBE_CONTAINER_NAME" ]
then
    export SONARQUBE_CONTAINER_NAME=lequalsonarqube
fi

if [ -z "$SONARQUBE_ADMIN_PASSWORD" ]
then
    export SONARQUBE_ADMIN_PASSWORD="adminpassword"
fi

if [ -z "$SONARQUBE_URL" ]
then
    export SONARQUBE_URL="http://$SONARQUBE_CONTAINER_NAME:9000"
fi

if [ -z "$SONARQUBE_LOCAL_URL" ]
then
    export SONARQUBE_LOCAL_URL="http://localhost:9000"
fi

if [ -z "$SONARQUBE_TAG" ]
then
    export SONARQUBE_TAG=latest
fi

if [ -z "$SONARQUBE_NETWORK" ]
then
    export SONARQUBE_NETWORK=sonarbridge
fi

# ============================================================================ #

# log
#
# This function logs a line.
# Log levels are: INFO, ERROR
# INFO are logged on STDOUT.
# ERROR are logged on STDERR.
#
# Parameters:
#   1: level of log
#   2: message to log
#
# Example:
#   $ log "$ERROR" "Something went wrong"
export INFO="INFO"
export ERROR="ERROR"
log()
{
    msg="[$1] Test CNES sonar-scanner: $2"
    if [ "$1" = "$INFO" ]
    then
        echo "$msg"
    else
        >&2 echo "$msg, raised by ${0##*/}"
    fi
}

# wait_cnes_sonarqube_ready
#
# This function waits for SonarQube to be configured by
# the configure.bash script.
# If this function is run in background, call wait
# at some point.
#
# Parameters:
#   1: name of the container running lequal/sonarqube
#
# Example:
#   $ wait_cnes_sonarqube_ready lequalsonarqube
wait_cnes_sonarqube_ready()
{
    container_name="$1"
    while ! docker container logs "$container_name" 2>&1 | grep -q '\[INFO\] CNES SonarQube: ready!';
    do
        log "$INFO" "Waiting for CNES SonarQube to be ready."
        sleep 5
    done
}

# test_language
#
# This function tests that the image can analyze
# a project.
#
# Parameters:
#   1: language name to display
#   2: language key for SonarQube
#   3: folder name, relative to the tests/ folder
#   4: array of lines of sensors to look for in the scanner output
#   5: project key (sonar.projectKey of sonar-project.properties)
#   6: number of issues with the Sonar way Quality Profile
#   7: (optional) name of the CNES Quality Profile to apply, if any
#   8: (optional) number of issues with the CNES Quality Profile, if specified
#
# Environment variables used:
#   * SONARQUBE_URL
#   * SONARQUBE_LOCAL_URL
#   * SONARQUBE_NETWORK
#   * SONARQUBE_ADMIN_PASSWORD
#
# Example:
#   sensors=(
#       "INFO: Sensor CheckstyleSensor \[checkstyle\]"
#       "INFO: Sensor FindBugs Sensor \[findbugs\]"
#       "INFO: Sensor PmdSensor \[pmd\]"
#       "INFO: Sensor CoberturaSensor \[cobertura\]"
#   )
#   test_language "Java" "java" "java" sensors "java-dummy-project" 3 "CNES_JAVA_A" 6
test_language()
{
    # Args
    languageName=$1
    languageKey=$2
    folder=$3
    local -n sensorsInfo=$4
    projectKey=$5
    nbIssues=$6
    cnesQp=$7
    nbIssuesCnesQp=$8
    
    # Run analysis
    output=$(docker run --rm -u "$(id -u):$(id -g)" \
                -e SONAR_HOST_URL="$SONARQUBE_URL" \
                --net "$SONARQUBE_NETWORK" \
                -v "${PWD%tests}:/usr/src" \
                -v "${PWD%tests}/.sonarcache:/opt/sonar-scanner/.sonar/cache" \
                lequal/sonar-scanner \
                    "-Dsonar.projectBaseDir=/usr/src/tests/$folder" \
                    2>&1)
    echo -e "$output"

    # Make sure all non-default for this language plugins were executed by the scanner
    for line in "${sensorsInfo[@]}"
    do
        if ! echo -e "$output" | grep -q "$line";
        then
            [[ $line =~ .*\[(.*)\\\] ]]
            log "$ERROR" "Failed: the scanner did not use ${BASH_REMATCH[1]}."
            log "$ERROR" "docker run --rm -u $(id -u):$(id -g) -e SONAR_HOST_URL=$SONARQUBE_URL --net $SONARQUBE_NETWORK -v ${PWD%tests}:/usr/src -v ${PWD%tests}/.sonarcache:/opt/sonar-scanner/.sonar/cache lequal/sonar-scanner -Dsonar.projectBaseDir=/usr/src/tests/$folder"
            >&2 echo -e "$output"
            return 1
        fi
    done

    # Wait for SonarQube to process the results
    sleep 5

    # Check that the project was added to the server
    output=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                    "$SONARQUBE_LOCAL_URL/api/projects/search?projects=$projectKey")
    key=$(echo -e "$output" | jq -r '(.components[0].key)')
    if [ "$key" != "$projectKey" ]
    then
        log "$ERROR" "Failed: the project is not on the server."
        log "$ERROR" "curl -su admin:$SONARQUBE_ADMIN_PASSWORD $SONARQUBE_LOCAL_URL/api/projects/search?projects=$projectKey"
        echo -e "$output" | >&2 jq
        return 1
    fi

    # Get the number of issues of the project
    output=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                    "$SONARQUBE_LOCAL_URL/api/issues/search?componentKeys=$projectKey")
    issues=$(echo -e "$output" | jq '.issues | map(select(.status == "OPEN" or .status == "TO_REVIEW")) | length')
    if [ "$issues" -ne "$nbIssues" ]
    then
        log "$ERROR" "Failed: there should be $nbIssues issues on the $languageName dummy project with the Sonar way QP but $issues were found"
        log "$ERROR" "curl -su admin:$SONARQUBE_ADMIN_PASSWORD $SONARQUBE_LOCAL_URL/api/issues/search?componentKeys=$projectKey"
        echo -e "$output" | >&2 jq
        return 1
    fi

    log "$INFO" "Analysis with Sonar way QP ran as expected."

    # If the language does not have any CNES QP, the test ends
    if [ -z "$cnesQp" ]
    then
        log "$INFO" "Analyses succeeded, $languageName is supported."
        return 0
    fi

    # Switch to a CNES QP
    curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
        --data-urlencode "language=$languageKey" \
        --data-urlencode "project=$projectKey" \
        --data-urlencode "qualityProfile=$cnesQp" \
        "$SONARQUBE_LOCAL_URL/api/qualityprofiles/add_project"

    # Rerun the analysis
    docker run --rm -u "$(id -u):$(id -g)" \
            -e SONAR_HOST_URL="$SONARQUBE_URL" \
            --net "$SONARQUBE_NETWORK" \
            -v "${PWD%tests}:/usr/src" \
            -v "${PWD%tests}/.sonarcache:/opt/sonar-scanner/.sonar/cache" \
            lequal/sonar-scanner \
                "-Dsonar.projectBaseDir=/usr/src/tests/$folder" \
                2>&1

    # Wait for SonarQube to process the results
    sleep 5

    # Switch back to the Sonar way QP (in case the test needs to be rerun)
    curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
        --data-urlencode "language=$languageKey" \
        --data-urlencode "project=$projectKey" \
        --data-urlencode "qualityProfile=Sonar way" \
        "$SONARQUBE_LOCAL_URL/api/qualityprofiles/add_project"

    # Get the new number of issues
    output=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                    "$SONARQUBE_LOCAL_URL/api/issues/search?componentKeys=$projectKey")
    issues=$(echo -e "$output" | jq '.issues | map(select(.status == "OPEN"  or .status == "TO_REVIEW")) | length')
    if [ "$issues" -ne "$nbIssuesCnesQp" ]
    then
        log "$ERROR" "Failed: there should be $nbIssuesCnesQp issues on the $languageName dummy project with the $cnesQp QP but $issues were found"
        log "$ERROR" "curl -su admin:$SONARQUBE_ADMIN_PASSWORD $SONARQUBE_LOCAL_URL/api/issues/search?componentKeys=$projectKey"
        echo -e "$output" | >&2 jq
        return 1
    fi

    log "$INFO" "Analysis with $cnesQp QP ran as expected."
    log "$INFO" "Analyses succeeded, $languageName is supported."
    return 0
}

# test_analysis_tool
#
# This function tests that the image can run a
# specified code analyzer and that it keeps producing
# the same result given the same source code.
#
# Parameters:
#   1: tool name
#   2: tool command line
#   3: analysis results reference file
#   4: temporary results file
#
# Example:
#   $ cmd="pylint -f json --rcfile=/opt/python/pylintrc_RNC_sonar_2017_A_B tests//src/*.py"
#   $ test_analysis_tool "pylint" "$cmd" "tests/python/reference-pylint-results.json" "tests/python/tmp-pylint-results.json"
test_analysis_tool()
{
    # Args
    tool=$1
    cmd=$2
    ref_file=$3
    tmp_file=$4

    # Run an analysis with the tool
    docker run --rm -u "$(id -u):$(id -g)" \
                -v "$(pwd):/usr/src" \
                lequal/sonar-scanner \
                $cmd \
                    > "$tmp_file"

    # Compare result of the analysis with the reference
    if ! diff "$tmp_file" "$ref_file";
    then
        log "$ERROR" "Failed: $tool reports are different."
        log "$ERROR" "=== Result ==="
        >&2 cat "$tmp_file"
        log "$ERROR" "=== Reference ==="
        >&2 cat "$ref_file"
        return 1
    fi

    log "$INFO" "Analysis succeeded, $tool works as expected."
    return 0
}
