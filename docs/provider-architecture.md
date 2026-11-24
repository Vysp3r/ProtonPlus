# Provider architecture

An ordinary provider combines a definition with a release source.
`InstallationService` selects the workflow from the job's requirements.

## Responsibilities and data flow

```text
ProviderDefinition
    -> ProviderRegistry
    -> ProviderCatalog / ProviderTool
    -> ReleaseSource
    -> ReleaseCatalog
    -> Release and Asset
    -> InstallJob
    -> InstallationService
    -> InstallationWorkflow
    -> InstalledToolInventory refresh
```

### Definitions and source selection

- `ProviderDefinition` snapshots the provider's identity, source, filters,
  variants, layouts, and install requirements. Its collection accessors return
  copies. The files in `src/models/providers/definitions/` are combined by
  `BuiltInProviderDefinitions`.
- `ProviderRegistry` validates unique IDs, legacy aliases, source URL
  templates, one default variant, and a `default` layout. It indexes definitions
  by ID and category.
- `ProviderCatalog` resolves the `InstallLayout` and asks
  `ReleaseSourceRegistry` to construct a source for the `SourceType`. Both
  must exist before it creates a `ProviderTool`, which owns tool identity,
  variants, and directory naming.

### Release browsing

- Each stateless `ReleaseSource` fetches one page into a `ReleasePageResult`.
  `ReleaseCatalog` owns pagination, cached snapshots, refresh, and latest lookup.
- `GitHubCompatibleReleaseParser` serves GitHub and Forgejo.
  `CatalogReleaseBuilder` applies provider filters, variant selection, and
  asset matching. Share helpers when source semantics match.
- `Release` carries upstream identity, tag, and variants. Each matched
  `Asset` supplies the canonical archive name, URL, size, and upstream digest.

### Installation and inventory

- `InstallJob` binds the asset or variant to a destination and carries
  progress, cancellation, and the archive-install requirement.
- `InstallationService` owns workflow selection and the operation lifecycle.
  `StandardArchiveWorkflow` handles ordinary archives.
  `SteamTinkerLaunchWorkflow` handles the specialized legacy transaction.
- `InstalledToolInventory` owns the group's snapshot of installed directory,
  metadata, VDF identity, and usage. `Group` exposes invalidation and refresh.

`Group` exposes the inventory refresh/invalidation boundary. After a service operation, the service invalidates the affected group's inventory; callers refresh it when they need a current installed-tool snapshot.

Latest installation slots are resolved through `InstalledToolInventory` by
persisted tool/target identity, installation mode, and variant. Jobs use the
resolved physical path even after a provider title changes. Older receipts use
their recorded title or the definition's explicit `legacy_titles`; aliases do
not override conflicting stable IDs or ambiguous legacy metadata. Existing
Steam manifest keys survive updates so game assignments retain their identity.

GTK and Libadwaita widgets consume tool, catalog, job, and inventory state. They do not define provider configuration, select a remote source, parse a release response, or choose an installation workflow. Likewise, release sources do not depend on GTK or Libadwaita, catalog code does not perform installation transactions, and workflows do not parse ordinary release APIs.

`CompatibilityTool` is discovery data for a launcher and is separate from provider-backed `Tool` instances. SteamTinkerLaunch is intentionally a dedicated tool because its lifecycle is not an ordinary archive installation.

## Launcher and tool-target identities

`Launcher.family_id` and `Launcher.instance_id` identify the launcher selected in the UI and CLI. Provider-backed tools, their persisted metadata, install layouts, and installation operation IDs instead use `tool_target_family_id` and `tool_target_id`, which identify the physical compatibility-tool storage target. The target IDs default to the launcher IDs, preserving every existing launcher and tool identity.

