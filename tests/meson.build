test_sources = files(
    'main.vala',
    'filesystem_test.vala',
    'metadata_test.vala',
    'parser_test.vala',
    'steam_test.vala',
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

test('ProtonPlus unit tests', test_exe, protocol: 'tap')

python = import('python').find_installation()
test('Maintenance script tests', python, args: files('scripts_test.py'))
