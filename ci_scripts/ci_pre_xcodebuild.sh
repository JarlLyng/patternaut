#!/bin/sh

# Xcode Cloud runs this before building. Set a unique, incrementing build number
# from the Cloud build number so every TestFlight upload is accepted.
# Runs only in Xcode Cloud (CI_BUILD_NUMBER is set there); a no-op locally.

set -e

if [ -n "$CI_BUILD_NUMBER" ] && [ -n "$CI_PRIMARY_REPOSITORY_PATH" ]; then
    echo "Setting build number to $CI_BUILD_NUMBER"
    cd "$CI_PRIMARY_REPOSITORY_PATH/App"
    agvtool new-version -all "$CI_BUILD_NUMBER"
else
    echo "Not in Xcode Cloud (CI_BUILD_NUMBER unset) — leaving build number unchanged."
fi