Faugus Launcher and Proton-Autogen share the native Steam target.
`faugus-system`, `faugus-flatpak`, and `proton-autogen-system` have their own
launcher identities and use `steam-system` with the `steam` layout family. This
lets their Tools views resolve the same installed metadata as native Steam.
Launcher models declare this mapping explicitly. See the [Proton-Autogen
integration](integrations/proton-autogen.md) for its profile and storage rules.

## Adding an ordinary provider

Reuse an existing source type and the standard archive transaction.

1. Add a definition in `src/models/providers/definitions/` under the relevant
   category (`dxvk.vala`, `vkd3d.vala`, `proton.vala`, or `wine.vala`).
2. Set a stable ID, source type, endpoint, canonical repository URL, variants,
   and any filters. Supply a `default` layout and explicit layouts for launcher
   families that use different directory names. Mark translated literals with
   `N_()`.
3. Update `tests/fixtures/definitions/runners.json` and the definition,
   registry, or layout tests when the provider changes their fixtures.

The `definition-only-provider-creates-standard-tool` test shows how the catalog
assembles a tool from a definition alone.

### Asset names and legacy metadata

- Keep the old endpoint as a legacy alias when changing it. Keep the old title
  in `legacy_titles` when renaming a provider. Preserve the provider ID.
- Match the intended archive by exact name. Use `$release_version` when the
  archive omits one leading `v` from the release name. Canonical formats take
  priority over older exact templates in `alternate_formats`.
- Use `single_archive_releases` only when each release exposes one usable
  archive. This allows a fallback when the exact name is missing. Use a closed
  archive-install requirement for layouts such as a nested archive.

### Release variant sets

Providers whose packaging changes between releases can declare ordered
`release_variant_sets`, each containing a complete `VariantDefinition` array
with one default. The first set with an exact named asset match describes the
release; otherwise the ordinary `variants` definitions and their alternate
formats remain the fallback. Missing archives retain entries without download
URLs. UI projections expose only available, CPU-compatible entries, and a
release with only a non-default archive remains browsable. Other providers
retain their required-default policy.

`ProviderTool.variants` retains the union of configured stable IDs. For these
providers, the GUI shows the selected build in each release row and offers a
Build submenu when that release has multiple usable archives. The interactive
CLI also asks for the build after selecting such a release. Cached releases
replay variant composition from their retained assets; former collapsed caches
refresh rather than inventing omitted assets.

DXVK-Sarek uses sets for unified, dyasync, and separate Async/Standard archives.
Its historical `standard` ID and default directory slot intentionally continue
to identify the previously selected Async archive on older releases. The newly
exposed non-async archive has ID `non-async` and a separate `-Standard` slot.
Labels vary with packaging while these identities remain stable. Automatic
updates preserve the stored variant ID and leave an installation intact if the
new release no longer provides that variant.

### Launcher and manifest constraints

Use `supported_launcher_ids` to restrict a provider to particular launcher
instances. Rosemary uses `managed_steam_manifest` because each upstream
archive declares the same Steam key. The standard workflow assigns a stable
Latest key and a distinct key per versioned release, and the inventory requires
matching provider, tool, and target metadata for ownership. Steam discovery
can still read manually installed copies through their upstream key.

Definitions use named configuration fields; optional settings can be omitted:

```vala
new ProviderDefinition (new ProviderConfig () {
    provider_id = "example-proton",
    category = Category.PROTON,
    source_type = SourceType.GITHUB,
    title = "Example Proton",
    description = N_ ("An example compatibility tool."),
    endpoint = "https://api.github.com/repos/example/proton/releases",
    repository_url = "https://github.com/example/proton",
    sort_priority = 20,
    variants = { new VariantDefinition ("standard", "default", "$release_name", true) },
    install_layouts = { InstallLayout.template ("default", "$release_name") },
    single_archive_releases = true
})
```

`ProviderConfig` is editable construction input. `ProviderDefinition` copies it,
including collections, before sharing it with tools. Registry validation still
checks required fields and compatibility rules. Existing persisted IDs and
legacy aliases must survive configuration edits.

