#
configuration = configuration_data()
configuration.set_quoted('APP_ID', meson.project_name())
configuration.set_quoted('APP_VERSION', meson.project_version())
configuration.set_quoted('LOCALE_DIR', join_paths (get_option('prefix'), get_option('localedir')))

#
constants = configure_file(
    input : 'Constants.vala.in',
    output : 'Constants.vala',
    configuration : configuration
)

#
subdir('models')

#
subdir('launchers')

#
subdir('utils')