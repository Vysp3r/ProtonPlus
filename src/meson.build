protonplus_sources = [
  'main.vala',
  'application.vala',

  'stores/preferences.vala',
  'stores/threads.vala',

  'manager/preferences.vala',
  'manager/themes.vala',
  'manager/http.vala',
  'manager/file.vala',

  'models/preference.vala',
  'models/compatibilitytool.vala',
  'models/location.vala',
  'models/launcher.vala',

  'widgets/protoncb.vala',
  'widgets/protonrow.vala',

  'views/games.vala',
  'views/other.vala',
  'views/tools.vala',

  'windows/home.vala',
  'windows/home_custom_directory.vala',
  'windows/home_info.vala',
  'windows/preferences.vala',
  'windows/selector.vala',
]

#vapi_dir = meson.current_source_dir() / 'vapi'

#add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

protonplus_deps = [
  dependency('libadwaita-1', version: '>= 1.2'),
  dependency('json-glib-1.0'),
  dependency('libsoup-3.0'),
  dependency('libarchive'),
  meson.get_compiler('vala').find_library('posix')
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