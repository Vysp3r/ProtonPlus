# Provider architecture

This document describes the extension seams for ordinary compatibility-tool providers. It is intentionally narrow: a provider is configuration plus a release source, while installation behaviour is selected from the job's requirements. It is not a framework for provider subclasses.

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

| Component | Responsibility |
| --- | --- |
| `ProviderDefinition` | Immutable-style configuration for one ordinary provider: stable ID, category, source type, endpoint, sort metadata, title filtering, variants, installation-layout rules, and a closed archive-install requirement where needed. It has no request, JSON, filesystem, or widget behaviour. Its collection accessors return copies. |
| Built-in definition files | `src/models/providers/definitions/{dxvk,vkd3d,proton,wine}.vala` declare the supported providers by category. `BuiltInProviderDefinitions` combines them. |
| `ProviderRegistry` | Indexes the built-in definitions by ID and category and validates static configuration. Validation includes unique provider IDs, valid variants with one default, non-empty unique layout families with a default layout, and source-specific URL-template requirements. It does not construct sources or choose installation behaviour. |
| `ProviderCatalog` | The composition boundary for an ordinary provider. It resolves the group's `InstallLayout`, obtains a source from `ReleaseSourceRegistry`, and creates a `ProviderTool` only when both exist. Unsupported source types therefore cannot create a partially usable tool. |
| `ProviderTool` | A normal `Tool` assembled from a definition, group layout, and source. It owns the provider identity, per-tool variant instances, and directory naming; its `ReleaseCatalog` owns remote browsing state. |
| `ReleaseSource` | Stateless host adapter contract. An adapter fetches one requested page and normalizes it into a `ReleasePageResult`; it does not cache releases or know about a launcher installation. |
| `ReleaseSourceRegistry` | The closed construction point from `SourceType` to the corresponding stateless source. A missing mapping returns `null`; registry validation catches that as invalid provider configuration. |
| Shared parsing helpers | `ReleaseSourceSupport` contains only common response support. `GitHubCompatibleReleaseParser` is shared by GitHub and Forgejo because their release and asset semantics match; `CatalogReleaseBuilder` applies definition filtering, variant selection, and asset matching. Helpers must not be extracted for JSON syntax alone. |
| `ReleaseCatalog` | Owns one tool's remote page state, pagination, cache snapshot, refresh, and latest-release lookup. It asks its injected `ReleaseSource` for pages; it never installs a release. |
| `Release` and `Asset` | Canonical provider-neutral remote metadata. `Asset` is the authoritative immutable value for archive name, URL, and size. `Release` carries upstream identity, source tag, variants, and source-specific metadata, but no installation target or progress state. |
| `InstallJob` | A target-bound installation lifecycle: selected release asset or variant, destination, progress, cancellation, operation state, and the composed archive-install requirement. It turns reusable catalog data into one requested operation. |
| `InstallationService` | Application-level coordinator for install, update, removal, download registration, cache-operation lifetime, and finalization. It has the one workflow-selection point. |
| `InstallationWorkflow` | A filesystem and lifecycle transaction implementation selected for a job. It does not browse or parse a remote release API. `StandardArchiveWorkflow` serves all ordinary provider tools; `SteamTinkerLaunchWorkflow` owns SteamTinkerLaunch's materially different transaction. |
| `InstallLayout` | A small closed value object that renders a directory name for a launcher family. Definitions provide an exact layout where needed and a required `default` fallback; layouts are not encoded strings to be parsed later. |
| `InstalledToolInventory` | Per-group snapshot of installed directories, metadata, compatibility-tool VDF identity, and usage. It resolves installed state for tools after invalidation or refresh rather than making individual tools repeatedly scan the filesystem. |

`Group` exposes the inventory refresh/invalidation boundary. After a service operation, the service invalidates the affected group's inventory; callers refresh it when they need a current installed-tool snapshot.

GTK and Libadwaita widgets consume tool, catalog, job, and inventory state. They do not define provider configuration, select a remote source, parse a release response, or choose an installation workflow. Likewise, release sources do not depend on GTK or Libadwaita, catalog code does not perform installation transactions, and workflows do not parse ordinary release APIs.

`CompatibilityTool` is discovery data for a launcher and is separate from provider-backed `Tool` instances. SteamTinkerLaunch is intentionally a dedicated tool because its lifecycle is not an ordinary archive installation.

