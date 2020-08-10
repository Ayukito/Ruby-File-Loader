#! /bin/bash

BASEDIR=$(dirname "$0")

cd "$BASEDIR"

clear
cd Project
/usr/local/opt/ruby/bin/ruby Game.rb --ignore-gpu-issue
echo ""
exit
