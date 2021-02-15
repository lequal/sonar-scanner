#!/usr/bin/env bash

# User story:
# As a user of this image, I want to run hadolint to lint my Dockerfile
# so that I can see if my Dockerfile respect best pratices

. tests/functions.bash

ref="tests/dockertext/reference-hadolint-results.xml"
output="tests/dockertext/tmp-hadolint-results.xml"
cmd="hadolint -f checkstyle tests/dockertext/Dockerfile > $output"
test_analysis_tool "hadolint" "$cmd" "$ref" "$output" "no"

exit $?
