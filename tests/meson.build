test_sources = files(
  'main.vala',
  'base.vala',
  'example_test.vala',
)

test_exe = executable('protonplus-tests',
  test_sources,
  dependencies: deps,
  link_with: protonplus_lib,
  include_directories: [config_inc, include_directories('../src')],
  vala_args: ['--target-glib=2.58'],
)

test('ProtonPlus Unit Tests', test_exe, protocol: 'tap')