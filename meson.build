project(
    'com.vysp3r.ProtonPlus', ['c', 'vala'],
    version: '0.4.3',
    meson_version: '>= 0.59.0'
)

#
i18n = import('i18n')
gnome = import('gnome')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

#
subdir('po')
subdir('data')
subdir('src')

#
executable(
    meson.project_name(),
    gresource,
    constants,
    sources,
    dependencies: [
        dependency('gtk4'),
        dependency('glib-2.0'),
        dependency('libadwaita-1', version: '>= 1.2'),
  	    dependency('json-glib-1.0'),
  	    dependency('libsoup-3.0'),
        dependency('gee-0.8'),
  	    dependency('libarchive'),
        meson.get_compiler('vala').find_library('posix'),
    ],
    install: true
)

#
gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)