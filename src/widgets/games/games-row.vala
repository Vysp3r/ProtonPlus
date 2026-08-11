namespace ProtonPlus.Widgets.Games {
    public delegate bool GameVerticalFocusRequest (GameListItem item, int delta);
    public delegate bool GamePeerFocusRequest (GameListItem item);
    public delegate void GameModifyRequest (GameListItem item);

    public enum GameTextCellKind {
        TITLE,
        PREFIX,
        TOOL
    }

    public class GameSelectionCell : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationRedirect {
        Gtk.CheckButton check_button;
        Binding? selected_binding;
        GameListItem? item;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GamePeerFocusRequest actions_focus;

        public GameSelectionCell (GameVerticalFocusRequest vertical_focus,
            GamePeerFocusRequest actions_focus) {
            Object (orientation: Gtk.Orientation.HORIZONTAL);
            this.vertical_focus = vertical_focus;
            this.actions_focus = actions_focus;

            set_focusable (true);
            set_halign (Gtk.Align.CENTER);
            set_valign (Gtk.Align.CENTER);
            check_button = new Gtk.CheckButton () {
                tooltip_text = _("Select game")
            };
            append (check_button);
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            selected_binding = item.bind_property (
                "selected", check_button, "active",
                BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
            );
        }

        public void unbind () {
            selected_binding?.unbind ();
            selected_binding = null;
            item = null;
            check_button.set_active (false);
        }

        public GameListItem? get_item () {
            return item;
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            if (item == null)
                return false;
            if (direction == Utils.ControllerNavigationDirection.UP)
                return vertical_focus ((!) item, -1);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1);
            if (direction == Utils.ControllerNavigationDirection.RIGHT)
                return actions_focus ((!) item);
            if (direction == Utils.ControllerNavigationDirection.LEFT)
                return check_button.grab_focus ();
            return false;
        }

        public Object? get_controller_activation_target (Object focused_object) {
            return check_button;
        }
    }

    public class GameTextCell : Gtk.Box {
        Gtk.Label label;
        Gtk.GestureClick gesture;
        Gtk.EventControllerMotion motion;
        GameTextCellKind kind;
        GameListItem? item;
        ulong tool_title_handler = 0;

        public GameTextCell (GameTextCellKind kind) {
            Object (orientation: Gtk.Orientation.HORIZONTAL);
            this.kind = kind;
            set_margin_start (6);
            set_margin_end (6);
            set_valign (Gtk.Align.CENTER);

            label = new Gtk.Label (null) {
                xalign = 0,
                halign = Gtk.Align.FILL,
                hexpand = true,
                ellipsize = Pango.EllipsizeMode.END
            };
            append (label);

            gesture = new Gtk.GestureClick ();
            gesture.pressed.connect ((gesture, n_press, x, y) => {
                if (n_press == 1)
                    open_directory ();
            });
            label.add_controller (gesture);

            motion = new Gtk.EventControllerMotion ();
            motion.enter.connect ((x, y) => set_underlined (can_open_directory ()));
            motion.leave.connect (() => set_underlined (false));
            label.add_controller (motion);
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            if (kind == GameTextCellKind.TOOL) {
                tool_title_handler = item.notify["tool-title"].connect (refresh);
            }
            refresh ();
        }

        public void unbind () {
            if (tool_title_handler != 0 && item != null) {
                ((!) item).disconnect (tool_title_handler);
                tool_title_handler = 0;
            }
            item = null;
            label.set_label ("");
            label.set_tooltip_text (null);
            set_underlined (false);
        }

        void refresh () {
            if (item == null)
                return;
            switch (kind) {
            case GameTextCellKind.TITLE:
                label.set_label (((!) item).game.name);
                label.set_tooltip_text (((!) item).has_install_directory
                    ? _("Browse game install directory") : ((!) item).game.name);
                break;
            case GameTextCellKind.PREFIX:
                label.set_label (((!) item).game.prefix.to_string ());
                label.set_tooltip_text (((!) item).has_prefix_directory
                    ? _("Browse prefix directory") : null);
                break;
            case GameTextCellKind.TOOL:
                label.set_label (((!) item).tool_title);
                label.set_tooltip_text (((!) item).tool_title);
                break;
            }
        }

        bool can_open_directory () {
            return item != null && ((kind == GameTextCellKind.TITLE
                && ((!) item).has_install_directory) ||
                (kind == GameTextCellKind.PREFIX && ((!) item).has_prefix_directory));
        }

        void open_directory () {
            if (!can_open_directory ())
                return;
            if (kind == GameTextCellKind.TITLE)
                Utils.System.open_path (((!) item).game.installdir);
            else
                Utils.System.open_path (((!) item).game.prefixdir);
        }

        void set_underlined (bool underlined) {
            if (!underlined) {
                label.attributes = null;
                return;
            }
            var attributes = new Pango.AttrList ();
            attributes.insert (Pango.attr_underline_new (Pango.Underline.SINGLE));
            label.attributes = attributes;
        }
    }

    public class GameActions : Gtk.Box, Utils.ControllerDirectionalFocus {
        Gtk.Button modify_button;
        Gtk.Button custom_executable_button;
        Gtk.Button launch_button;
        ExtraButton extra_button;
        GameListItem? item;
        unowned GameModifyRequest modify_request;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GamePeerFocusRequest selection_focus;

        public GameActions (GameModifyRequest modify_request,
            GameVerticalFocusRequest vertical_focus,
            GamePeerFocusRequest selection_focus) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
            this.modify_request = modify_request;
            this.vertical_focus = vertical_focus;
            this.selection_focus = selection_focus;
            set_halign (Gtk.Align.START);
            set_valign (Gtk.Align.CENTER);

            modify_button = new Gtk.Button.from_icon_name ("screwdriver-wrench-symbolic") {
                tooltip_text = _("Modify the game"),
                css_classes = { "flat" }
            };
            modify_button.clicked.connect (() => {
                if (item != null)
                    modify_request ((!) item);
            });

            custom_executable_button = new Gtk.Button.from_icon_name ("rocket-symbolic") {
                tooltip_text = _("Launch custom executable"),
                css_classes = { "flat" }
            };
            custom_executable_button.clicked.connect (open_custom_executable);

            launch_button = new Gtk.Button.from_icon_name ("play-fill") {
                tooltip_text = _("Launch game"),
                css_classes = { "flat" }
            };
            launch_button.clicked.connect (() => {
                var steam_game = item?.game as Models.Games.Steam;
                if (steam_game != null)
                    Utils.System.open_uri ("steam://run/" + ((!) steam_game).appid.to_string ());
            });

            extra_button = new ExtraButton ();
            append (modify_button);
            append (custom_executable_button);
            append (launch_button);
            append (extra_button);
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            var is_steam = item.game is Models.Games.Steam;
            modify_button.set_visible (is_steam);
            custom_executable_button.set_visible (is_steam);
            custom_executable_button.set_sensitive (item.has_prefix_directory);
            launch_button.set_visible (is_steam);
            extra_button.bind (item);
        }

        public void unbind () {
            item = null;
            extra_button.unbind ();
            modify_button.set_visible (false);
            custom_executable_button.set_visible (false);
            launch_button.set_visible (false);
        }

        public GameListItem? get_item () {
            return item;
        }

        public bool focus_first_action () {
            return focus_action (null, true);
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            if (item == null)
                return false;
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;
            if (direction == Utils.ControllerNavigationDirection.UP)
                return vertical_focus ((!) item, -1);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1);
            if (direction == Utils.ControllerNavigationDirection.RIGHT) {
                if (focus_action ((!) focused, true))
                    return true;
                return ((!) focused).grab_focus ();
            }
            if (direction == Utils.ControllerNavigationDirection.LEFT) {
                if (focus_action ((!) focused, false))
                    return true;
                return selection_focus ((!) item);
            }
            return false;
        }

        bool focus_action (Gtk.Widget? focused, bool forward) {
            Gtk.Widget? action = find_action_ancestor (focused);
            Gtk.Widget? candidate = action == null
                ? (forward ? get_first_child () : get_last_child ())
                : (forward ? action.get_next_sibling () : action.get_prev_sibling ());
            while (candidate != null) {
                if (candidate.get_mapped () && candidate.is_visible () &&
                    candidate.is_sensitive () && candidate.get_focusable ())
                    return candidate.grab_focus ();
                candidate = forward
                    ? candidate.get_next_sibling () : candidate.get_prev_sibling ();
            }
            return false;
        }

        Gtk.Widget? find_action_ancestor (Gtk.Widget? focused) {
            var current = focused;
            while (current != null && current != this) {
                if (current.get_parent () == this)
                    return current;
                current = current.get_parent ();
            }
            return null;
        }

        void open_custom_executable () {
            if (item == null)
                return;
            var expected = (!) item;
            var root = get_root () as Gtk.Window;
            if (root == null)
                return;

            var file_dialog = new Gtk.FileDialog () {
                title = _("Select executable")
            };
            var filters = new ListStore (typeof (Gtk.FileFilter));
            var filter = new Gtk.FileFilter () {
                name = _("Executables (*.exe, *.msi, *.msu, *.bat)")
            };
            filter.add_pattern ("*.exe");
            filter.add_pattern ("*.msi");
            filter.add_pattern ("*.msu");
            filter.add_pattern ("*.bat");
            filters.append (filter);
            file_dialog.set_filters (filters);

            file_dialog.open.begin ((!) root, null, (object, result) => {
                try {
                    var file = file_dialog.open.end (result);
                    var path = file?.get_path ();
                    if (path != null)
                        run_custom_executable (expected, (!) path, (!) root);
                } catch (Error error) {
                    warning (error.message);
                }
            });
        }

        static void run_custom_executable (GameListItem expected, string exe_path,
            Gtk.Window root) {
            var game = expected.game;
            var steam = game.launcher as Models.Launchers.Steam;
            var proton_path = steam?.resolve_effective_proton_executable (
                game.compatibility_tool
            );
            if (proton_path == null) {
                present_error_dialog (root, new Main.ErrorDialog (
                    _("Compatibility Tool Not Found"),
                    _("The compatibility tool required for %s is missing from your system. Please ensure it is correctly installed.").printf (game.name), // vala-lint=line-length
                    ""
                ));
                return;
            }

            var inner_command = "STEAM_COMPAT_DATA_PATH=%s STEAM_COMPAT_CLIENT_INSTALL_PATH=%s %s run %s".printf (
                Shell.quote (game.prefixdir), Shell.quote (game.launcher.directory),
                Shell.quote ((!) proton_path), Shell.quote (exe_path)
            );
            Utils.System.run_command.begin ("sh -c " + Shell.quote (inner_command),
                (object, result) => {
                    var command_result = Utils.System.run_command.end (result);
                    if (command_result.exit_status == 0)
                        return;
                    var diagnostic = command_result.stderr.strip ();
                    if (diagnostic == "")
                        diagnostic = command_result.stdout.strip ();
                    var details = _("Exit status: %d").printf (command_result.exit_status);
                    if (diagnostic != "")
                        details = "%s\n\n%s".printf (details, diagnostic);
                    present_error_dialog (root, new Main.ErrorDialog (
                        _("Custom Executable Failed"),
                        _("The custom executable for %s could not be launched.").printf (game.name),
                        details
                    ));
                });
        }

        static void present_error_dialog (Gtk.Window root, Adw.AlertDialog dialog) {
            if (root.get_root () == null)
                return;
            Window.present_dialog_for_controller (dialog, root);
        }
    }

    public class GameRow : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationRedirect {
        Gtk.CheckButton select_check_button;
        Gtk.Label title_label;
        Gtk.Label tool_label;
        Gtk.Label prefix_label;
        GameActions actions;
        Gtk.GestureClick title_gesture;
        Gtk.GestureClick prefix_gesture;
        Gtk.EventControllerMotion title_motion;
        Gtk.EventControllerMotion prefix_motion;
        Binding? selected_binding;
        GameListItem? item;
        ulong tool_title_handler = 0;
        unowned GameVerticalFocusRequest vertical_focus;

        public GameRow (GameModifyRequest modify_request,
            GameVerticalFocusRequest vertical_focus) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 4);
            this.vertical_focus = vertical_focus;
            set_focusable (true);
            set_hexpand (true);
            set_margin_top (10);
            set_margin_bottom (10);
            set_margin_start (12);
            set_margin_end (12);

            select_check_button = new Gtk.CheckButton () {
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Select game")
            };
            title_label = compact_label (true);
            title_label.add_css_class ("heading");
            tool_label = compact_label (true);
            prefix_label = compact_label (false);
            prefix_label.add_css_class ("dim-label");

            title_gesture = new Gtk.GestureClick ();
            title_gesture.pressed.connect ((gesture, n_press, x, y) => {
                if (n_press == 1 && item != null && ((!) item).has_install_directory)
                    Utils.System.open_path (((!) item).game.installdir);
            });
            title_label.add_controller (title_gesture);
            title_motion = new Gtk.EventControllerMotion ();
            title_motion.enter.connect ((x, y) => {
                set_label_underlined (
                    title_label, item != null && ((!) item).has_install_directory
                );
            });
            title_motion.leave.connect (() => set_label_underlined (title_label, false));
            title_label.add_controller (title_motion);

            prefix_gesture = new Gtk.GestureClick ();
            prefix_gesture.pressed.connect ((gesture, n_press, x, y) => {
                if (n_press == 1 && item != null && ((!) item).has_prefix_directory)
                    Utils.System.open_path (((!) item).game.prefixdir);
            });
            prefix_label.add_controller (prefix_gesture);
            prefix_motion = new Gtk.EventControllerMotion ();
            prefix_motion.enter.connect ((x, y) => {
                set_label_underlined (
                    prefix_label, item != null && ((!) item).has_prefix_directory
                );
            });
            prefix_motion.leave.connect (() => set_label_underlined (prefix_label, false));
            prefix_label.add_controller (prefix_motion);

            var title_line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            title_line.append (select_check_button);
            title_line.append (title_label);

            var details_line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            details_line.set_margin_start (30);
            details_line.append (tool_label);
            details_line.append (prefix_label);

            actions = new GameActions (
                modify_request, on_vertical_focus, focus_selection
            );
            actions.set_margin_start (30);

            append (title_line);
            append (details_line);
            append (actions);
        }

        static Gtk.Label compact_label (bool expand) {
            return new Gtk.Label (null) {
                xalign = 0,
                halign = Gtk.Align.FILL,
                hexpand = expand,
                ellipsize = Pango.EllipsizeMode.END
            };
        }

        static void set_label_underlined (Gtk.Label label, bool underlined) {
            if (!underlined) {
                label.attributes = null;
                return;
            }
            var attributes = new Pango.AttrList ();
            attributes.insert (Pango.attr_underline_new (Pango.Underline.SINGLE));
            label.attributes = attributes;
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            selected_binding = item.bind_property (
                "selected", select_check_button, "active",
                BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
            );
            tool_title_handler = item.notify["tool-title"].connect (refresh_tool_title);
            title_label.set_label (item.game.name);
            title_label.set_tooltip_text (item.game.name);
            prefix_label.set_label (item.game.prefix.to_string ());
            prefix_label.set_tooltip_text (item.has_prefix_directory
                ? _("Browse prefix directory") : null);
            refresh_tool_title ();
            actions.bind (item);
        }

        public void unbind () {
            selected_binding?.unbind ();
            selected_binding = null;
            if (tool_title_handler != 0 && item != null) {
                ((!) item).disconnect (tool_title_handler);
                tool_title_handler = 0;
            }
            actions.unbind ();
            item = null;
            title_label.set_label ("");
            tool_label.set_label ("");
            prefix_label.set_label ("");
            select_check_button.set_active (false);
            set_label_underlined (title_label, false);
            set_label_underlined (prefix_label, false);
        }

        public GameListItem? get_item () {
            return item;
        }

        void refresh_tool_title () {
            if (item == null)
                return;
            tool_label.set_label (((!) item).tool_title);
            tool_label.set_tooltip_text (((!) item).tool_title);
        }

        public bool focus_first_action () {
            return actions.focus_first_action ();
        }

        bool on_vertical_focus (GameListItem item, int delta) {
            return vertical_focus (item, delta);
        }

        bool focus_selection (GameListItem item) {
            return select_check_button.grab_focus ();
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            if (item == null)
                return false;
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;
            if (direction == Utils.ControllerNavigationDirection.UP)
                return vertical_focus ((!) item, -1);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1);
            if (direction == Utils.ControllerNavigationDirection.RIGHT)
                return actions.focus_first_action ();
            if (direction == Utils.ControllerNavigationDirection.LEFT)
                return select_check_button.grab_focus ();
            return false;
        }

        public Object? get_controller_activation_target (Object focused_object) {
            var focused = focused_object as Gtk.Widget;
            if (focused != null && ((!) focused).is_ancestor (actions))
                return null;
            return select_check_button;
        }
    }
}
