# Sentry: anonymous crash reports and one feature count

Patternaut sends crash reports, app hangs, crash-free sessions, MetricKit diagnostics and one
count, a project exported, to Sentry. All of it is anonymous. The code is
`App/Patternaut/Telemetry.swift`, and what may be sent is in
`PatternautCore/Sources/PatternautCore/Diagnostics/TelemetryRules.swift`, which is unit-tested.

The app's only network access (`com.apple.security.network.client`) is for this.

## What is sent, and what isn't

Anonymous is a recipe, not Sentry's default. Out of the box sentry-cocoa sends a random
installation ID as the user, as every session's `did` and on every metric, plus
`device_app_hash` (a hash of the vendor ID) on every event. `Telemetry.swift` stops all of it:

- **One shared user, `anonymous`:**
  - set right after `SentrySDK.start`, before any event or metric;
  - set again on every event in `beforeSend`, which also covers app hangs and MetricKit
    diagnostics.
- **No device IDs or host name:** `beforeSend` drops `contexts.app.device_app_hash`,
  `contexts.device.id` and `server_name`.
- **Nothing the user made:**
  - **No breadcrumbs at all.** On the Mac they can hold window titles, which name documents.
  - **Library paths:** the account name goes from the paths a crash report lists for the app
    and its libraries (`/Users/~/…`).
  - **Free text:** any path under a home folder or on a card in an exception message or
    event message becomes `<path>`.
  - The app never puts a pattern, a project name, an instrument name or a file path in an
    event, tag or metric.
- **Sessions without an ID:**
  - sentry-cocoa sets a session's `did` from the `INSTALLATION` file in its cache directory,
    and has no option to change it.
  - The app writes `anonymous` into that file before the SDK starts, so every install reports
    the same `did`.
  - This relies on SDK internals. That is why `App/project.yml` pins sentry-cocoa to an exact
    version, and why the envelope check below has to be repeated after every upgrade.
- **One count, `project.exported`:**
  - sent when a project has been written for the Tracker;
  - one attribute, `device` (`tracker_plus` or `tracker_mini`);
  - `beforeSendMetric` keeps only that and the SDK's coarse facts (SDK, release, environment,
    OS, device model), and drops the rest, `user.id` included.
- **Off:** `sendDefaultPii`, performance tracing, file I/O tracing, network breadcrumbs and
  failed-request capture. The Mac SDK takes no screenshots or view hierarchy, and session
  replay is not used.
- **Environment:**
  - `debug` for builds from Xcode.
  - In release builds, StoreKit's `AppTransaction` decides: `production` for App Store
    installs and `testflight` for TestFlight. A Mac TestFlight build looks like an App Store
    build from the inside, so a receipt can't tell them apart.
  - Until StoreKit answers, events say `release`. Sessions keep the environment they started
    with, so sessions from release builds say `release`.

The `iamjarl` Sentry organisation also strips `user.id`, `contexts.device.id` and
`contexts.app.device_app_hash` server-side and stores no IP addresses, as a safety net for
native crashes the app's code can't reach.

## The DSN

- **Where the app reads it:** first from the `SENTRY_DSN` environment variable (handy in an
  Xcode scheme), then from `SentryDSN` in Info.plist. Info.plist gets it from the
  `SENTRY_DSN` build setting in `App/Sentry.xcconfig`.
- **Locally:** copy `App/Sentry.xcconfig.example` to `App/Sentry.xcconfig`. The real file is
  gitignored, and `App/Config.xcconfig` includes it only if it exists. Without a DSN, the app
  sends nothing.
- **Write `//` as `/$()/`** in the xcconfig. There, `//` starts a comment, so a plain
  `https://…` leaves only `https:`. The app treats that as no DSN.
- **Xcode Cloud:** add `SENTRY_DSN` (secret) to the workflow's environment.
  `ci_scripts/ci_pre_xcodebuild.sh` writes `App/Sentry.xcconfig` from it before every build,
  escaped.
  - **An archive without a DSN that looks like one fails**, with an error that names the fix.
  - Builds and tests still run without it.
- **The value the build resolved is checked too.** The target's first build phase, "Check the
  Sentry DSN for archives", stops any archive whose resolved `SENTRY_DSN` isn't
  `http(s)://…@…/…`. That covers a hand-written xcconfig and local archives as well. Checked on
  2026-11-15 with `xcodebuild install`:
  - no xcconfig fails;
  - a plain `https://` fails, because it resolves to `https:`;
  - the escaped form passes and ends up in Info.plist as `https://…`.

## Readable crashes (dSYMs)

`ci_scripts/ci_post_xcodebuild.sh` uploads the archive's dSYMs with a pinned `sentry-cli`
whose checksum is verified.

- **Token:** it needs a second secret on the workflow, `SENTRY_AUTH_TOKEN`, an organisation
  token that can upload debug files.
- **Slugs:** `SENTRY_ORG` and `SENTRY_PROJECT` default to `iamjarl` and `patternaut`.
- **Without the token, or if the upload fails,** the build goes on with a warning. The release
  is fine; only its stack traces are unreadable.

## Checking the envelopes (after every sentry-cocoa upgrade)

Point a Debug build at a local stand-in for Sentry and read what it sends:

1. Run a small HTTP server on a free local port that saves each POST body. Gunzip it if it
   arrives with `Content-Encoding: gzip`. Check that no other session already holds the port.
2. Launch the built app with these two environment variables, for example through
   `open -n --env`:
   - `SENTRY_DSN=http://0123456789abcdef0123456789abcdef@127.0.0.1:<port>/1`
   - `PATTERNAUT_SENTRY_PROBE=1`

   The probe sends one event and two counts, and one of the counts carries an attribute that
   must not survive.
3. Bring the window to the front, so a session starts.
4. Quit or stop the app, then launch it once more, so the first session is closed and sent.

It passes when:
- every `session` item's `did` is `anonymous`;
- every `event` item's `user` is `{"id": "anonymous"}`, with no `device_app_hash`, no
  `contexts.device.id` and no `server_name`;
- the `trace_metric` items carry no `user.*` attribute and no `project`.

**First runs:**
- A shell can't read or write another app's sandbox, because of macOS's app-data protection.
  That rules out seeding the `INSTALLATION` file with a fake old ID.
- No version before the one that added Sentry ever wrote that file, so every update starts
  without one. A build with another bundle ID (`PRODUCT_BUNDLE_IDENTIFIER=…envtest`) gets an
  empty sandbox for checking that first run.

**Last checked** with sentry-cocoa 9.32.0 on 2026-11-15, and it passed. 16 envelopes came from
the existing sandbox and from a fresh one: 7 events, 6 sessions and 3 metric batches. Every
`did` and user was `anonymous`, there was no `device_app_hash`, `server_name` or `user.id`,
the probe's `project` attribute was dropped, and no path under `/Users/` appeared.
