#!/usr/bin/env bash
set -euo pipefail

TARGET=$1

if [[ $TARGET != https://* ]]
   then TARGET="https://$TARGET"
fi

chromium --app=$TARGET
