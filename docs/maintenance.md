# Maintaining ProtonPlus

Use the [codebase guide](codebase-guide.md) to find a change's owner and the
[test map](testing.md#test-map) to select checks.

## Everyday workflow

| Task | Command |
| --- | --- |
| See available commands | `make help` |
| Build and run the checkout | `make run` |
| Check one area | `./tests/check.sh /release-catalog` |
| Run the full suite and check the diff | `./tests/check.sh` |
| Lint Vala source and tests | `make lint` |
| Check release metadata | `./packaging/set-version.sh --check` |

Native builds, tests, and translations use `build/` and honor `BUILD_DIR`.
If you move a checkout and Meson still references the old path, use
`meson setup build --wipe .` to regenerate that build directory. Meson normally
regenerates changed build definitions during compilation.

Use `make translations` to refresh the source list and template after changing
translatable strings or adding or removing Vala sources. Use
`make translations-update` when you intend to merge the language catalogs.

## Debug a report

Collect the version, package format, launcher type, provider, variant, exact
action, and error. **Preferences → Advanced → System Information** provides
copyable environment details. For a crash before Preferences opens, capture
terminal output or use `make debug` for a native backtrace.

| Symptom | Start here | Focused test paths |
| --- | --- | --- |
| Launcher missing | `Launcher.get_all()` and `src/models/launchers/` | Launcher-specific tests |
| Release missing or wrong asset | Definition, release source, `ReleaseCatalog` | `/providers`, `/provider-definitions`, `/release-catalog` |
| Installed tool missing or wrong variant | Inventory, metadata, `ProviderTool.get_directory_name()` | `/installed-tool-inventory`, `/identity`, `/install-layout` |
| Install or update fails | `InstallationService` and selected workflow | `/installer-transaction`, `/update-transaction` |
| Download keeps failing | `Utils.Web` and partial download cache | `./tests/check.sh downloads` |
| Steam edit or restart stays pending | Configuration service, restart manager, session evidence | `/steam-configuration`, `/steam-restart-manager`, `/steam-session` |
| Launch command changes unexpectedly | Parser, edit state, writer | `/launch-command-parser`, `/launch-command-writer` |
| Controller focus or dialog problem | `ControllerManager`, policy, widget lifecycle | `./tests/check.sh controller` and hardware validation |

See the [fixture rules](testing.md#safety-rules-for-tests) for launcher, Steam,
and filesystem tests. Record any GUI or live behavior that needs separate
validation. [Manual checks](testing.md#manual-validation)

## CI and packaging

| CI trigger | Flatpak | Native packages and AppImage |
| --- | --- | --- |
| Pull request to `main` | x86_64 and aarch64 | x86_64 |
| Push to `main` | x86_64 and aarch64 | x86_64 and aarch64 |
| Manual CI with `flatpak` scope | x86_64 and aarch64 | — |
| Manual CI with `full` scope | x86_64 and aarch64 | x86_64 and aarch64 |

The [CI workflow](../.github/workflows/ci.yml) builds the local Flatpak, runs
its tests, and reports advisory lint for both manifests and the exported repo.

`make package TARGET=debian13` builds a native package into `dist/`. Other
native targets are `ubuntu26.04`, `fedora45`, and `archlinux`. The package
builder uses Docker or Podman. Set `PROTONPLUS_CONTAINER_ENGINE=podman` to
select Podman explicitly.

Build an AppImage with `make package TARGET=appimage` in the prepared
Arch-based environment. The [dependency script](../packaging/appimage/get-dependencies.sh)
prepares that environment. If optional smaller packages are unavailable, the
build uses stock Arch packages and may produce a larger AppImage.

## Prepare a release

1. Inspect the working tree. Run `./tests/check.sh`, exercise the relevant
   [manual checks](testing.md#manual-validation), and review CI for both
   architectures. Test the local Flatpak when packaging inputs changed.
2. Preview and set the intended version in Meson and the release Flatpak
   manifest. Replace the example version with the intended release.

   ```bash
   version=0.6.10
   ./packaging/set-version.sh "$version" --dry-run
   ./packaging/set-version.sh "$version"
   ```

3. Add a version, ISO date, and notes to the top of the AppStream release
   list. Keep the six newest entries there and move the oldest entry's
   version, date, and notes to the top of the archive. [AppStream metadata](../data/com.vysp3r.ProtonPlus.metainfo.xml.in) · [Release archive](changelog.md)
4. Run `./packaging/set-version.sh --check` and review the release diff. The
   read-only check uses Meson's version by default and requires `xmllint` from
   the libxml2 tools package.
5. Commit the release changes and push the matching `vVERSION` tag. Review
   [Release tag validation](../.github/workflows/release-tag.yml), which checks
   the tag against Meson, AppStream, and the tagged Flatpak source.
6. Publish the GitHub release for that tag. [Release](../.github/workflows/release.yml)
   builds and verifies the source archive, native packages, and AppImages,
   then attaches them with `SHA256SUMS`. A manual Release run builds artifacts
   for the selected branch or tag.

The tagged Flatpak manifest needs the published source tag. Use the local
manifest for a checkout before that tag is available.

### Package verification

- The native packages cover Debian 13, Ubuntu 26.04 LTS, Fedora 45, and Arch
  Linux on x86_64 and aarch64. Builds run the Meson suite with Xvfb and D-Bus.
- A fresh container installs each package and checks runtime dependencies,
  version, desktop metadata, icons, and GSettings schema discovery.
- AppImage jobs check update metadata and run `protonplus version` in a clean
  container.
- Downstream recipes can use `ProtonPlus-VERSION-source.tar.gz` from the
  release and its digest from `SHA256SUMS`. The archive extracts into
  `ProtonPlus-VERSION/`. The Arch recipe accepts `PROTONPLUS_VERSION` and
  `PROTONPLUS_SOURCE_SHA256` when run with `makepkg`.

## Maintenance audit and priorities

### Build and validation

- The Makefile and `tests/check.sh` share a build directory. `make run` uses
  the checkout's local resources and catalog data.
- `packaging/set-version.sh --check` validates release metadata with fixture
  coverage. CI validates the version tag before release packaging.
- `tests/gui/meson.build` owns the shared GTK test registration and per-test
  environment. The Tools fixture checks content allocation with a controlled
  viewport instead of relying on the compositor's window sizing.
- Issue and pull request templates ask for the affected launcher, release,
  and validation evidence.

### Runtime ownership

- `ProviderTool.get_directory_name()` owns variant naming for install jobs and
  inventory. `ToolVariantPreferences` owns saved selections and legacy aliases.
- `Games.Box` in `games-page.vala` owns navigation. `GameCollection` and
  `GameListView` own list state and presentation. `ReleaseRow` uses one action
  registration helper with stable action IDs.
- Simple launch options share catalog metadata and stable IDs. The external
  MangoHud wrapper and switches remain supported, with configuration managed
  by MangoHud itself.
- `InstalledComponents` queries the host's Flatpak IDs once per startup.
  `SteamLifecycle` shares Steam service creation between the GUI and CLI.

## Feature costs and scope choices

- Reuse definition, source, and standard archive workflows for ordinary
  providers. Add hosting adapters for distinct API semantics.
- Keep Steam configuration, restart evidence, and process lifecycles with
  their existing owners. Preserve raw launch options through the writer,
  including wrappers and unknown tokens.
- Validate controller changes on representative hardware alongside GTK tests.
  Prioritize focus, cleanup, and handoff regressions.
- Keep SteamTinkerLaunch and TinkerGame support limits and migration rules
  explicit. Add a fixture and packaging check when expanding launcher support.
- Share CLI and GUI mutation services. Use the Flatpak and native CI jobs to
  verify packaging changes across architectures.
