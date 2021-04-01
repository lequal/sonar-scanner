#!/bin/bash

#run fake display
Xvfb :0 &
#run sonarscanner entry file
/usr/bin/entrypoint.sh "$@" 