## Adding a release-hosting API

Add a source only when the host has different transport, pagination, failure, response, or asset-selection semantics that an existing source cannot faithfully represent.

1. Add a `SourceType` and its stable source ID mapping in `src/models/providers/provider-definition.vala` when the API is a new source type.
2. Add one stateless `ReleaseSource` implementation under `src/providers/sources/` and list it in `src/providers/sources/meson.build`.
3. Register its construction in `src/providers/sources/release-source-registry.vala`.
4. Normalize every usable response into canonical `Release` and `Asset` values. A canonical asset must have both its name and download URL, and releases must retain upstream identity where the API supplies it.
5. Add the new source's parser, pagination, malformed-response, transport-failure, filtering, identity, and asset-selection coverage to `tests/provider-source-test.vala`, `tests/release-identity-test.vala`, and fixture files below `tests/fixtures/providers/`. Add registry coverage if the new type changes the source matrix.

Extract shared parsing only after two sources have the same semantics. GitHub and Forgejo share their compatible release parser but retain distinct primary-asset policies; GitLab and GitHub Actions remain separate because their response and selection behaviour differs.

## Adding a specialized installation workflow

Create a workflow only when the installation transaction or lifecycle differs materially from extracting an archive into the normal target directory. Provider identity is not a workflow-selection mechanism.

1. Add the workflow and any focused composed context under `src/services/installation/`, and list new source files in its `meson.build`.
2. Make the context or another explicit job capability available from `InstallJob`; do not add nullable provider-specific fields to generic jobs.
3. Add the explicit selection rule in `InstallationService`, which remains the sole coordinator for operation registration and completion.
4. Add transaction, state, update, and removal coverage in the relevant `tests/installer-transaction-test.vala`, `tests/update-transaction-test.vala`, and specialized workflow test file. Add a dedicated fixture where it makes a transaction observable.

SteamTinkerLaunch is the current example: `SteamTinkerLaunchContext` selects its specialized workflow. Its provider identity and widgets do not select it. Do not generalize that workflow unless another workflow has genuinely identical transaction and lifecycle requirements.

## Architecture fitness checks

The focused test suite protects the extension points rather than implementation formatting:

- `tests/provider-registry-test.vala` verifies all built-ins validate, IDs and variants remain valid, layouts are structurally valid, all configured sources are constructible, a definition-only provider instantiates normally, and unsupported source types produce no tool.
- `tests/provider-definition-test.vala` and `tests/install-layout-test.vala` preserve built-in definition metadata, filtering, launcher-specific naming, and layout fallback behaviour.
- `tests/provider-source-test.vala` and `tests/release-identity-test.vala` verify canonical assets, source identities, pagination, malformed data, filtering, and the intentionally distinct GitHub/Forgejo primary-asset policies.
- Installation, inventory, CLI, and SteamTinkerLaunch tests preserve the remaining boundaries: installation transactions, installed-state refresh, command behaviour, and the specialized lifecycle.

These are behavioural checks. Do not replace them with source-text searches or tests that depend on code formatting.

## TinkerGame successor integration

`InstallationService` selects `TinkerGameWorkflow` for jobs in `TINKER_GAME`
mode. The workflow specializes the archive workflow's staged preparation and
metadata hooks while sharing directory staging, promotion and backup
restoration. It stages the complete modular runtime and Steam manifests
together. SteamTinkerLaunch uses a separate external command and global
executable-link lifecycle.
See [TinkerGame](integrations/tinkergame.md) for automatic release discovery (including prereleases), ownership,
dependency policy, unsupported targets and explicit configuration migration.

`TinkerGameReleaseSource` is stateless and uses GitHub source archives, including
prereleases. Its `ReleaseCatalog` owns caching; update checks bypass the browse
cache. Ordinary GitHub providers retain their uploaded-asset and stable-release
policies.
