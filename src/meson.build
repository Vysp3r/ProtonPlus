protonplus_sources += [
  'Interfaces/IModel.vala',
  'Interfaces/IView.vala',

  'Utils/Preference.vala',
  'Utils/Theme.vala',
  'Utils/Web.vala',
  'Utils/File.vala',

  'Models/preferences/Style.vala',
  'Models/Tool.vala',
  'Models/Launcher.vala',
  'Models/Release.vala',

  'Stores/Preferences.vala',
  'Stores/Threads.vala',

  'Views/Games.vala',
  'Views/Tools.vala',
  'Views/Notifications.vala',

  'Widgets/ProtonComboRow.vala',
  'Widgets/ProtonMessageDialog.vala',

  'Windows/Home.vala',
  'Windows/About.vala',
  'Windows/Preferences.vala',
  'Windows/Installer.vala',
  'Windows/LauncherSettings.vala',

  'Main.vala',
  'Application.vala',
]

vapi_sources = files(
  'Config.vapi'
)

protonplus_sources += vapi_sources

protonplus_deps = [
  dependency('libadwaita-1', version: '>= 1.2'),
  dependency('json-glib-1.0'),
  dependency('libsoup-3.0'),
  dependency('libarchive')
]

protonplus_vala_args = [
  '--vapidir', meson.current_source_dir(),
  '--target-glib', '2.50',
]

protonplus_c_args = [
  '-include', 'config.h',
]

executable('protonplus', protonplus_sources,
  include_directories: config_h_dir,
  vala_args: protonplus_vala_args,
  c_args: protonplus_c_args,
  dependencies: protonplus_deps,
  install: true,
)