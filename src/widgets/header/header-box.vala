namespace ProtonPlus.Widgets.Header {
    public class Box : Gtk.Box {
        public signal void launcher_selected (Models.Launcher launcher);

        public Adw.HeaderBar header_bar { get; private set; }
        LaunchersButton launchers_button { get; set; }
        DownloadsIndicator downloads_indicator { get; set; }
        Gtk.MenuButton menu_button { get; set; }
        Gtk.Button back_button { get; set; }
        Menu menu { get; set; }
        bool controller_mode_active = false;
        Adw.ViewSwitcher? global_view_switcher;
        Presentation? current_presentation;

        private bool _narrow_navigation = false;
        public bool narrow_navigation {
            get { return _narrow_navigation; }
            set {
                if (_narrow_navigation == value)
                    return;
                _narrow_navigation = value;
                update_title_widget ();
            }
        }

        public signal void download_selected (Services.InstallJob job);

        public Box () {
            launchers_button = new LaunchersButton ();
            launchers_button.launcher_selected.connect ((launcher) => launcher_selected (launcher));

            downloads_indicator = new DownloadsIndicator ();
            downloads_indicator.download_selected.connect ((job) => download_selected (job));

            menu = new Menu ();
            rebuild_menu ();

            menu_button = new Gtk.MenuButton ();
            menu_button.set_tooltip_text (_("Main Menu"));
            menu_button.set_icon_name ("bars-symbolic");
            menu_button.set_menu_model (menu);
            var menu_popover = menu_button.get_popover ();
            if (menu_popover != null)
                Window.register_popover_for_controller ((!) menu_popover, menu_button);

            back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            back_button.add_css_class ("flat");
            back_button.set_tooltip_text (_ ("Back"));
            back_button.clicked.connect (() => current_presentation?.request_back ());

            header_bar = new Adw.HeaderBar ();
            header_bar.pack_start (launchers_button);
            header_bar.pack_start (back_button);
            header_bar.pack_end (menu_button);
            header_bar.pack_end (downloads_indicator);
            header_bar.set_hexpand (true);

            append (header_bar);
        }

        public void set_controller_mode_active (bool active) {
            if (controller_mode_active == active)
                return;
            controller_mode_active = active;
            rebuild_menu ();
        }

        void rebuild_menu () {
            menu.remove_all ();
            menu.append (_("_Preferences"), "app.preferences");
            if (!controller_mode_active)
                menu.append (_("_Keyboard Shortcuts"), "win.show-help-overlay");
            menu.append (_("_Donate"), "app.donate");
            menu.append (_("_About ProtonPlus"), "app.about");
            if (controller_mode_active)
                menu.append (_("_Exit"), "app.quit");
        }

        public void initialize (Gee.LinkedList<Models.Launcher> launchers,
            Adw.ViewSwitcher? view_switcher) {
            launchers_button.initialize (launchers);
            global_view_switcher = view_switcher;
            update_title_widget ();
        }

        public void set_presentation (Presentation? presentation) {
            if (current_presentation == presentation) {
                update_title_widget ();
                return;
            }

            if (current_presentation != null) {
                ((!) current_presentation).attach_back_widget (null);
                foreach (var action in ((!) current_presentation).end_actions)
                    header_bar.remove (action);
            }

            current_presentation = presentation;

            back_button.set_visible (
                presentation != null && ((!) presentation).can_navigate_back
            );
            launchers_button.set_visible (presentation == null);
            downloads_indicator.set_global_header_visible (presentation == null);
            menu_button.set_visible (presentation == null);

            if (presentation != null) {
                ((!) presentation).attach_back_widget (back_button);
                foreach (var action in ((!) presentation).end_actions)
                    header_bar.pack_end (action);
            }

            update_title_widget ();
        }

        void update_title_widget () {
            if (current_presentation != null) {
                header_bar.set_title_widget (((!) current_presentation).title_widget);
                return;
            }

            if (!narrow_navigation && global_view_switcher != null &&
                (((!) global_view_switcher).get_parent () == null ||
                 header_bar.get_title_widget () == global_view_switcher))
                header_bar.set_title_widget ((!) global_view_switcher);
            else
                header_bar.set_title_widget (null);
        }

        public void open_menu () {
            menu_button.activate ();
        }

        public void open_launchers () {
            launchers_button.button_clicked ();
        }

        public bool select_launcher (Models.Launcher launcher) {
            return launchers_button.select_launcher (launcher);
        }

        public override void dispose () {
            if (current_presentation != null)
                ((!) current_presentation).attach_back_widget (null);
            current_presentation = null;
            global_view_switcher = null;
            base.dispose ();
        }
    }
}
