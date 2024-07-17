#
subdir('css')

#
subdir('icons')

#
subdir('images')

#
icon_sizes = ['32', '48', '64', '128']
foreach i : icon_sizes
  install_data(
      join_paths('logo', 'com.vysp3r.ProtonPlus.png'),
      install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps'),
      rename: meson.project_name() + '.png'
  )

  install_data(
      join_paths('logo', 'com.vysp3r.ProtonPlus.png'),
      install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps'),
      rename: meson.project_name() + '.png'
  )
endforeach

#
desktop_file = i18n.merge_file(
        input: 'com.vysp3r.ProtonPlus.desktop.in',
       output: 'com.vysp3r.ProtonPlus.desktop',
         type: 'desktop',
       po_dir: '../po',
      install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

appstream_file = i18n.merge_file(
        input: 'com.vysp3r.ProtonPlus.metainfo.xml.in',
       output: 'com.vysp3r.ProtonPlus.metainfo.xml',
       po_dir: '../po',
      install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('Validate appstream file', appstream_util, args: ['validate', appstream_file])
endif

install_data('com.vysp3r.ProtonPlus.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file',
       compile_schemas,
       args: ['--strict', '--dry-run', meson.current_source_dir()])
endif