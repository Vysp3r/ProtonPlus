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
        'environment': ['GSK_RENDERER=cairo'],
    },
    {
        'target': 'tools-presentation-test',
        'name': 'Tools presentation',
        'environment': ['PROTONPLUS_TEST_FIXTURES=' + (meson.project_source_root() / 'tests' / 'fixtures')],
    },
    {
        'target': 'games-presentation-test',
        'name': 'Games presentation',
        'environment': ['GSK_RENDERER=cairo', 'LC_ALL=C'],
        'xvfb_args': ['-s', '-screen 0 1280x1024x24'],
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
        dependencies: deps + [resources_dep],
        link_with: protonplus_lib,
        include_directories: [config_inc, include_directories('../../src')],
        vala_args: ['--target-glib=2.58'],
    )
    gui_test_env = ['GTK_A11Y=none'] + gui_test['environment']
    if xvfb_run.found()
        test(gui_test['name'], xvfb_run,
            args: ['-a'] + gui_test.get('xvfb_args', []) + [gui_test_exe],
            env: ['GDK_BACKEND=x11'] + gui_test_env)
    else
        # Help checks focus restoration. Other GUI tests can steal focus
        # when they share the desktop display.
        test(gui_test['name'], gui_test_exe, env: gui_test_env,
            is_parallel: gui_test['target'] != 'help-presentation-test')
    endif
endforeach
