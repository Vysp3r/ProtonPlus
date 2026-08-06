namespace ProtonPlus.Widgets {
    private class GtkControllerHostAdapter : Object, Utils.ControllerHostAdapter {
        public bool is_controller_window (Object candidate) {
            return candidate is Window;
        }

        public Object? get_root (Object candidate) {
            var widget = candidate as Gtk.Widget;
            return widget?.get_root () as Object;
        }
    }

    private class ControllerPopoverRegistration : Object {
        weak Gtk.Popover? popover;
        weak Gtk.Widget? opener;
        weak Gtk.Widget? initial_focus;
        ulong visible_handler = 0;
        ulong map_handler = 0;

        public ControllerPopoverRegistration (Gtk.Popover popover, Gtk.Widget opener,
            Gtk.Widget? initial_focus) {
            this.popover = popover;
            this.opener = opener;
            this.initial_focus = initial_focus;
        }

        public void start () {
            if (popover == null)
                return;
            visible_handler = ((!) popover).notify["visible"].connect (try_register);
            map_handler = ((!) popover).map.connect (try_register);
            try_register ();
        }

        void try_register () {
            var current_popover = popover;
            var current_opener = opener;
            if (current_popover == null || current_opener == null || !current_popover.get_visible ())
                return;

            var controller_window = Window.resolve_controller_window (current_opener);
            if (controller_window == null)
                controller_window = Window.resolve_controller_window (current_popover);
            if (controller_window == null)
                return;

            controller_window.register_controller_popover (
                current_popover, current_opener, initial_focus
            );
            if (visible_handler != 0) {
                current_popover.disconnect (visible_handler);
                visible_handler = 0;
            }
            if (map_handler != 0) {
                current_popover.disconnect (map_handler);
                map_handler = 0;
            }
        }
    }

    public class Window : Adw.ApplicationWindow {
        public Gee.LinkedList<Models.Launcher> launchers { get; set; }
        Utils.ControllerManager controller_manager { get; set; }

        Header.Box header_box { get; set; }
        Loading.Box loading_box { get; set; }
        public Main.Box main_box { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }

        private Services.SteamRestartManager restart_manager;
        private Services.SteamRestartOrchestrator restart_orchestrator;

        public Window (Services.SteamRestartManager restart_manager, Services.SteamRestartOrchestrator restart_orchestrator) {
            Object (application: (Adw.Application) GLib.Application.get_default (), title: Config.APP_NAME);
            this.restart_manager = restart_manager;
            this.restart_orchestrator = restart_orchestrator;

            controller_manager = new Utils.ControllerManager (this);
            var navigate_back_action = new SimpleAction ("navigate-back", null);
            navigate_back_action.activate.connect ((parameter) => controller_manager.navigate_application_back ());
            add_action (navigate_back_action);

            build_ui ();
            controller_manager.start ();
        }

        public static void present_dialog_for_controller (Adw.Dialog dialog, Gtk.Widget? parent) {
            var controller_window = resolve_controller_window (parent);
            if (controller_window != null) {
                controller_window.present_controller_dialog (dialog, parent);
                return;
            }

            dialog.present (parent);
        }

        public static void register_popover_for_controller (Gtk.Popover popover,
            Gtk.Widget opener, Gtk.Widget? initial_focus = null) {
            new ControllerPopoverRegistration (popover, opener, initial_focus).start ();
        }

        internal static Window? resolve_controller_window (Gtk.Widget? parent) {
            return Utils.ControllerWindowResolver.resolve (
                parent, new GtkControllerHostAdapter ()
            ) as Window;
        }

        public void present_controller_dialog (Adw.Dialog dialog, Gtk.Widget? parent = null) {
            controller_manager.register_dialog (dialog);
            dialog.present (parent ?? this);
        }

        internal void register_controller_popover (Gtk.Popover popover,
            Gtk.Widget opener, Gtk.Widget? initial_focus = null) {
            controller_manager.register_popover (popover, opener, initial_focus);
        }

        public void open_menu () {
            header_box.open_menu ();
        }

        public void open_launchers () {
            header_box.open_launchers ();
        }

        private void build_ui () {
            header_box = new Header.Box ();
            header_box.launcher_selected.connect ((launcher) => {
                main_box.set_selected_launcher (launcher);
            });

            loading_box = new Loading.Box ();
            loading_box.loaded.connect ((launchers) => {
                this.launchers = launchers;

                header_box.initialize (launchers, main_box.view_switcher);
                main_box.initialize (launchers);
                toolbar_view.set_content (main_box);

                if (Globals.SETTINGS.get_boolean ("check-updates-on-launch")) {
                    main_box.check_for_updates.begin (launchers);
                }
            });

            main_box = new Main.Box (restart_manager, restart_orchestrator);
            header_box.download_selected.connect ((job) => {
                main_box.navigate_to_download (job);
            });

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_box);
            toolbar_view.set_content (loading_box);

            set_content (toolbar_view);

            loading_box.load.begin ();
        }

        public void reload_ui () {
            var toplevels = Gtk.Window.get_toplevels ();
            for (uint i = 0; i < toplevels.get_n_items (); i++) {
                var popover = toplevels.get_item (i) as Gtk.Popover;

                if (popover != null && popover.get_root () == this) {
                    popover.popdown (); // Bezpečně sklopíme/zavřeme bublinu
                }
            }

            build_ui ();
        }

        public void reload () {
            toolbar_view.set_content (loading_box);

            loading_box.load.begin ();
        }

        public override bool close_request () {
            if (Utils.DownloadManager.instance.active_downloads.size == 0) {
                controller_manager.stop ();

                return false;
            }

            var dialog = new Adw.AlertDialog (
                _ ("Warning"),
                _ ("The application is currently downloading a tool.\nExiting the application early may cause issues.")
            );

            dialog.add_response ("exit", _ ("Exit"));
            dialog.set_response_appearance ("exit", Adw.ResponseAppearance.DESTRUCTIVE);

            dialog.add_response ("cancel", _ ("Cancel"));
            dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.SUGGESTED);

            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");

            dialog.response.connect ((response) => {
                if (response != "exit")
                return;

                controller_manager.stop ();

                application.quit ();
            });

            present_controller_dialog (dialog);

            return true;
        }
    }
}
