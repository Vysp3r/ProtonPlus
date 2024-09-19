configuration = configuration_data()
configuration.set_quoted('APP_ID', meson.project_name())
configuration.set_quoted('APP_VERSION', meson.project_version())
configuration.set_quoted('LOCALE_DIR', join_paths (get_option('prefix'), get_option('localedir')))

constants = configure_file(
    input : 'constants.vala.in',
    output : 'constants.vala',
    configuration : configuration
)

sources = files(
  'application.vala',

  'window.vala',

  'widgets/info-box.vala',
  'widgets/status-box.vala',
  'widgets/sidebar.vala',
  'widgets/release-row-button.vala',
  'widgets/release-row.vala',
  'widgets/dialog.vala',

  'widgets/release-rows/steamtinkerlaunch.vala',
  'widgets/release-rows/basic.vala',

  'models/group.vala',
  'models/launcher.vala',
  'models/release.vala',
  'models/runner.vala',

  'models/launchers/bottles.vala',
  'models/launchers/hgl.vala',
  'models/launchers/lutris.vala',
  'models/launchers/steam.vala',

  'models/runners/basic.vala',
  'models/runners/github.vala',
  'models/runners/github-action.vala',
  'models/runners/gitlab.vala',
  'models/runners/proton-ge.vala',
  'models/runners/luxtorpeda.vala',
  'models/runners/boxtron.vala',
  'models/runners/roberta.vala',
  'models/runners/northstar-proton.vala',
  'models/runners/proton-ge-rstp.vala',
  'models/runners/proton-tkg.vala',
  'models/runners/steamtinkerlaunch.vala',
  'models/runners/wine-ge.vala',
  'models/runners/wine-lutris.vala',
  'models/runners/kron4ek-wine-builds-staging-tkg.vala',
  'models/runners/kron4ek-wine-builds-staging.vala',
  'models/runners/kron4ek-wine-builds-vanilla.vala',
  'models/runners/other.vala',
  'models/runners/dxvk-async-sporif.vala',
  'models/runners/dxvk-async-gnusenpai.vala',
  'models/runners/dxvk-gpl-async-ph42on.vala',
  'models/runners/dxvk-doitsujin.vala',
  'models/runners/vkd3d-lutris.vala',
  'models/runners/vkd3d-proton.vala',

  'models/releases/basic.vala',
  'models/releases/steamtinkerlaunch.vala',

  'utils/filesystem.vala',
  'utils/web.vala',
  'utils/parser.vala',
  'utils/system.vala',
)

protonplus_deps = [
    dependency('gtk4'),
    dependency('glib-2.0'),
    dependency('libadwaita-1', version: '>= 1.4'),
  	dependency('json-glib-1.0'),
  	dependency('libsoup-3.0'),
    dependency('gee-0.8'),
  	dependency('libarchive')
]

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