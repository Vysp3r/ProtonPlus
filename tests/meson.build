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
    'asset_test.vala',
    'filesystem_test.vala',
    'web_test.vala',
    'system-path-test.vala',
    'systemd-timer-test.vala',
    'migration-v0.6.6-test.vala',
    'faugus-launcher-test.vala',
    'metadata_test.vala',
    'compatibility-tool-test.vala',
    'steam-compatibility-tool-discovery-test.vala',
    'steam-library-diagnostics-test.vala',
    'installed-tool-inventory-test.vala',
    'parser_test.vala',
    'launch-command-test.vala',
    'launch-command-parser-test.vala',
    'launch-command-composer-test.vala',
    'launch-command-editor-projection-test.vala',
    'launch-command-writer-test.vala',
    'launch-option-capability-resolver-test.vala',
    'provider_definition_test.vala',
    'provider_registry_test.vala',
    'provider_source_test.vala',
    'identity_test.vala',
    'cli_test.vala',
    'release_identity_test.vala',
    'release_page_test.vala',
    'release-catalog-test.vala',
    'variant_settings_test.vala',
    'install_layout_test.vala',
    'compatibility-process-guard-test.vala',
    'installer-transaction-test.vala',
    'steam_test.vala',
    'steam-session-test.vala',
    'steam-game-launch-test.vala',
    'steam-configuration-service-test.vala',
    'steam-restart-manager-test.vala',
    'steam-restart-orchestrator-test.vala',
    'steam-restart-presentation-test.vala',
    'steamtinkerlaunch-test.vala',
    'tinkergame-test.vala',
    'update-transaction-test.vala',
    'vdf_binary_test.vala',
)

test_exe = executable(
    'protonplus-tests',
    test_sources,
    resources,
    dependencies: deps,
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

python = import('python').find_installation()
test('Maintenance script tests', python, args: files('scripts_test.py'))
test('Check command tests', python, args: files('check_script_test.py'))

# Keep GUI harness settings together so every presentation test gets the same
# display setup. Test-specific rendering or locale requirements stay explicit.
xvfb_run = find_program('xvfb-run', required: false)
foreach gui_test : [
    {
        'target': 'downloads-presentation-test',
        'name': 'Downloads presentation',
        'environment': ['GSK_RENDERER=cairo', 'LC_ALL=C.UTF-8', 'LANGUAGE=de',
            'PROTONPLUS_TEST_LOCALES=' + (meson.project_build_root() / 'po')],
    },
    {
        'target': 'steam-diagnostics-presentation-test',
        'name': 'Steam diagnostics presentation',
        'environment': ['GSK_RENDERER=cairo', 'LC_ALL=C'],
    },
    {
        'target': 'launch-option-flags-widget-test',
        'name': 'Launch option flag widgets',
        'environment': [],
    },
    {
        'target': 'tools-presentation-test',
        'name': 'Tools presentation',
        'environment': ['PROTONPLUS_TEST_FIXTURES=' + (meson.current_source_dir() / 'fixtures')],
    },
    {
        'target': 'games-presentation-test',
        'name': 'Games presentation',
        'environment': ['GSK_RENDERER=cairo', 'LC_ALL=C'],
    },
    {
        'target': 'help-presentation-test',
        'name': 'Help presentation',
        'environment': ['GSK_RENDERER=cairo', 'LC_ALL=C'],
    },
]
    gui_test_exe = executable(
        gui_test['target'],
        gui_test['target'] + '.vala',
        resources,
        dependencies: deps,
        link_with: protonplus_lib,
        include_directories: [config_inc, include_directories('../src')],
        vala_args: ['--target-glib=2.58'],
    )
    gui_test_env = ['GTK_A11Y=none'] + gui_test['environment']
    if xvfb_run.found()
        test(gui_test['name'], xvfb_run,
            args: ['-a', gui_test_exe],
            env: ['GDK_BACKEND=x11'] + gui_test_env)
    else
        test(gui_test['name'], gui_test_exe, env: gui_test_env)
    endif
endforeach
