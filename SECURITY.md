# Security policy

Report suspected vulnerabilities privately. For ordinary bugs and feature
requests, use the [issue tracker](https://github.com/Vysp3r/ProtonPlus/issues).

## Reporting a vulnerability

1. Use **Report a vulnerability** if the repository's Security tab offers it.
   [GitHub private reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately)
2. Otherwise, email [dev@vysp3r.com](mailto:dev@vysp3r.com) with
   `ProtonPlus security report` in the subject.

Use a private channel when in doubt. Redact secrets, personal data, home paths,
and identifying logs. Ask for a safer transfer method before sending a
sensitive attachment.

### What to include

- The ProtonPlus version (`protonplus version` for native builds) and
  installation source or package format.
- The distribution and relevant launcher or Flatpak details.
- The affected feature, input, provider, URL, release, or archive.
- Reproduction steps, expected and observed behavior, impact, and prerequisites.
- Redacted logs or a proof of concept, plus any known mitigation.

### Response timeline

We aim to acknowledge reports within seven calendar days. Follow up through
the same channel if you have received no acknowledgement by then. Triage,
fixes, testing, and distribution may take longer.

## Security scope

Report vulnerabilities in ProtonPlus, including its CLI, native and Flatpak
behavior, archive and file handling, networking, installation workflows,
release selection, and repository build and release workflows.

Report a vulnerability in an upstream launcher, library, or compatibility tool
to its maintainer. Include ProtonPlus when its handling contributes to the
issue, such as unsafe source selection, archive processing, credential
exposure, or improper local data access.

## Supported versions

The project provides security fixes for its latest published release. Check
with your package maintainer for distribution-specific update timing.

| Version | Security support |
| --- | --- |
| Latest published release | Supported |
| Older releases, development branches, and snapshots | Unsupported |

## Coordinated disclosure

- Maintainers review reports privately and coordinate a disclosure date with
  the reporter. Timing depends on the fix, exploitation risk, and time to update.
- A public notice may include affected and fixed versions, impact, workarounds,
  and a CVE if assigned. We credit reporters on request when it is safe.
- Details that are already public or under active exploitation may require
  faster disclosure.

## Security updates

Update ProtonPlus and the runtime or system packages it depends on. Security
fixes ship in project releases. Check [GitHub Releases](https://github.com/Vysp3r/ProtonPlus/releases),
[repository advisories](https://github.com/Vysp3r/ProtonPlus/security), and
notices from your package source.

## Package integrity and permissions

- **Flathub.** The recommended package uses the ID `com.vysp3r.ProtonPlus`.
  It requests network and host filesystem access to find launchers and game
  libraries. [Flathub listing](https://flathub.org/apps/com.vysp3r.ProtonPlus)
- **GitHub releases.** The release workflow generates `SHA256SUMS` for the
  source archive, native packages, AppImages, and update metadata. Use it to
  check that a download matches the published release. [Verification command](docs/installation.md#github-release-packages)
- **Compatibility tools.** The standard archive workflow checks the file size
  and upstream digest when supplied. Checked-in provider endpoints use HTTPS.
  Providers also supply asset URLs, so the upstream project and release
  service are part of the trust boundary.
- **Runtime dependencies.** The operating system, Flatpak runtime, and package
  maintainers determine library versions and their security support.

## Safe testing

Use systems, accounts, launchers, and data you own or have permission to test.
Protect credentials and other users' data. For reproduction in a development
checkout, use the [test fixture guidance](docs/testing.md#safety-rules-for-tests).
