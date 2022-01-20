#!/usr/bin/env bash
export OSCHII_NAME=$1
irb -W0 -r ./cloud/lights.rb
