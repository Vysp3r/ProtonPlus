namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Updates : Base {
        public Updates () {
            base (
                  _("Keep Everything Updated"),
                  _("ProtonPlus can automatically check for and install updates to keep your gaming experience smooth."),
                  "arrows-rotate-symbolic"
            );

            var updates_group = new Adw.PreferencesGroup ();
            updates_group.margin_top = 12;

            var background_updates_row = new Adw.SwitchRow () {
                title = _("Background updates"),
                subtitle = _("Automatically update the tools in the background"),
            };
            Globals.SETTINGS.bind ("background-updates", background_updates_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (background_updates_row);

            var background_updates_frequency_row = new Preferences.BackgroundUpdatesFrequencyRow () {
                subtitle = _("Set how often to check for updates in the background"),
            };
            background_updates_row.bind_property ("active", background_updates_frequency_row, "sensitive", BindingFlags.SYNC_CREATE);
            updates_group.add (background_updates_frequency_row);

            var check_updates_on_boot_row = new Adw.SwitchRow () {
                title = _("Check updates on boot"),
                subtitle = _("Check for tool updates when the system starts"),
            };
            Globals.SETTINGS.bind ("check-updates-on-boot", check_updates_on_boot_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (check_updates_on_boot_row);

            var check_updates_on_launch_row = new Adw.SwitchRow () {
                title = _("Check updates on launch"),
                subtitle = _("Update the tools when the application is launched"),
            };
            Globals.SETTINGS.bind ("check-updates-on-launch", check_updates_on_launch_row, "active", SettingsBindFlags.DEFAULT);
            updates_group.add (check_updates_on_launch_row);

            this.append (updates_group);
        }
    }
}
