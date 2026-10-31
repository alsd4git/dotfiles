# Security policy

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/alsd4git/dotfiles/security/advisories/new).
Do not disclose exploit details or sensitive data in public issues or pull requests.

Include the affected commit, operating system, shell, expected impact and minimal
reproduction steps. Use synthetic examples and redact screenshots and logs.
If your own credential was exposed, revoke or rotate it. Report credentials you
do not control promptly and privately; do not use or attempt to revoke them.

## Versions and maintenance

Check the current default branch, `main`, before reporting an issue. Fixes, when
provided, target that branch; older revisions do not receive separate backports.
Reports are handled on a best-effort basis without guaranteed response or
remediation times.

## Safe reproduction

Use disposable home directories or containers and the repository's test harnesses.
Do not run installers, uninstallers, package bootstraps or macOS defaults changes
against a real user account merely to demonstrate an issue. Never include SSH
private keys, tokens, credential stores, private hostnames or unredacted shell
history in a report. Issues in third-party software should also be reported to
the relevant upstream maintainer.
