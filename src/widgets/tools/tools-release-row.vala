namespace ProtonPlus.Widgets.Tools {
    public class ReleaseRow : Adw.ActionRow {
        protected Models.Release release { get; set; }

        Gtk.Button update_button { get; set; }
        Gtk.Button open_button { get; set; }
        Gtk.Button remove_button { get; set; }
        Gtk.Button install_button { get; set; }
        Gtk.Button cancel_button { get; set; }

        public ReleaseRow (Models.Release release) {
            Object (title: release.title);

            this.release = release;

            var icon = new Gtk.Image.from_icon_name ("box-open-symbolic");

            remove_button = new Gtk.Button.from_icon_name ("trash-symbolic");
            remove_button.set_tooltip_text (_ ("Delete %s").printf (release.title));
            remove_button.add_css_class ("flat");
            remove_button.clicked.connect (remove_button_clicked);

            install_button = new Gtk.Button.from_icon_name ("download-2-symbolic");
            install_button.set_tooltip_text (_ ("Install %s").printf (release.title));
            install_button.add_css_class ("flat");
            install_button.clicked.connect (install_button_clicked);

            cancel_button = new Gtk.Button.from_icon_name ("circle-xmark-symbolic");
            cancel_button.set_tooltip_text (_ ("Cancel download"));
            cancel_button.add_css_class ("flat");
            cancel_button.clicked.connect (() => { release.canceled = true; });

            var input_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            input_box.set_margin_end (10);
            input_box.set_valign (Gtk.Align.CENTER);
            input_box.add_css_class ("linked");
            input_box.add_css_class ("tools-release-row-input-box");

            if (release.title.contains ("Latest") || release.runner is Models.Tools.SteamTinkerLaunch) {
                update_button = new Gtk.Button.from_icon_name ("arrow-rotate-symbolic");
                update_button.add_css_class ("flat");
                update_button.set_tooltip_text (_ ("Update the runner if a newer version is available"));
                update_button.clicked.connect (update_button_clicked);

                input_box.append (update_button);
            }

            if (release.install_location != null) {
                open_button = new Gtk.Button.from_icon_name ("folder-open-2-symbolic");
                open_button.set_tooltip_text (_ ("Open runner directory"));
                open_button.add_css_class ("flat");
                open_button.clicked.connect (open_button_clicked);

                input_box.append (open_button);
            }

            input_box.append (remove_button);
            input_box.append (install_button);
            input_box.append (cancel_button);

            add_prefix (icon);
            add_suffix (input_box);

            release.notify["state"].connect (release_state_changed);

            release.notify_property ("state");
        }

        void release_state_changed () {
            var installed = release.state == Models.Release.State.UP_TO_DATE || release.state == Models.Release.State.UPDATE_AVAILABLE;
            var downloading = release.state == Models.Release.State.BUSY_INSTALLING ||
            release.state == Models.Release.State.BUSY_UPDATING;
            var busy = downloading || release.state == Models.Release.State.BUSY_REMOVING;

            install_button.set_visible (!installed && !downloading);
            cancel_button.set_visible (downloading);
            remove_button.set_visible (installed);
            update_button?.set_visible (installed);
            open_button?.set_visible (installed);

            install_button.set_sensitive (!busy);
            remove_button.set_sensitive (!busy);
            update_button?.set_sensitive (!busy);
            open_button?.set_sensitive (!busy);
        }

        void update_button_clicked () {
            release.update.begin ((obj, res) => {
                var success = release.update.end (res);
                if (!success && !release.canceled) {
                    var dialog = new Main.ErrorDialog (_ ("Couldn't update %s").printf (release.title), _ ("Please report this issue on GitHub."));
                    dialog.present ((Gtk.Window) this.get_root ());
                }
            });
        }

        void open_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (release.install_location));
        }

        protected virtual void install_button_clicked () {
            release.install.begin ((obj, res) => {
                var success = release.install.end (res);
                if (!success && !release.canceled) {
                    var dialog = new Main.ErrorDialog (_ ("Couldn't install %s").printf (release.title), _ ("Please report this issue on GitHub."));
                    dialog.present ((Gtk.Window) this.get_root ());
                }
            });
        }

        protected virtual void remove_button_clicked () {
            var remove_dialog = new RemoveDialog (release);
            remove_dialog.present ((Gtk.Window) this.get_root ());
        }
    }
}