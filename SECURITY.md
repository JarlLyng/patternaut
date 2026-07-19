# Security Policy

## Reporting a vulnerability

Please report security issues privately, not as a public issue.

Use GitHub's private vulnerability reporting on this repository (the **Security** tab →
**Report a vulnerability**). If you cannot use that, reach out via
[iamjarl.com](https://iamjarl.com).

Please include enough detail to reproduce the issue. You will get an acknowledgement, and a
fix or mitigation will be prioritized according to severity.

## Scope

Patternaut runs locally on macOS with no accounts, no network backend, and no data sent off
the device, so most classes of remote/server vulnerability do not apply. Relevant reports
would typically concern local file handling (parsing/writing `.mtp`/`.mt`/`.pti`/WAV files) or
the app's handling of untrusted input.
