#! /bin/bash

BASEDIR=$(dirname "$0")

cd "$BASEDIR"

clear

ruby game.rb --ignore-gpu-issue
echo ""
exit