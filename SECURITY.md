# Security Policy

ProtonPlus is a Linux desktop application that discovers launcher data, reads and writes local configuration files, accesses selected launcher directories, and downloads compatibility tools from upstream release services. Please report issues that could affect the confidentiality, integrity, or availability of ProtonPlus or the data it handles.

## Reporting a Vulnerability

Please do not open a public issue, pull request, discussion, or chat message for a suspected security vulnerability.

Use one of these private channels:

1. If the repository shows **Report a vulnerability** on its Security tab, use [GitHub Private Vulnerability Reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately).
2. Otherwise, email [dev@vysp3r.com](mailto:dev@vysp3r.com) with `ProtonPlus security report` in the subject.

If you are unsure whether an issue is security-sensitive, report it privately. Do not include passwords, API tokens, private keys, personal data, or other secrets in a report. Redact usernames, home-directory paths, and logs where practical. If an attachment contains sensitive material, ask for a safer transfer method before sending it.

### What to Include

Include enough information to reproduce and assess the issue:

- the ProtonPlus version, obtained with `protonplus version` where available;
- the installation source and format, such as Flathub, a community package, a native build, or an AppImage;
- the Linux distribution and relevant launcher or Flatpak details;
- the affected feature, input, upstream provider, URL, release, or archive;
- clear reproduction steps and the expected and observed behavior;
- the security impact and likely attack prerequisites;
- a proof of concept or supporting logs, after removing secrets and personal data; and
- any suggested mitigation or fix, if known.

### Reporting Timeline

We aim to acknowledge a report within 7 calendar days. Triage, impact assessment, fixes, testing, and distribution timing depend on the issue and may take longer. If you have not received an acknowledgement after 7 days, please follow up using the same channel.

## Security Scope

In scope are vulnerabilities in ProtonPlus itself, including its native and Flatpak behavior, command-line interface, local file and archive handling, network requests, release and asset selection, installation and update workflows, and repository-controlled build or release configuration.

ProtonPlus integrates with third-party launchers, release services, runtimes, libraries, package repositories, and compatibility tools. A vulnerability in one of those systems is normally outside ProtonPlus's scope and should also be reported to its responsible maintainer. However, please report ProtonPlus behavior that causes an unsafe source to be selected, an untrusted archive to be handled unsafely, credentials to be exposed, or local data to be accessed improperly.

## Supported Versions

Only the latest published ProtonPlus release receives security fixes from this project.

| Version | Security support |
| --- | --- |
| Latest published release | Supported |
| Older published releases | Not supported |
| Development branches, snapshots, and unreleased builds | Not supported |

The version shown by a distribution package may lag behind the latest project release. Contact that package's maintainer for package-specific update timing. The project does not control the release timing or security policies of community packages, operating-system repositories, or upstream compatibility-tool projects.

## Coordinated Disclosure

Reports are handled privately while maintainers investigate and, where appropriate, prepare a fix. We will work with the reporter on a reasonable disclosure date, taking into account the availability of a fix, the risk of exploitation, and the time needed for users and distributors to update.

When appropriate, the project may publish a GitHub security advisory, release-note entry, or other public notice after remediation is available. A notice should identify the affected and fixed versions, impact, affected configurations, workarounds, and relevant identifiers such as a CVE when one is assigned. We will credit reporters when they request credit and it is safe to do so.

If details are already public or exploitation is occurring, we may coordinate an expedited disclosure to reduce user risk.

## Security Updates

Security fixes are delivered through a subsequent project release when a fix is available. Monitor the [GitHub releases](https://github.com/Vysp3r/ProtonPlus/releases), the [repository security page](https://github.com/Vysp3r/ProtonPlus/security), and announcements from the package source you use.

Users should keep ProtonPlus, their operating system, Flatpak runtimes, and distribution packages up to date. A fix in ProtonPlus does not fix vulnerabilities in a launcher, compatibility tool, runtime, library, or community package that ProtonPlus uses.

## Dependencies and Third-Party Software

ProtonPlus is built with GTK4, libadwaita, GLib, json-glib, libsoup, libgee, libarchive, libnotify, Cairo, AppStream, SDL, Vala, and other system or Flatpak SDK/runtime components. The versions and security support of those components are provided by the operating system, Flatpak runtime, or package maintainer.

The application retrieves release metadata from upstream GitHub, GitLab, Forgejo, and GitHub Actions sources and installs selected archives into launcher-specific directories. Reports about upstream services, provider releases, or compatibility-tool contents should be sent to those upstream projects as well as to ProtonPlus when ProtonPlus's handling contributes to the risk.

## Package Integrity and Known Limitations

- The recommended distribution is the official [Flathub package](https://flathub.org/apps/com.vysp3r.ProtonPlus) with application ID `com.vysp3r.ProtonPlus`.
- Native builds and AppImages can be built from this repository. Community distribution packages are maintained outside the ProtonPlus project and may differ from the official Flatpak.
- The checked-in provider definitions and API endpoints use HTTPS, but ProtonPlus does not currently enforce HTTPS for every dynamically supplied asset URL and does not provide general checksum or cryptographic signature verification for the compatibility-tool archives it downloads. Users should consider the upstream release service and provider project part of their trust decision.
- This repository's release workflow does not currently publish a ProtonPlus signing key, release checksums, or artifact provenance that users can independently verify. Do not treat an artifact as project-signed merely because it is linked from a release page.
- The Flatpak requests network access and broad host filesystem access so it can discover launcher installations and libraries. Install it only from a source you trust, and review the permissions reported by your Flatpak tooling.

## Safe Testing

Only test against systems, accounts, launchers, and files that you own or are authorized to use. Avoid actions that could modify another user's launcher data, consume upstream resources excessively, or expose credentials. Do not download or execute a proof of concept that you do not understand.

## Contact

For security reports, use [dev@vysp3r.com](mailto:dev@vysp3r.com) or GitHub Private Vulnerability Reporting as described above. For ordinary bugs and feature requests, use the [issue tracker](https://github.com/Vysp3r/ProtonPlus/issues).
