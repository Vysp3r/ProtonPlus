namespace ProtonPlus.Widgets.Preferences {
    public class SteamShortcutRow : Adw.ActionRow {
        Models.SteamProfile profile { get; set; }
        Gtk.Button shortcut_button;

        construct {
            shortcut_button = new Gtk.Button ();
            shortcut_button.add_css_class ("flat");
            shortcut_button.set_valign (Gtk.Align.CENTER);
            shortcut_button.clicked.connect (shortcut_button_clicked);

            set_title (_ ("Manage shortcut"));
            add_suffix (shortcut_button);
        }

        public SteamShortcutRow (Models.SteamProfile profile) {
            load (profile);
        }

        public void load (Models.SteamProfile profile) {
            this.profile = profile;
            refresh ();
        }

        void refresh () {
            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            var shortcut_installed = configuration != null
                ? configuration.protonplus_shortcut_is_effectively_installed (profile)
                : profile.shortcuts.get_installed_status ();
            shortcut_button.set_label (!shortcut_installed ? _ ("Create shortcut") : _ ("Delete shortcut"));
            set_subtitle (!shortcut_installed ? _ ("Create a shortcut of ProtonPlus in Steam") : _ ("Delete the shortcut of ProtonPlus in Steam"));
        }

        void shortcut_button_clicked () {
            var configuration = ProtonPlus.Services.SteamConfigurationService.instance;
            if (configuration == null)
                return;
            var installed = configuration.protonplus_shortcut_is_effectively_installed (profile);
            shortcut_button.set_sensitive (false);
            var current_profile = profile;
            if (installed) {
                configuration.remove_protonplus_shortcut.begin (current_profile, (obj, res) => {
                    present_shortcut_result (configuration.remove_protonplus_shortcut.end (res), false);
                });
            } else {
                configuration.install_protonplus_shortcut.begin (current_profile, (obj, res) => {
                    present_shortcut_result (configuration.install_protonplus_shortcut.end (res), true);
                });
            }
        }

        private void present_shortcut_result (ProtonPlus.Services.SteamConfigurationMutation result, bool creating) {
            if (!result.accepted) {
                var dialog = new Main.ErrorDialog (
                    creating ? _ ("Failed to create shortcut") : _ ("Failed to delete shortcut"),
                    creating
                        ? _ ("ProtonPlus was unable to add the shortcut to Steam. Please ensure Steam is closed and try again.")
                        : _ ("ProtonPlus was unable to remove the shortcut from Steam. This might happen if Steam is currently running or if the shortcuts file is inaccessible."),
                    ""
                );
                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());
            }
            shortcut_button.set_sensitive (true);
            refresh ();
        }
    }
}
