project(
    'com.vysp3r.ProtonPlus', ['c', 'vala'],
    version: '0.5.3',
    meson_version: '>= 1.0.0',
    default_options: [ 'warning_level=2', 'werror=false', ],
)

i18n = import('i18n')
gnome = import('gnome')
valac = meson.get_compiler('vala')

src_dir = meson.project_source_root() / 'src'

globals_h = configuration_data()
globals_h.set_quoted('APP_NAME', meson.project_name().split('.')[2])
globals_h.set_quoted('APP_ID', meson.project_name())
globals_h.set_quoted('APP_VERSION', meson.project_version())
globals_h.set_quoted('LOCALE_DIR', join_paths (get_option('prefix'), get_option('localedir')))
globals_h.set_quoted('RESOURCE_BASE', join_paths('/', meson.project_name().replace('.', '/')))
configure_file(output : 'globals.h', configuration : globals_h)

globals_dep = valac.find_library ('globals', dirs: src_dir)
globals_inc = include_directories('.')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)