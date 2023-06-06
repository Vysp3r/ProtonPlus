namespace ProtonPlus.Launcher {
    public class LauncherWindow : Adw.ApplicationWindow {
        List<Shared.Models.Launcher> launchers;

        int tasks;

        Adw.Leaflet content_leaflet;
        Adw.Leaflet other_leaflet;

        Launcher.LauncherListBox launcher_list_box;
        Launcher.LauncherInfoBox launcher_info_box;

        construct {
            //
            set_application ((Adw.Application) GLib.Application.get_default ());
            set_title (Shared.Constants.APP_NAME);
            set_default_size (950, 600);

            //
            var launcher_warning_box = new Launcher.LauncherWarningBox ();

            //
            launcher_list_box = new Launcher.LauncherListBox ();

            //
            var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);

            //
            launcher_info_box = new Launcher.LauncherInfoBox ();

            //
            content_leaflet = new Adw.Leaflet ();
            content_leaflet.append (launcher_list_box);
            content_leaflet.append (separator);
            content_leaflet.append (launcher_info_box);
            content_leaflet.notify.connect ((pspec) => {
                if (pspec.get_name () == "folded") {
                    launcher_list_box.set_header_controls_visible (content_leaflet.get_folded ());
                    launcher_info_box.set_back_btn_visible (content_leaflet.get_folded ());
                }
            });

            //
            other_leaflet = new Adw.Leaflet ();
            other_leaflet.set_can_unfold (false);
            other_leaflet.append (content_leaflet);
            other_leaflet.append (launcher_warning_box);

            //
            this.add_action (load_info_box ());
            this.add_action (switch_other_page ());
            this.add_action (switch_content_page ());
            this.add_action (add_task ());
            this.add_action (remove_task ());

            //
            set_content (other_leaflet);
        }

        public override bool close_request () {
            bool busy = tasks > 0;

            if (busy) {
                this.set_visible (false);

                GLib.Timeout.add (1000, () => {
                    if (tasks == 0) this.close ();

                    return true;
                });
            }

            return busy;
        }

        public void initialize () {
            tasks = 0;
            launchers = Shared.Models.Launcher.get_all ();
            if (launchers.length () > 0) {
                launcher_info_box.initialize (launchers); // Must be loaded before since list_box relies on info_box being initialized
                launcher_list_box.initialize (launchers);
            } else {
                this.activate_action_variant ("win.switch-other-page", 2);
            }
        }

        SimpleAction switch_other_page () {
            SimpleAction action = new SimpleAction ("switch-other-page", VariantType.INT32);

            action.activate.connect ((variant) => {
                other_leaflet.get_pages ().select_item (variant.get_int32 (), true);
            });

            return action;
        }

        SimpleAction switch_content_page () {
            SimpleAction action = new SimpleAction ("switch-content-page", VariantType.INT32);

            action.activate.connect ((variant) => {
                content_leaflet.get_pages ().select_item (variant.get_int32 (), true);
            });

            return action;
        }

        SimpleAction load_info_box () {
            SimpleAction action = new SimpleAction ("load-info-box", VariantType.INT32);

            action.activate.connect ((variant) => {
                if (content_leaflet.get_folded ()) this.activate_action_variant ("win.switch-content-page", 2);
                launcher_info_box.switch_launcher (launchers.nth_data (variant.get_int32 ()).title, variant.get_int32 ());
            });

            return action;
        }

        SimpleAction add_task () {
            SimpleAction action = new SimpleAction ("add-task", VariantType.STRING);

            action.activate.connect (() => {
                tasks++;
            });

            return action;
        }

        SimpleAction remove_task () {
            SimpleAction action = new SimpleAction ("remove-task", VariantType.STRING);

            action.activate.connect (() => {
                tasks--;
            });

            return action;
        }
    }
}