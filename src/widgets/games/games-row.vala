namespace ProtonPlus.Widgets.Games {
    public class GameRow : Gtk.ListBoxRow, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationRedirect {
        Gtk.GestureClick title_gesture;
        Gtk.GestureClick prefix_gesture;
        Gtk.CheckButton select_check_button;
        Gtk.Label title_label;
        Gtk.Label prefix_label;
        Gtk.Label tool_label;
        Gtk.Button tool_button;
        Gtk.Button launch_button;
        Gtk.Button run_custom_executable_button;
        ExtraButton extra_button;
        Gtk.Box other_box;
        Gtk.Box content_box;
        weak Gtk.Widget? controller_up_target;
        string normalized_name;
        public Models.Game game { get; set; }

        public signal void mass_edit_requested (GameRow row);

        public bool selected { get; set; }

        public GameRow (Models.Game game,
                        bool reserve_filter_column = false,
                        Gtk.SizeGroup? prefix_column_size_group = null,
                        Gtk.SizeGroup? tool_column_size_group = null,
                        Gtk.SizeGroup? actions_column_size_group = null,
                        Gtk.SizeGroup? filter_column_size_group = null,
                        Gtk.Widget? controller_up_target = null) {
            this.game = game;
            this.controller_up_target = controller_up_target;
            normalized_name = game.name.down ();

            select_check_button = new Gtk.CheckButton ();
            select_check_button.set_size_request (30, 0);
            select_check_button.bind_property ("active", this, "selected", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);

            title_label = new Gtk.Label (game.name);
            title_label.set_tooltip_text (title_label.get_label ());
            title_label.set_halign (Gtk.Align.START);
            title_label.set_hexpand (true);
            title_label.set_ellipsize (Pango.EllipsizeMode.END);

            title_gesture = new Gtk.GestureClick ();
            title_gesture.pressed.connect ((gesture, n_press, x, y) => {
                if (n_press == 1)
                    open_install_directory_button_clicked ();
            });

            prefix_label = new Gtk.Label (game.prefix.to_string ());
            prefix_label.set_xalign (0);
            prefix_label.set_max_width_chars (10);
            prefix_label.set_ellipsize (Pango.EllipsizeMode.END);
            prefix_label.set_size_request (110, 0);
            if (prefix_column_size_group != null)
                prefix_column_size_group.add_widget (prefix_label);

            prefix_gesture = new Gtk.GestureClick ();
            prefix_gesture.pressed.connect ((gesture, n_press, x, y) => {
                if (n_press == 1)
                    open_prefix_directory_button_clicked ();
            });

            tool_label = new Gtk.Label (null);
            tool_label.set_xalign (0.0f);
            tool_label.set_max_width_chars (30);
            tool_label.set_ellipsize (Pango.EllipsizeMode.END);
            tool_label.set_size_request (254, 0);
            if (tool_column_size_group != null)
                tool_column_size_group.add_widget (tool_label);
            refresh_tool_label ();

            extra_button = new ExtraButton (game);

            other_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            other_box.set_size_request (122, 0);
            if (actions_column_size_group != null)
                actions_column_size_group.add_widget (other_box);
            other_box.append (extra_button);

            content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            content_box.set_hexpand (true);
            content_box.set_margin_start (12);
            content_box.set_margin_end (12);
            content_box.set_margin_top (12);
            content_box.set_margin_bottom (12);
            content_box.set_valign (Gtk.Align.CENTER);
            content_box.append (select_check_button);
            content_box.append (title_label);
            if (reserve_filter_column) {
                // Keep the remaining row columns aligned with the header's
                // filter button, which occupies a column of its own.
                var filter_column_spacer = new Gtk.MenuButton () {
                    icon_name = "filter-2-symbolic",
                    sensitive = false,
                    focusable = false,
                    opacity = 0.0,
                    css_classes = { "flat" },
                };
                if (filter_column_size_group != null)
                    filter_column_size_group.add_widget (filter_column_spacer);
                content_box.append (filter_column_spacer);
            }
            content_box.append (prefix_label);
            content_box.append (tool_label);
            content_box.append (other_box);

            if (game is Models.Games.Steam)
                load_steam ((Models.Games.Steam) game);

            set_child (content_box);
            set_selectable (false);
        }

        public override bool focus (Gtk.DirectionType direction) {
            var root = get_root ();
            var focused = root?.get_focus ();
            if (focused == null ||
                (focused != this && !((!) focused).is_ancestor (this))) {
                if (direction == Gtk.DirectionType.UP ||
                    direction == Gtk.DirectionType.DOWN)
                    return grab_focus ();
                return base.focus (direction);
            }

            if (direction == Gtk.DirectionType.UP || direction == Gtk.DirectionType.DOWN)
                return focus_adjacent_game (direction);

            return base.focus (direction);
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;

            if (direction == Utils.ControllerNavigationDirection.UP &&
                find_adjacent_game (Gtk.DirectionType.UP) == null)
                return focus_controller_up_target ();

            if (direction == Utils.ControllerNavigationDirection.LEFT ||
                direction == Utils.ControllerNavigationDirection.RIGHT)
                return focus_horizontal ((!) focused, direction);

            return false;
        }

        public Object? get_controller_activation_target (Object focused_object) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null || find_action_ancestor ((!) focused) != null)
                return null;
            return select_check_button;
        }

        bool focus_horizontal (Gtk.Widget focused,
            Utils.ControllerNavigationDirection direction) {
            var action = find_action_ancestor (focused);

            if (direction == Utils.ControllerNavigationDirection.RIGHT) {
                if (action == null)
                    return focus_first_action ();
                return focus_action_sibling ((!) action, true);
            } else {
                if (action == null)
                    return select_check_button.grab_focus ();
                var previous = find_focusable_action ((!) action, false);
                return previous != null
                    ? ((!) previous).grab_focus ()
                    : grab_focus ();
            }
        }

        bool focus_adjacent_game (Gtk.DirectionType direction) {
            var adjacent = find_adjacent_game (direction);
            if (adjacent != null)
                return ((!) adjacent).grab_focus ();
            if (direction == Gtk.DirectionType.UP)
                return focus_controller_up_target ();
            return false;
        }

        GameRow? find_adjacent_game (Gtk.DirectionType direction) {
            Gtk.Widget? sibling = direction == Gtk.DirectionType.UP
                ? get_prev_sibling () : get_next_sibling ();
            while (sibling != null) {
                if (sibling is GameRow && sibling.get_mapped () && sibling.is_visible () &&
                    sibling.get_child_visible () &&
                    sibling.is_sensitive () && sibling.get_focusable ())
                    return (GameRow) sibling;
                sibling = direction == Gtk.DirectionType.UP
                    ? sibling.get_prev_sibling ()
                    : sibling.get_next_sibling ();
            }
            return null;
        }

        bool focus_controller_up_target () {
            return controller_up_target != null &&
                ((!) controller_up_target).get_mapped () &&
                ((!) controller_up_target).is_visible () &&
                ((!) controller_up_target).is_sensitive () &&
                ((!) controller_up_target).grab_focus ();
        }

        bool focus_first_action () {
            var child = find_focusable_action (null, true);
            return child != null && ((!) child).grab_focus ();
        }

        bool focus_action_sibling (Gtk.Widget action, bool forward) {
            var sibling = find_focusable_action (action, forward);
            return sibling != null
                ? ((!) sibling).grab_focus ()
                : action.grab_focus ();
        }

        Gtk.Widget? find_focusable_action (Gtk.Widget? current, bool forward) {
            Gtk.Widget? child;
            if (current == null)
                child = forward ? other_box.get_first_child () : other_box.get_last_child ();
            else
                child = forward ? current.get_next_sibling () : current.get_prev_sibling ();

            while (child != null) {
                if (child.get_mapped () && child.is_visible () &&
                    child.is_sensitive () && child.get_focusable ())
                    return child;
                child = forward ? child.get_next_sibling () : child.get_prev_sibling ();
            }
            return null;
        }

        Gtk.Widget? find_action_ancestor (Gtk.Widget focused) {
            Gtk.Widget? current = focused;
            while (current != null && current != other_box) {
                if (current.get_parent () == other_box)
                    return current;
                current = current.get_parent ();
            }
            return null;
        }

        public bool matches_search (string query) {
            return normalized_name.contains (query);
        }

        void add_hover_underline (Gtk.Label label) {
            var motion = new Gtk.EventControllerMotion ();
            motion.enter.connect ((x, y) => {
                var list = new Pango.AttrList ();
                list.insert (Pango.attr_underline_new (Pango.Underline.SINGLE));
                label.attributes = list;
            });
            motion.leave.connect (() => {
                label.attributes = null;
            });
            label.add_controller (motion);
        }

        public void refresh_tool_label () {
            string tool_name = _("Default");

            if (game.compatibility_tool == "Default" && game.is_native) {
                tool_name = _("Native");
            } else {
                foreach (var tool in game.launcher.compatibility_tools) {
                    if (tool.internal_title == game.compatibility_tool) {
                        tool_name = tool.display_title;
                        break;
                    }
                }
            }

            tool_label.set_label (tool_name);
        }

        void load_steam (Models.Games.Steam game) {
            tool_button = new Gtk.Button.from_icon_name ("screwdriver-wrench-symbolic");
            tool_button.set_tooltip_text (_("Modify the game"));
            tool_button.add_css_class ("flat");
            tool_button.clicked.connect (() => mass_edit_requested (this));

            run_custom_executable_button = new Gtk.Button.from_icon_name ("rocket-symbolic");
            run_custom_executable_button.set_tooltip_text (_("Launch custom executable"));
            run_custom_executable_button.add_css_class ("flat");
            run_custom_executable_button.clicked.connect (run_custom_executable_button_clicked);
            run_custom_executable_button.set_sensitive (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR));


            launch_button = new Gtk.Button.from_icon_name ("play-fill");
            launch_button.set_tooltip_text (_("Launch game"));
            launch_button.add_css_class ("flat");
            launch_button.clicked.connect (launch_button_clicked);

            if (FileUtils.test (game.installdir, GLib.FileTest.IS_DIR)) {
                title_label.set_tooltip_text (_("Browse game install directory"));
                title_label.add_controller (title_gesture);
                add_hover_underline (title_label);
            }

            if (FileUtils.test (game.prefixdir, GLib.FileTest.IS_DIR)) {
                prefix_label.set_tooltip_text (_("Browse prefix directory"));
                prefix_label.add_controller (prefix_gesture);
                add_hover_underline (prefix_label);
            }

            other_box.prepend (launch_button);
            other_box.prepend (run_custom_executable_button);
            other_box.prepend (tool_button);
        }

        void open_install_directory_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (game.installdir));
        }

        void open_prefix_directory_button_clicked () {
            Utils.System.open_uri ("file://%s".printf (game.prefixdir));
        }

        void run_custom_executable_button_clicked () {
            var file_dialog = new Gtk.FileDialog ();
            file_dialog.set_title (_("Select executable"));

            var filters = new ListStore (typeof (Gtk.FileFilter));
            var filter = new Gtk.FileFilter ();
            filter.add_pattern ("*.exe");
            filter.add_pattern ("*.msi");
            filter.add_pattern ("*.msu");
            filter.add_pattern ("*.bat");
            filter.name = _("Executables (*.exe, *.msi, *.msu, *.bat)");
            filters.append (filter);

            file_dialog.set_filters (filters);

            file_dialog.open.begin ((Gtk.Window) this.get_root (), null, (obj, res) => {
                try {
                    var file = file_dialog.open.end (res);
                    if (file != null) {
                        run_custom_executable (file.get_path ());
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            });
        }

        void launch_button_clicked () {
            if (game is Models.Games.Steam) {
                var steam_game = (Models.Games.Steam) game;
                var uri = "steam://run/" + steam_game.appid.to_string ();
                Utils.System.open_uri (uri);
            }
        }

        void run_custom_executable (string exe_path) {
            var steam = game.launcher as Models.Launchers.Steam;
            var proton_path = steam?.resolve_effective_proton_executable (game.compatibility_tool);
            if (proton_path == null) {
                var dialog = new Main.ErrorDialog (
                    _("Compatibility Tool Not Found"),
                    _("The compatibility tool required for %s is missing from your system. Please ensure it is correctly installed.").printf (game.name),
                    ""
                );
                present_error_dialog (dialog);
                return;
            }

            var steam_compat_data_path = game.prefixdir;
            var steam_compat_client_install_path = game.launcher.directory;

            var inner_command = "STEAM_COMPAT_DATA_PATH=%s STEAM_COMPAT_CLIENT_INSTALL_PATH=%s %s run %s".printf (
                Shell.quote (steam_compat_data_path),
                Shell.quote (steam_compat_client_install_path),
                Shell.quote (proton_path),
                Shell.quote (exe_path)
            );

            Utils.System.run_command.begin ("sh -c " + Shell.quote (inner_command), (obj, res) => {
                var result = Utils.System.run_command.end (res);
                if (result.exit_status == 0)
                    return;

                var diagnostic = result.stderr.strip ();
                if (diagnostic == "")
                    diagnostic = result.stdout.strip ();

                var details = _("Exit status: %d").printf (result.exit_status);
                if (diagnostic != "")
                    details = "%s\n\n%s".printf (details, diagnostic);

                var dialog = new Main.ErrorDialog (
                    _("Custom Executable Failed"),
                    _("The custom executable for %s could not be launched.").printf (game.name),
                    details
                );
                present_error_dialog (dialog);
            });
        }

        void present_error_dialog (Adw.AlertDialog dialog) {
            var root = this.get_root () as Gtk.Window;
            if (root == null)
                return;
            ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (!) root);
        }
    }
}
