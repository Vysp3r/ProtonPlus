protonplus_sources = gnome.compile_resources('protonplus-resources',
  'com.vysp3r.ProtonPlus.gresource.xml',
  c_name: 'protonplus'
)

desktop_file = install_data('com.vysp3r.ProtonPlus.desktop',
  install_dir: join_paths(get_option('datadir'), 'applications')
)

appstream_file = install_data('com.vysp3r.ProtonPlus.appdata.xml',
  install_dir: join_paths(get_option('datadir'), 'appdata')
)

install_data('com.vysp3r.ProtonPlus.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

subdir('icons')
