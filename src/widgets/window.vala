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
            if (current_popover == null || current_opener == null ||
                !Utils.ControllerSurfacePolicy.can_register_popover (
                    current_popover.get_visible (), current_popover.get_mapped ()
                ))
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
        // Leave room for the launcher, three-page switcher, downloads, and menu.
        const double NARROW_NAVIGATION_WIDTH = 700;
        const int MINIMUM_WINDOW_WIDTH = 384;
        const int MINIMUM_WINDOW_HEIGHT = 360;

        public Gee.LinkedList<Models.Launcher> launchers { get; set; }
        Utils.ControllerManager controller_manager { get; set; }

        Header.Box header_box { get; set; }
        Loading.Box loading_box { get; set; }
        public Main.Box main_box { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }
        Adw.BreakpointBin responsive { get; set; }
        ControllerHintBar controller_hint_bar { get; set; }
        ulong controller_presentation_handler = 0;
        ulong header_presentation_handler = 0;
        ulong search_availability_handler = 0;
        bool navigation_breakpoint_added = false;
        bool main_content_visible = false;
        SimpleAction search_action;

        private Services.SteamRestartManager restart_manager;
        private Services.SteamRestartOrchestrator restart_orchestrator;

        public Window (Services.SteamRestartManager restart_manager, Services.SteamRestartOrchestrator restart_orchestrator) {
            Object (application: (Adw.Application) GLib.Application.get_default (), title: Config.APP_NAME);
            this.restart_manager = restart_manager;
            this.restart_orchestrator = restart_orchestrator;

            controller_manager = new Utils.ControllerManager (this);
            controller_presentation_handler = controller_manager.presentation_changed.connect ((state) => {
                controller_hint_bar.update_state (state);
                header_box.set_controller_mode_active (state.controller_mode_active);
            });
            var navigate_back_action = new SimpleAction ("navigate-back", null);
            navigate_back_action.activate.connect ((parameter) => controller_manager.navigate_application_back ());
            add_action (navigate_back_action);
            search_action = new SimpleAction ("search", null);
            search_action.activate.connect ((parameter) => {
                main_box.controller_open_search ();
            });
            search_action.set_enabled (false);
            add_action (search_action);

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

        public bool focus_launcher_selector () {
            return header_box.focus_launchers ();
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
            var alert_dialog = dialog as Adw.AlertDialog;
            if (alert_dialog != null)
                prepare_alert_dialog_focus ((!) alert_dialog);
            dialog.present (parent ?? this);
            if (alert_dialog != null) {
                GLib.Idle.add (() => {
                    if (((!) alert_dialog).get_mapped ())
                        prepare_alert_dialog_focus ((!) alert_dialog);
                    return GLib.Source.REMOVE;
                });
            }
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

        public void request_controller_exit () {
            if (Utils.DownloadManager.instance.active_downloads.size > 0) {
                close ();
                return;
            }

            var dialog = new Adw.AlertDialog (_("Do you want to exit?"), "");
            dialog.add_response ("cancel", _("Cancel"));
            dialog.add_response ("exit", _("Exit"));
            dialog.set_response_appearance ("exit", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");
            dialog.response.connect ((response) => {
                if (response != "exit")
                    return;
                close ();
            });
            present_controller_dialog (dialog);
        }

        static void prepare_alert_dialog_focus (Adw.AlertDialog dialog) {
            disable_alert_heading_focus (dialog, dialog.get_heading ());
            update_alert_scroll_focus (dialog);

            Gtk.Widget? focus = dialog.get_default_widget ();
            var default_response = dialog.get_default_response ();
            if (focus == null && default_response != null) {
                focus = find_button_with_label (
                    dialog, dialog.get_response_label ((!) default_response)
                );
            }
            if (focus == null)
                return;

            ((!) focus).set_focusable (true);
            dialog.set_focus (focus);
            if (dialog.get_mapped ())
                ((!) focus).grab_focus ();
        }

        static void disable_alert_heading_focus (Gtk.Widget root, string? heading) {
            var child = root.get_first_child ();
            while (child != null) {
                var label = child as Gtk.Label;
                if (label != null && heading != null && label.get_label () == heading) {
                    label.set_selectable (false);
                    label.set_focusable (false);
                }
                disable_alert_heading_focus (child, heading);
                child = child.get_next_sibling ();
            }
        }

        static void update_alert_scroll_focus (Gtk.Widget root) {
            var child = root.get_first_child ();
            while (child != null) {
                var scrolled = child as Gtk.ScrolledWindow;
                if (scrolled != null && scrolled.has_css_class ("body-scrolled-window")) {
                    var adjustment = scrolled.get_vadjustment ();
                    scrolled.set_focusable (
                        Utils.ControllerSurfacePolicy.scroll_container_needs_focus (
                            adjustment.get_upper (), adjustment.get_page_size ()
                        )
                    );
                }
                update_alert_scroll_focus (child);
                child = child.get_next_sibling ();
            }
        }

        static Gtk.Widget? find_button_with_label (Gtk.Widget root, string label) {
            var child = root.get_first_child ();
            while (child != null) {
                var button = child as Gtk.Button;
                if (button != null && button.get_label () == label)
                    return button;
                var nested = find_button_with_label (child, label);
                if (nested != null)
                    return nested;
                child = child.get_next_sibling ();
            }
            return null;
        }

        private void build_ui () {
            if (header_presentation_handler != 0) {
                main_box.disconnect (header_presentation_handler);
                header_presentation_handler = 0;
            }
            if (search_availability_handler != 0) {
                main_box.disconnect (search_availability_handler);
                search_availability_handler = 0;
            }
            navigation_breakpoint_added = false;
            main_content_visible = false;
            search_action.set_enabled (false);
            header_box = new Header.Box ();
            header_box.set_controller_mode_active (
                controller_manager.presentation_state.controller_mode_active
            );
            header_box.launcher_selected.connect ((launcher) => {
                main_box.set_selected_launcher (launcher);
            });

            loading_box = new Loading.Box ();
            loading_box.loaded.connect ((launchers) => {
                this.launchers = launchers;

                header_box.initialize (
                    launchers,
                    navigation_breakpoint_added ? null : main_box.view_switcher
                );
                main_box.initialize (launchers);
                toolbar_view.set_content (main_box);
                main_content_visible = true;
                search_action.set_enabled (main_box.search_available ());
                main_box.view_switcher_bar.set_visible (true);
                add_navigation_breakpoint ();

                if (Globals.SETTINGS.get_boolean ("check-updates-on-launch")) {
                    main_box.check_for_updates.begin (launchers);
                }
            });

            main_box = new Main.Box (restart_manager, restart_orchestrator);
            main_box.view_switcher_bar.set_visible (false);
            header_presentation_handler = main_box.header_presentation_changed.connect (
                header_box.set_presentation
            );
            search_availability_handler = main_box.search_availability_changed.connect (
                (available) => search_action.set_enabled (
                    main_content_visible && available
                )
            );
            header_box.download_selected.connect ((job) => {
                header_box.select_launcher (job.tool.group.launcher);
                main_box.navigate_to_download (job);
            });

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_box);
            toolbar_view.add_bottom_bar (main_box.view_switcher_bar);
            controller_hint_bar = new ControllerHintBar ();
            controller_hint_bar.update_state (controller_manager.presentation_state);
            toolbar_view.add_bottom_bar (controller_hint_bar);
            toolbar_view.set_content (loading_box);

            responsive = new Adw.BreakpointBin ();
            responsive.set_size_request (
                MINIMUM_WINDOW_WIDTH, MINIMUM_WINDOW_HEIGHT
            );
            responsive.set_child (toolbar_view);
            set_content (responsive);
            controller_manager.presentation_context_changed ();

            loading_box.load.begin ();
        }

        void add_navigation_breakpoint () {
            if (navigation_breakpoint_added)
                return;

            var navigation_breakpoint = new Adw.Breakpoint (
                new Adw.BreakpointCondition.length (
                    Adw.BreakpointConditionLengthType.MAX_WIDTH,
                    NARROW_NAVIGATION_WIDTH,
                    Adw.LengthUnit.SP
                )
            );
            var narrow = Value (typeof (bool));
            narrow.set_boolean (true);
            navigation_breakpoint.add_setter (
                header_box, "narrow-navigation", narrow
            );
            navigation_breakpoint.add_setter (
                main_box, "narrow-navigation", narrow
            );

            responsive.add_breakpoint (navigation_breakpoint);
            navigation_breakpoint_added = true;
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
            main_content_visible = false;
            search_action.set_enabled (false);
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

        public override void dispose () {
            if (header_presentation_handler != 0) {
                main_box.disconnect (header_presentation_handler);
                header_presentation_handler = 0;
            }
            if (controller_presentation_handler != 0) {
                controller_manager.disconnect (controller_presentation_handler);
                controller_presentation_handler = 0;
            }
            controller_manager.stop ();
            base.dispose ();
        }
    }
}
