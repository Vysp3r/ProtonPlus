test_sources = files(
    'main.vala',
    'controller-control-policy-test.vala',
    'controller-hint-policy-test.vala',
    'controller-haptics-test.vala',
    'controller-input-policy-test.vala',
    'controller-text-input-policy-test.vala',
    'controller-navigation-policy-test.vala',
    'controller-surface-policy-test.vala',
    'application-action-test.vala',
    'games-action-policy-test.vala',
    'release-row-presentation-test.vala',
    'inline-release-request-guard-test.vala',
    'games-collection-test.vala',
    'cpu-capabilities-test.vala',
    'variant-compatibility-test.vala',
    'variant-selector-test.vala',
    'asset-test.vala',
    'filesystem-test.vala',
    'web-test.vala',
    'system-path-test.vala',
    'systemd-timer-test.vala',
    'migration-v0.6.6-test.vala',
    'faugus-launcher-test.vala',
    'proton-autogen-test.vala',
    'metadata-test.vala',
    'compatibility-tool-test.vala',
    'steam-compatibility-tool-discovery-test.vala',
    'steam-library-diagnostics-test.vala',
    'installed-tool-inventory-test.vala',
    'parser-test.vala',
    'launch-command-test.vala',
    'launch-command-parser-test.vala',
    'launch-command-composer-test.vala',
    'launch-command-editor-projection-test.vala',
    'launch-command-writer-test.vala',
    'launch-option-capability-resolver-test.vala',
    'provider-definition-test.vala',
    'provider-registry-test.vala',
    'provider-source-test.vala',
    'identity-test.vala',
    'cli-test.vala',
    'release-identity-test.vala',
    'release-page-test.vala',
    'release-catalog-test.vala',
    'variant-settings-test.vala',
    'install-layout-test.vala',
    'compatibility-process-guard-test.vala',
    'installer-transaction-test.vala',
    'steam-test.vala',
    'steam-session-test.vala',
    'steam-game-launch-test.vala',
    'steam-configuration-service-test.vala',
    'steam-restart-manager-test.vala',
    'steam-restart-orchestrator-test.vala',
    'steam-restart-presentation-test.vala',
    'steamtinkerlaunch-test.vala',
    'tinkergame-test.vala',
    'update-transaction-test.vala',
    'vdf-binary-test.vala',
)

test_exe = executable(
    'protonplus-tests',
    test_sources,
    dependencies: deps + [resources_dep],
    link_with: protonplus_lib,
    include_directories: [config_inc, include_directories('../src')],
    vala_args: ['--target-glib=2.58'],
)

test(
    'ProtonPlus unit tests',
    test_exe,
    protocol: 'tap',
    # Network recovery fixtures exercise real socket timeouts and retry backoff.
    timeout: 120,
    workdir: meson.current_source_dir(),
)

script_test_fixture = files('script-test-fixture.vala')
script_test_deps = [dependency('glib-2.0'), dependency('gio-2.0')]

maintenance_test = executable(
    'maintenance-script-tests',
    script_test_fixture,
    'scripts-test.vala',
    dependencies: script_test_deps,
)
test('Maintenance script tests', maintenance_test, protocol: 'tap',
    workdir: meson.project_source_root())

check_command_test = executable(
    'check-command-tests',
    script_test_fixture,
    'check-script-test.vala',
    dependencies: script_test_deps,
)
test('Check command tests', check_command_test, protocol: 'tap',
    workdir: meson.project_source_root())

subdir('gui')
