test_env = environment()
test_sources = files(
  'main.vala',
  'base.vala',
  'example_test.vala',
)

subdir('models')

test_exe = executable('protonplus-tests',
  test_sources,
  resources,
  dependencies: deps,
  link_with: protonplus_lib,
  include_directories: [config_inc, include_directories('../src')],
  vala_args: ['--target-glib=2.58'],
)

test('ProtonPlus Unit Tests', test_exe, env: test_env, protocol: 'tap')