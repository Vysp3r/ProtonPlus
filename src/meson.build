protonplus_sources = [
  'interfaces/IModel.vala',
  'interfaces/IView.vala',

  'manager/Preference.vala',
  'manager/Theme.vala',
  'manager/Web.vala',
  'manager/File.vala',

  'models/preferences/Style.vala',
  'models/Tool.vala',
  'models/Launcher.vala',
  'models/Release.vala',

  'stores/Preferences.vala',
  'stores/Threads.vala',

  'views/Games.vala',
  'views/Tools.vala',
  'views/Notifications.vala',

  'widgets/ProtonComboRow.vala',
  'widgets/ProtonMessageDialog.vala',

  'windows/Home.vala',
  'windows/HomeInfo.vala',
  'windows/Preferences.vala',
  'windows/Selector.vala',

  'main.vala',
  'application.vala',
]

protonplus_deps = [
  dependency('libadwaita-1', version: '>= 1.2'),
  dependency('json-glib-1.0'),
  dependency('libsoup-3.0'),
  dependency('libarchive')
]

gnome = import('gnome')

protonplus_sources += gnome.compile_resources('protonplus-resources',
  'protonplus.gresource.xml',
  c_name: 'protonplus'
)

executable('protonplus', protonplus_sources,
  vala_args: '--target-glib=2.50',  dependencies: protonplus_deps,
  install: true,
)