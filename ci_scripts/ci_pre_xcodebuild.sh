#!/bin/sh

# Xcode Cloud runs this before every xcodebuild action.
#
# 1. Set a unique, incrementing build number from the Cloud build number so
#    every TestFlight upload is accepted.
# 2. Write App/Sentry.xcconfig (gitignored) from the SENTRY_DSN environment
#    variable, and stop an archive that has no usable DSN: it would ship with
#    crash reports off and say so nowhere. Builds and tests still run without it.
#
# Runs only in Xcode Cloud (CI_BUILD_NUMBER is set there); a no-op locally.

set -e

if [ -z "$CI_BUILD_NUMBER" ] || [ -z "$CI_PRIMARY_REPOSITORY_PATH" ]; then
    echo "Not in Xcode Cloud (CI_BUILD_NUMBER unset) — leaving build number and Sentry.xcconfig alone."
    exit 0
fi

echo "Setting build number to $CI_BUILD_NUMBER"
cd "$CI_PRIMARY_REPOSITORY_PATH/App"
agvtool new-version -all "$CI_BUILD_NUMBER"

# A DSN looks like https://<key>@<host>/<project id>.
if printf '%s' "$SENTRY_DSN" | grep -Eq '^https?://[^@/]+@[^/]+/[0-9]+$'; then
    # In an xcconfig "//" starts a comment, so write it as "/$()/".
    printf 'SENTRY_DSN = %s\n' "$(printf '%s' "$SENTRY_DSN" | sed 's#://#:/$()/#')" > Sentry.xcconfig
    echo "Wrote Sentry.xcconfig with a DSN"
else
    printf 'SENTRY_DSN =\n' > Sentry.xcconfig
    if [ "$CI_XCODEBUILD_ACTION" = "archive" ]; then
        echo "error: SENTRY_DSN is missing or not a DSN on this Xcode Cloud workflow, so this archive would ship without crash reports. Add it under Environment (secret), then build again. See App/SENTRY.md."
        exit 1
    fi
    echo "warning: no SENTRY_DSN, so this build sends nothing to Sentry."
fi
