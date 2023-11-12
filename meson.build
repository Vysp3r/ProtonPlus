#
project(
    'com.vysp3r.ProtonPlus', ['c', 'vala'],
    version: '0.4.7',
    meson_version: '>= 0.62.0',
    default_options: [ 'warning_level=2', 'werror=false', ],
)

#
i18n = import('i18n')
gnome = import('gnome')

#
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

#
subdir('po')

#
subdir('data')

#
subdir('src')

#
gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)