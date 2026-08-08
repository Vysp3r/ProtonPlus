# Agent guide

Applies to the entire repository.

## Before editing

- Run `git status --short` and inspect relevant diffs. Preserve unrelated user
  changes.
- Read [`docs/codebase-guide.md`](docs/codebase-guide.md). For provider work,
  also read [`docs/provider-architecture.md`](docs/provider-architecture.md).
- Trace the full read/state/write/persistence path before changing behavior.
- Keep changes scoped. Add new Vala files to the nearest `meson.build`.

## Validation

```bash
meson setup build                 # only if build/ is not configured
meson compile -C build
meson test -C build --print-errorlogs
git diff --check
```

Run focused GLib paths from `tests/` so fixtures resolve correctly:

```bash
(cd tests && ../build/tests/protonplus-tests -l)
(cd tests && ../build/tests/protonplus-tests -p /launch-command-writer)
```

See [`docs/testing.md`](docs/testing.md) for the test map. Run
`make translations` only after adding, removing, or changing translatable UI
strings.

## Required contracts

- Ordinary providers are definitions under `src/models/providers/definitions/`.
  Reuse release sources and workflows; do not branch on provider IDs in widgets
  or `InstallationService`.
- `ReleaseCatalog` owns browse/cache state. Release sources are stateless.
  `InstallationService` owns workflow selection and operation lifecycle.
- `InstalledToolInventory` owns installed-state discovery. Invalidate after
  mutations and refresh at an explicit read boundary.
- Treat launcher/tool-target, provider, tool, variant, release, Steam target,
  metadata, CLI, and GSettings IDs as persisted contracts.
- Keep complete `ProviderTool.variants` and `Release.variants` collections.
  Filter UI projections and enforce compatibility through
  `VariantCompatibility`, `VariantSelector`, and `InstallationService`.
- Route production Steam VDF changes through `SteamConfigurationService`.
  Persist receipts through `SteamRestartManager`; reconcile only after
  `SteamSessionService` confirms Steam stopped. Keep native, Flatpak, Snap, and
  SteamOS behavior separate.
- Preserve raw launch-option spelling, order, quotes, duplicates, and unknown
  safe content. `LaunchCommandWriter` is the serializer for preview and Apply.
  Clear remains a full-source replacement; mass edit writes each source
  independently.
- Keep SDL/GTK controller integration in `ControllerManager` and semantic
  decisions in the controller policy helpers. Register dialogs and popovers
  through `Widgets.Window`, use `ControllerNavigationHost` for page flows, and
  preserve keyboard/pointer handoff and lifecycle cleanup.
- Do not follow symlinks while enumerating or copying extracted trees. Preserve
  links through staging and cover archive paths with fixtures.
- Keep blocking work out of GTK callbacks. After async yields, revalidate the
  selected object/operation. Disconnect long-lived handlers at their owner’s
  lifecycle boundary.
- Use gettext for user-visible strings and escape dynamic markup.
- Never test mutations against real Steam profiles or tool directories. Use
  fixtures and injected backends. Capture CLI output with
  `RecordingCliOutputSink`, not process-wide descriptor redirection.

## Handoff

Inspect `git status --short`, the exact scoped diff, and `git diff --check`.
Report tests run and clearly identify unverified GUI, packaging, hardware, or
live Steam behavior.
