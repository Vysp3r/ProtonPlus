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
  'Utils/Web.vala',
  'Utils/File.vala',
  'Utils/Dir.vala',

  'Models/Tool.vala',
  'Models/Launcher.vala',
  'Models/Release.vala',
  'Models/Preferences/Style.vala',

  'Widgets/ProtonActionRow.vala',

  'Windows/Main.vala',
  'Windows/ViewManager.vala',

  'Windows/Tools/LauncherSelector.vala',
  'Windows/Tools/LauncherInfo.vala',
  'Windows/Tools/ReleaseInstaller.vala',
  'Windows/Tools/ReleaseInfo.vala',
  'Windows/Tools/ToolInfo.vala',

  'Windows/Errors/GithubApiRequest.vala',

  'Windows/Games/Main.vala',

  'Windows/Notifications/Main.vala',

  'Windows/Preferences/Main.vala',

  'Application.vala',
)