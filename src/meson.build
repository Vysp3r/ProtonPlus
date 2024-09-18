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
  'widgets/release-row.vala',
  'widgets/release-row-button.vala',
  'widgets/dialog.vala',

  'models/group.vala',
  'models/launcher.vala',
  'models/release.vala',
  'models/runner.vala',

  'launchers/bottles.vala',
  'launchers/hgl.vala',
  'launchers/lutris.vala',
  'launchers/steam.vala',

  'releases/steamtinkerlaunch.vala',

  'runners/basic.vala',
  'runners/github.vala',
  'runners/github-action.vala',
  'runners/gitlab.vala',
  'runners/proton-ge.vala',
  'runners/luxtorpeda.vala',
  'runners/boxtron.vala',
  'runners/roberta.vala',
  'runners/northstar-proton.vala',
  'runners/proton-ge-rstp.vala',
  'runners/proton-tkg.vala',
  'runners/steamtinkerlaunch.vala',
  'runners/wine-ge.vala',
  'runners/wine-lutris.vala',
  'runners/kron4ek-wine-builds-staging-tkg.vala',
  'runners/kron4ek-wine-builds-staging.vala',
  'runners/kron4ek-wine-builds-vanilla.vala',
  'runners/other.vala',
  'runners/dxvk-async-sporif.vala',
  'runners/dxvk-async-gnusenpai.vala',
  'runners/dxvk-gpl-async-ph42on.vala',
  'runners/dxvk-doitsujin.vala',
  'runners/vkd3d-lutris.vala',
  'runners/vkd3d-proton.vala',

  'utils/filesystem.vala',
  'utils/web.vala',
  'utils/parser.vala',
  'utils/system.vala',
  'utils/gui.vala',
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