## Adding an ordinary provider

Use this path when the upstream uses an existing source type and its release can be installed with the standard archive transaction.

1. Add one `ProviderDefinition` to the matching file in `src/models/providers/definitions/`: `dxvk.vala`, `vkd3d.vala`, `proton.vala`, or `wine.vala`.
2. Give it a stable provider ID, normal metadata, an existing `SourceType`, endpoint, filtering rules if required, valid variant definitions, and layouts for the launcher families whose naming differs. Set the closed archive-install requirement only when the downloaded archive has a non-standard shape such as a nested archive. Always include a `default` layout.
3. Update the definition snapshot and focused tests in `tests/fixtures/definitions/runners.json`, `tests/provider_definition_test.vala`, `tests/provider_registry_test.vala`, and `tests/install_layout_test.vala` when the provider's observable definition or install naming needs coverage.

No provider subclass, new release model, widget branch, installation-service branch, or workflow is needed. `ProviderCatalog` combines the definition with the existing source and `StandardArchiveWorkflow` handles the resulting archive job. The `definition-only-provider-creates-standard-tool` test demonstrates this seam with a test-only definition.

## Adding a release-hosting API

Add a source only when the host has different transport, pagination, failure, response, or asset-selection semantics that an existing source cannot faithfully represent.

1. Add a `SourceType` and its stable source ID mapping in `src/models/providers/provider-definition.vala` when the API is a new source type.
2. Add one stateless `ReleaseSource` implementation under `src/providers/sources/` and list it in `src/providers/sources/meson.build`.
3. Register its construction in `src/providers/sources/release-source-registry.vala`.
4. Normalize every usable response into canonical `Release` and `Asset` values. A canonical asset must have both its name and download URL, and releases must retain upstream identity where the API supplies it.
5. Add the new source's parser, pagination, malformed-response, transport-failure, filtering, identity, and asset-selection coverage to `tests/provider_source_test.vala`, `tests/release_identity_test.vala`, and fixture files below `tests/fixtures/providers/`. Add registry coverage if the new type changes the source matrix.

Extract shared parsing only after two sources have the same semantics. GitHub and Forgejo share their compatible release parser but retain distinct primary-asset policies; GitLab and GitHub Actions remain separate because their response and selection behaviour differs.

## Adding a specialized installation workflow

Create a workflow only when the installation transaction or lifecycle differs materially from extracting an archive into the normal target directory. Provider identity is not a workflow-selection mechanism.

1. Add the workflow and any focused composed context under `src/services/`, and list new source files in `src/services/meson.build`.
2. Make the context or another explicit job capability available from `InstallJob`; do not add nullable provider-specific fields to generic jobs.
3. Add the explicit selection rule in `InstallationService`, which remains the sole coordinator for operation registration and completion.
4. Add transaction, state, update, and removal coverage in the relevant `tests/installer-transaction-test.vala`, `tests/update-transaction-test.vala`, and specialized workflow test file. Add a dedicated fixture where it makes a transaction observable.

SteamTinkerLaunch is the current example: `SteamTinkerLaunchContext` selects its specialized workflow. Its provider identity and widgets do not select it. Do not generalize that workflow unless another workflow has genuinely identical transaction and lifecycle requirements.

## Architecture fitness checks

The focused test suite protects the extension points rather than implementation formatting:

- `tests/provider_registry_test.vala` verifies all built-ins validate, IDs and variants remain valid, layouts are structurally valid, all configured sources are constructible, a definition-only provider instantiates normally, and unsupported source types produce no tool.
- `tests/provider_definition_test.vala` and `tests/install_layout_test.vala` preserve built-in definition metadata, filtering, launcher-specific naming, and layout fallback behaviour.
- `tests/provider_source_test.vala` and `tests/release_identity_test.vala` verify canonical assets, source identities, pagination, malformed data, filtering, and the intentionally distinct GitHub/Forgejo primary-asset policies.
- Installation, inventory, CLI, and SteamTinkerLaunch tests preserve the remaining boundaries: installation transactions, installed-state refresh, command behaviour, and the specialized lifecycle.

These are behavioural checks. Do not replace them with source-text searches or tests that depend on code formatting.
