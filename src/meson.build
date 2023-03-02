configuration = configuration_data()

configuration.set_quoted('APP_ID', meson.project_name())
configuration.set_quoted('APP_VERSION', meson.project_version())
configuration.set_quoted('LOCALE_DIR', join_paths (get_option('prefix'), get_option('localedir')))

constants = configure_file(
    input : 'Utils/Constants.vala.in',
    output : 'Constants.vala',
    configuration : configuration
)

#
sources = files(
  'Interfaces/IModel.vala',

  'Utils/Preference.vala',
  'Utils/Theme.vala',
  'Utils/Web.vala',
  'Utils/File.vala',
  'Utils/Dir.vala',

  'Models/preferences/Style.vala',
  'Models/Preference.vala',
  'Models/Tool.vala',
  'Models/Launcher.vala',
  'Models/Release.vala',

  'Stores/Main.vala',

  'Widgets/ProtonComboRow.vala',
  'Widgets/ProtonMessageDialog.vala',

  'Windows/Home.vala',
  'Windows/About.vala',
  'Windows/Preferences.vala',
  'Windows/Installer.vala',
  'Windows/LauncherSettings.vala',

  'Windows/Views/Games.vala',
  'Windows/Views/Tools.vala',
  'Windows/Views/Notifications.vala',

  'Application.vala',
)