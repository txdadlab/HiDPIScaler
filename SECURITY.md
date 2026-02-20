# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| Latest release | Yes |
| Older releases | No |

Only the latest release receives security fixes. Please update to the newest version.

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately rather than opening a public issue.

**Email:** [Open a private security advisory](https://github.com/txdadlab/HiDPIScaler/security/advisories/new)

Please include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact

You can expect an initial response within 7 days. If confirmed, a fix will be released as soon as possible.

## Scope

HiDPI Scaler uses private CoreGraphics APIs and runs with standard user privileges. Areas of particular concern include:

- Code execution via crafted API responses (e.g., the GitHub update check)
- Unexpected behavior from the Objective-C bridge to private frameworks
- Any path that could escalate privileges or persist beyond the app's lifecycle

## Disclosure

Once a fix is released, the vulnerability will be disclosed in the release notes with credit to the reporter (unless they prefer to remain anonymous).
