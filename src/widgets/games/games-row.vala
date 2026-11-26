namespace ProtonPlus.Widgets.Games {
    public delegate bool GameVerticalFocusRequest (
        GameListItem item, int delta, GameFocusLane lane
    );
    public delegate bool GamePeerFocusRequest (GameListItem item);
    public delegate void GameActivationRequest (GameListItem item);

    public class GameSelectionCell : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        Gtk.CheckButton check_button;
        Gtk.Image navigation_image;
        Binding? selected_binding;
        GameListItem? item;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GamePeerFocusRequest row_focus;

        public GameSelectionCell (GameVerticalFocusRequest vertical_focus,
            GamePeerFocusRequest row_focus) {
            Object (orientation: Gtk.Orientation.HORIZONTAL);
            this.vertical_focus = vertical_focus;
            this.row_focus = row_focus;

            set_focusable (true);
            set_halign (Gtk.Align.START);
            set_valign (Gtk.Align.CENTER);
            set_margin_start (9);
            set_margin_top (4);
            set_margin_bottom (4);
            check_button = new Gtk.CheckButton () {
                tooltip_text = _("Select game"),
                focusable = false
            };
            check_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Select game"), -1
            );
            append (check_button);
            navigation_image = new Gtk.Image.from_icon_name ("go-next-symbolic") {
                tooltip_text = _("Modify Game")
            };
            append (navigation_image);
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            selected_binding = item.bind_property (
                "selected", check_button, "active",
                BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
            );
            check_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Select %s").printf (item.game.name),
                -1
            );
            var bulk = item.game.launcher.supports_bulk_game_edit;
            check_button.set_visible (bulk);
            navigation_image.set_visible (item.game.can_edit_compatibility_tool);
            set_focusable (bulk);
            update_accessibility ();
        }

        public void unbind () {
            selected_binding?.unbind ();
            selected_binding = null;
            item = null;
            check_button.set_active (false);
            check_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Select game"), -1
            );
            reset_property (Gtk.AccessibleProperty.LABEL);
            reset_property (Gtk.AccessibleProperty.DESCRIPTION);
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
                return vertical_focus ((!) item, -1, GameFocusLane.SELECTION);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1, GameFocusLane.SELECTION);
            if (direction == Utils.ControllerNavigationDirection.RIGHT)
                return row_focus ((!) item);
            if (direction == Utils.ControllerNavigationDirection.LEFT)
                return grab_focus ();
            return false;
        }

        public void set_selection_mode (bool selection_mode) {
            navigation_image.set_opacity (selection_mode ? 0.0 : 1.0);
            navigation_image.set_can_target (!selection_mode);
        }

        public bool controller_activate (Object focused) {
            if (item == null)
                return false;
            if (!item.game.launcher.supports_bulk_game_edit)
                return false;
            ((!) item).selected = !((!) item).selected;
            return true;
        }

        void update_accessibility () {
            if (item == null)
                return;
            update_property (
                Gtk.AccessibleProperty.LABEL, ((!) item).game.name,
                Gtk.AccessibleProperty.DESCRIPTION,
                _("Toggle selection for %s").printf (((!) item).game.name),
                -1
            );
        }
    }

    public class GameTitleCell : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        Gtk.Label label;
        Gtk.Label context_label;
        GameListItem? item;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GamePeerFocusRequest selection_focus;
        unowned GamePeerFocusRequest actions_focus;
        unowned GameActivationRequest activation_request;

        public GameTitleCell (GameVerticalFocusRequest vertical_focus,
            GamePeerFocusRequest selection_focus,
            GamePeerFocusRequest actions_focus,
            GameActivationRequest activation_request) {
            Object (orientation: Gtk.Orientation.VERTICAL);
            this.vertical_focus = vertical_focus;
            this.selection_focus = selection_focus;
            this.actions_focus = actions_focus;
            this.activation_request = activation_request;
            set_focusable (true);
            // ColumnView supplies matching padding for headers and cells.
            set_valign (Gtk.Align.CENTER);

            label = new Gtk.Label (null) {
                xalign = 0,
                halign = Gtk.Align.FILL,
                hexpand = true,
                ellipsize = Pango.EllipsizeMode.END
            };
            append (label);
            context_label = new Gtk.Label (null) {
                xalign = 0,
                ellipsize = Pango.EllipsizeMode.END,
                css_classes = { "dim-label" },
                visible = false
            };
            append (context_label);
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            label.set_label (item.game.name);
            label.set_tooltip_text (item.display_name);
            var context = item.game.library_context;
            context_label.set_label (context ?? "");
            context_label.set_tooltip_text (context);
            context_label.set_visible (context != null);
            update_property (
                Gtk.AccessibleProperty.LABEL, item.display_name,
                Gtk.AccessibleProperty.DESCRIPTION,
                item.game.can_edit_compatibility_tool ? _("Modify %s").printf (item.game.name) : "",
                -1
            );
        }

        public void unbind () {
            item = null;
            label.set_label ("");
            label.set_tooltip_text (null);
            context_label.set_visible (false);
            reset_property (Gtk.AccessibleProperty.LABEL);
            reset_property (Gtk.AccessibleProperty.DESCRIPTION);
        }

        public GameListItem? get_item () {
            return item;
        }

        public void set_selection_mode (bool selection_mode) {
            set_focusable (!selection_mode);
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            if (item == null)
                return false;
            if (direction == Utils.ControllerNavigationDirection.UP)
                return vertical_focus ((!) item, -1, GameFocusLane.ROW);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1, GameFocusLane.ROW);
            if (direction == Utils.ControllerNavigationDirection.LEFT)
                return selection_focus ((!) item);
            if (direction == Utils.ControllerNavigationDirection.RIGHT)
                return actions_focus ((!) item);
            return false;
        }

        public bool controller_activate (Object focused) {
            if (item == null || !item.game.can_edit_compatibility_tool)
                return false;
            activation_request ((!) item);
            return true;
        }
    }

    public class GameCompatibilityCell : Gtk.Box {
        Gtk.Label label;
        GameListItem? item;
        ulong tool_title_handler = 0;

        public GameCompatibilityCell () {
            Object (orientation: Gtk.Orientation.HORIZONTAL, valign: Gtk.Align.CENTER);
            label = new Gtk.Label (null) {
                xalign = 0,
                hexpand = true,
                ellipsize = Pango.EllipsizeMode.END
            };
            append (label);

            // Lists activate on click. Consume clicks in this cell in browse
            // mode, while leaving bulk selection and scrolling to the list.
            var click = new Gtk.GestureClick () { button = Gdk.BUTTON_PRIMARY };
            click.released.connect (() => {
                var view = get_ancestor (typeof (GameListView)) as GameListView;
                if (view != null && !view.selection_mode_active)
                    click.set_state (Gtk.EventSequenceState.CLAIMED);
            });
            add_controller (click);
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            tool_title_handler = item.notify["tool-title"].connect (refresh);
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
        }

        void refresh () {
            if (item == null)
                return;
            label.set_label (((!) item).tool_title);
            label.set_tooltip_text (((!) item).tool_title);
        }
    }

    public class GameActions : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        Gtk.Button launch_button;
        ExtraButton extra_button;
        GameActionTarget target;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GamePeerFocusRequest selection_focus;
        bool selection_mode = false;

        public GameActions (GameVerticalFocusRequest vertical_focus,
            GamePeerFocusRequest selection_focus) {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
            this.vertical_focus = vertical_focus;
            this.selection_focus = selection_focus;
            set_halign (Gtk.Align.START);
            set_valign (Gtk.Align.CENTER);

            target = new GameActionTarget ();
            launch_button = new Gtk.Button.from_icon_name (
                "media-playback-start-symbolic"
            ) {
                css_classes = { "flat" }
            };
            launch_button.clicked.connect (() => launch_game.begin ());

            extra_button = new ExtraButton (target);
            append (launch_button);
            append (extra_button.button);
        }

        public void bind (GameListItem item) {
            unbind ();
            target.bind (item);
            var steam_game = item.game as Models.Games.Steam;
            var availability = GameActionAvailability.evaluate (
                steam_game != null,
                item.is_non_steam,
                item.is_native,
                item.has_install_directory,
                item.has_prefix_directory,
                Globals.PROTONTRICKS_INSTALLED ||
                    Globals.PROTONTRICKS_FLATPAK_INSTALLED,
                steam_game?.awacy_status,
                steam_game?.awacy_name != null,
                steam_game?.awacy_lookup_complete ?? false,
                item.game.can_launch
            );
            launch_button.set_visible (availability.show_launch);
            launch_button.set_tooltip_text (_("Launch %s").printf (item.display_name));
            launch_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Launch %s").printf (item.display_name),
                -1
            );
            extra_button.bind (item);
            refresh_visibility ();
        }

        async void launch_game () {
            var generation = target.generation;
            var item = target.item;
            if (item == null)
                return;
            var game = item.game;
            var root = get_root () as Gtk.Window;
            var steam_game = game as Models.Games.Steam;
            var autogen_game = game as Models.Games.ProtonAutogen;
            try {
                if (steam_game != null) {
                    var steam_target = steam_game.launcher.get_steam_restart_target ();
                    if (steam_target == null)
                        throw new IOError.NOT_FOUND ("No Steam installation was found for this game.");
                    new Services.SteamGameLaunchService ().launch (
                        steam_target, steam_game.appid, steam_game.is_non_steam, Globals.IS_FLATPAK);
                } else if (autogen_game != null && autogen_game.can_launch) {
                    var process = Services.ProtonAutogenGameLaunchService.launch (
                        autogen_game.executable_path, Globals.IS_FLATPAK);
                    if (root != null)
                        observe_autogen_exit (process, root, game.name);
                } else if (game.can_launch) {
                    var process = yield game.launch_external ();
                    if (process != null)
                        yield process.wait_check_async ();
                }
            } catch (Error error) {
                if (root != null && generation == target.generation && root.get_mapped ())
                    Window.present_dialog_for_controller (new Main.ErrorDialog (
                        _("Game Launch Failed"),
                        _("%s could not be launched.").printf (item.display_name),
                        error.message), root);
            }
        }

        static void observe_autogen_exit (Subprocess process, Gtk.Window root, string game_name) {
            var window_ref = WeakRef (root);
            process.wait_check_async.begin (null, (source, result) => {
                try {
                    process.wait_check_async.end (result);
                } catch (Error error) {
                    var window = window_ref.get () as Gtk.Window;
                    if (window != null && window.get_mapped ())
                        Window.present_dialog_for_controller (new Main.ErrorDialog (
                            "Proton-Autogen",
                            _("The Proton-Autogen command failed for %s.").printf (game_name),
                            error.message), window);
                }
            });
        }

        public void unbind () {
            extra_button.unbind ();
            launch_button.set_visible (false);
            launch_button.reset_property (Gtk.AccessibleProperty.LABEL);
            target.unbind ();
            set_visible (false);
        }

        public GameListItem? get_item () {
            return target.item;
        }

        public void set_selection_mode (bool selection_mode) {
            this.selection_mode = selection_mode;
            refresh_visibility ();
        }

        public bool focus_first_action () {
            return focus_action (null, true);
        }

        public bool focus_lane (GameFocusLane lane) {
            if (lane == GameFocusLane.FIRST_ACTION)
                return focus_first_action ();
            if (lane == GameFocusLane.PRIMARY_ACTION)
                return focus_candidate (launch_button);
            if (lane == GameFocusLane.SECONDARY_ACTION)
                return focus_candidate (extra_button.button);
            return false;
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            if (target.item == null)
                return false;
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;
            var action = find_action_ancestor ((!) focused);
            var lane = GameControllerNavigationPolicy.action_lane (
                action == extra_button.button
            );
            if (direction == Utils.ControllerNavigationDirection.UP)
                return vertical_focus ((!) target.item, -1, lane);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) target.item, 1, lane);
            if (direction == Utils.ControllerNavigationDirection.RIGHT) {
                if (focus_action ((!) focused, true))
                    return true;
                return ((!) focused).grab_focus ();
            }
            if (direction == Utils.ControllerNavigationDirection.LEFT) {
                if (focus_action ((!) focused, false))
                    return true;
                return selection_focus ((!) target.item);
            }
            return false;
        }

        public bool controller_activate (Object focused_object) {
            if (target.item == null)
                return false;
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;
            var action = find_action_ancestor ((!) focused);
            if (action == launch_button) {
                launch_button.activate ();
                return true;
            }
            if (action == extra_button.button) {
                extra_button.button.popup ();
                return true;
            }
            return false;
        }

        bool focus_candidate (Gtk.Widget candidate) {
            return GameControllerNavigationPolicy.can_attempt_action_focus (
                candidate.get_mapped (), candidate.is_visible (),
                candidate.is_sensitive ()
            ) && candidate.grab_focus ();
        }

        bool focus_action (Gtk.Widget? focused, bool forward) {
            Gtk.Widget? action = find_action_ancestor (focused);
            Gtk.Widget? candidate = action == null
                ? (forward ? get_first_child () : get_last_child ())
                : (forward ? action.get_next_sibling () : action.get_prev_sibling ());
            while (candidate != null) {
                if (focus_candidate (candidate))
                    return true;
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

        void refresh_visibility () {
            set_visible (!selection_mode && target.item != null &&
                (launch_button.get_visible () || extra_button.button.get_visible ()));
        }
    }

    public class GameRow : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        Gtk.CheckButton select_check_button;
        Gtk.Label title_label;
        Gtk.Label context_label;
        GameCompatibilityCell compatibility;
        GameActions actions;
        Gtk.Image navigation_image;
        Binding? selected_binding;
        GameListItem? item;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GameActivationRequest activation_request;

        public GameRow (GameVerticalFocusRequest vertical_focus,
            GameActivationRequest activation_request) {
            Object (orientation: Gtk.Orientation.VERTICAL);
            this.vertical_focus = vertical_focus;
            this.activation_request = activation_request;
            set_focusable (true);
            set_hexpand (true);
            set_margin_top (10);
            set_margin_bottom (10);
            set_margin_start (12);
            set_margin_end (12);

            select_check_button = new Gtk.CheckButton () {
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Select game"),
                focusable = false
            };
            select_check_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Select game"), -1
            );
            title_label = compact_label ();
            title_label.add_css_class ("heading");
            title_label.set_wrap (true);
            title_label.set_wrap_mode (Pango.WrapMode.WORD_CHAR);
            title_label.set_lines (2);
            context_label = compact_label ();
            context_label.add_css_class ("dim-label");
            context_label.set_visible (false);
            compatibility = new GameCompatibilityCell () { hexpand = true };

            navigation_image = new Gtk.Image.from_icon_name ("go-next-symbolic") {
                tooltip_text = _("Modify Game")
            };
            var title_line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            title_line.append (title_label);
            title_line.append (navigation_image);

            actions = new GameActions (vertical_focus, focus_selection);

            var content = new Gtk.Grid () { column_spacing = 8, row_spacing = 4 };
            content.attach (select_check_button, 0, 0);
            content.attach (title_line, 1, 0);
            content.attach (context_label, 1, 1);
            content.attach (compatibility, 1, 2);
            content.attach (actions, 1, 3);
            append (content);
        }

        static Gtk.Label compact_label () {
            return new Gtk.Label (null) {
                xalign = 0,
                halign = Gtk.Align.FILL,
                hexpand = true,
                ellipsize = Pango.EllipsizeMode.END
            };
        }

        public void bind (GameListItem item) {
            unbind ();
            this.item = item;
            selected_binding = item.bind_property (
                "selected", select_check_button, "active",
                BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
            );
            select_check_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Select %s").printf (item.game.name),
                -1
            );
            title_label.set_label (item.game.name);
            title_label.set_tooltip_text (item.display_name);
            var context = item.game.library_context;
            context_label.set_label (context ?? "");
            context_label.set_tooltip_text (context);
            context_label.set_visible (context != null);
            select_check_button.set_visible (item.game.launcher.supports_bulk_game_edit);
            compatibility.bind (item);
            actions.bind (item);
            update_accessibility (false);
        }

        public void unbind () {
            selected_binding?.unbind ();
            selected_binding = null;
            compatibility.unbind ();
            actions.unbind ();
            item = null;
            title_label.set_label ("");
            context_label.set_visible (false);
            select_check_button.set_active (false);
            select_check_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Select game"), -1
            );
            reset_property (Gtk.AccessibleProperty.LABEL);
            reset_property (Gtk.AccessibleProperty.DESCRIPTION);
        }

        public GameListItem? get_item () {
            return item;
        }

        public bool focus_lane (GameFocusLane lane) {
            return lane == GameFocusLane.SELECTION || lane == GameFocusLane.ROW
                ? grab_focus () : actions.focus_lane (lane);
        }

        public void set_selection_mode (bool selection_mode) {
            actions.set_selection_mode (selection_mode);
            navigation_image.set_visible (!selection_mode && (item != null && item.game.can_edit_compatibility_tool));
            update_accessibility (selection_mode);
        }

        void update_accessibility (bool selection_mode) {
            if (item == null)
                return;
            update_property (
                Gtk.AccessibleProperty.LABEL, ((!) item).display_name,
                Gtk.AccessibleProperty.DESCRIPTION,
                selection_mode
                    ? _("Toggle selection for %s").printf (((!) item).game.name)
                    : (item.game.can_edit_compatibility_tool ? _("Modify %s").printf (item.game.name) : ""),
                -1
            );
        }

        bool focus_selection (GameListItem item) {
            return grab_focus ();
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
                return vertical_focus ((!) item, -1, GameFocusLane.SELECTION);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1, GameFocusLane.SELECTION);
            if (direction == Utils.ControllerNavigationDirection.RIGHT)
                return actions.focus_first_action ();
            if (direction == Utils.ControllerNavigationDirection.LEFT)
                return grab_focus ();
            return false;
        }

        public bool controller_activate (Object focused_object) {
            if (item == null)
                return false;
            var focused = focused_object as Gtk.Widget;
            if (focused != null && ((!) focused).is_ancestor (actions))
                return ((!) focused).activate ();
            if (!item.game.can_edit_compatibility_tool)
                return false;
            activation_request ((!) item);
            return true;
        }
    }
}
