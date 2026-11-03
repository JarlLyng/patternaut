# Contributing to Patternaut

Thanks for your interest. Patternaut is a small, focused app: native macOS, pay-once (no
subscription), private (offline, no accounts, no tracking) and minimal. Contributions that fit
that shape are welcome.

## Ways to help
- **Bugs and feature ideas:** open an issue using the templates. "Not right now" is a normal
  answer for a feature; it is not a judgement of the idea.
- **Ideas for the site or the store page:** there is a template for those too.

## Development
- Engine and tests: `cd PatternautCore && swift test`.
- App: `cd App && xcodegen generate`, then open `Patternaut.xcodeproj`. The app project is
  generated from `App/project.yml`; edit the yml, not the generated project, and regenerate.
- Keep changes covered by tests where the logic is testable (the core is pure and well tested).

## Ground rules
- No new tracking, accounts, subscriptions, or off-device data.
- Prefer clarity and small, focused changes.

By contributing you agree your contributions are licensed under the [MIT License](LICENSE).
