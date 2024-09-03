#
configuration = configuration_data()
configuration.set_quoted('APP_ID', meson.project_name())
configuration.set_quoted('APP_VERSION', meson.project_version())
configuration.set_quoted('LOCALE_DIR', join_paths (get_option('prefix'), get_option('localedir')))

#
constants = configure_file(
    input : 'constants.vala.in',
    output : 'constants.vala',
    configuration : configuration
)

#
sources = files(
  'application.vala',

  'window.vala',

  'widgets/info-box.vala',
  'widgets/status-box.vala',
  'widgets/sidebar.vala',

  'launchers/bottles.vala',
  'launchers/hgl.vala',
  'launchers/lutris.vala',
  'launchers/steam.vala',

  'releases/stl_release.vala',

  'models/group.vala',
  'models/launcher.vala',
  'models/release.vala',
  'models/runner.vala',

  'utils/filesystem.vala',
  'utils/web.vala',
  'utils/parser.vala',
  'utils/system.vala',
)

#
protonplus_deps = [
    dependency('gtk4'),
    dependency('glib-2.0'),
    dependency('libadwaita-1', version: '>= 1.4'),
  	dependency('json-glib-1.0'),
  	dependency('libsoup-3.0'),
    dependency('gee-0.8'),
  	dependency('libarchive')
]

#
executable(
    meson.project_name(),
    css_gresource,
    icons_gresource,
    images_gresource,
    constants,
    sources,
    dependencies: protonplus_deps,
    install: true
)