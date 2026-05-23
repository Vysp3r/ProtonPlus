namespace ProtonPlus.Widgets.Games {
    public class ShortcutButton : Gtk.Button {
        Models.SteamProfile profile { get; set; }

        construct {
            clicked.connect (shortcut_button_clicked);
        }

        public void load (Models.SteamProfile profile) {
            this.profile = profile;

            refresh ();
        }

        public void reset () {
            set_label (_ ("Create shortcut"));
        }

        void refresh () {
            var shortcut_installed = profile.shortcuts.get_installed_status ();
            set_label (!shortcut_installed ? _ ("Create shortcut") : _ ("Delete shortcut"));
            set_tooltip_text (!shortcut_installed ? _ ("Create a shortcut of ProtonPlus in Steam") : _ ("Delete the shortcut of ProtonPlus in Steam"));
        }

        void shortcut_button_clicked () {
            var installed = profile.shortcuts.get_installed_status ();

            if (installed) {
                var success = profile.shortcuts.uninstall ();
                if (!success) {
                    var dialog = new Main.ErrorDialog (_ ("Failed to Delete Shortcut"), _ ("ProtonPlus was unable to remove the shortcut from Steam. This might happen if Steam is currently running or if the shortcuts file is inaccessible."), "");
                    dialog.present ((Gtk.Window) this.get_root ());
                }
                refresh ();
            } else {
                profile.shortcuts.install.begin ((obj, res) => {
                    var success = profile.shortcuts.install.end (res);
                    if (!success) {
                        var dialog = new Main.ErrorDialog (_ ("Failed to Create Shortcut"), _ ("ProtonPlus was unable to add the shortcut to Steam. Please ensure Steam is closed and try again."), "");
                        dialog.present ((Gtk.Window) this.get_root ());
                    }
                    refresh ();
                });
            }
        }
    }
}
