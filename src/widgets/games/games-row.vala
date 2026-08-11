namespace ProtonPlus.Widgets.Games {
    public delegate bool GameVerticalFocusRequest (GameListItem item, int delta);
    public delegate bool GamePeerFocusRequest (GameListItem item);
    public delegate void GameActivationRequest (GameListItem item);

    public enum GameTextCellKind {
        TITLE,
        PREFIX,
        TOOL
    }

    public class GameSelectionCell : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        Gtk.CheckButton check_button;
        Gtk.Image navigation_image;
        Binding? selected_binding;
        GameListItem? item;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GamePeerFocusRequest actions_focus;
        unowned GameActivationRequest activation_request;

        public GameSelectionCell (GameVerticalFocusRequest vertical_focus,
            GamePeerFocusRequest actions_focus,
            GameActivationRequest activation_request) {
            Object (orientation: Gtk.Orientation.HORIZONTAL);
            this.vertical_focus = vertical_focus;
            this.actions_focus = actions_focus;
            this.activation_request = activation_request;

            set_focusable (true);
            set_halign (Gtk.Align.CENTER);
            set_valign (Gtk.Align.CENTER);
            set_margin_top (4);
            set_margin_bottom (4);
            check_button = new Gtk.CheckButton () {
                tooltip_text = _("Select game"),
                focusable = false
            };
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
            update_accessibility (false);
        }

        public void unbind () {
            selected_binding?.unbind ();
            selected_binding = null;
            item = null;
            check_button.set_active (false);
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
                return vertical_focus ((!) item, -1);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1);
            if (direction == Utils.ControllerNavigationDirection.RIGHT)
                return actions_focus ((!) item);
            if (direction == Utils.ControllerNavigationDirection.LEFT)
                return grab_focus ();
            return false;
        }

        public void set_selection_mode (bool selection_mode) {
            navigation_image.set_opacity (selection_mode ? 0.0 : 1.0);
            navigation_image.set_can_target (!selection_mode);
            update_accessibility (selection_mode);
        }

        public bool controller_activate (Object focused) {
            if (item == null)
                return false;
            activation_request ((!) item);
            return true;
        }

        void update_accessibility (bool selection_mode) {
            if (item == null)
                return;
            update_property (
                Gtk.AccessibleProperty.LABEL, ((!) item).game.name,
                Gtk.AccessibleProperty.DESCRIPTION,
                selection_mode
                    ? _("Toggle selection for %s").printf (((!) item).game.name)
                    : _("Modify %s").printf (((!) item).game.name),
                -1
            );
        }
    }

    public class GameTextCell : Gtk.Box {
        Gtk.Label label;
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
        }

        void refresh () {
            if (item == null)
                return;
            switch (kind) {
            case GameTextCellKind.TITLE:
                label.set_label (((!) item).game.name);
                label.set_tooltip_text (((!) item).game.name);
                break;
            case GameTextCellKind.PREFIX:
                label.set_label (((!) item).game.prefix.to_string ());
                label.set_tooltip_text (null);
                break;
            case GameTextCellKind.TOOL:
                label.set_label (((!) item).tool_title);
                label.set_tooltip_text (((!) item).tool_title);
                break;
            }
        }

    }

    public class GameActions : Gtk.Box, Utils.ControllerDirectionalFocus {
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
            launch_button.clicked.connect (() => {
                var steam_game = target.item?.game as Models.Games.Steam;
                if (steam_game != null)
                    Utils.System.open_uri ("steam://run/" + ((!) steam_game).appid.to_string ());
            });

            extra_button = new ExtraButton (target);
            append (launch_button);
            append (extra_button.button);
        }

        public void bind (GameListItem item) {
            unbind ();
            target.bind (item);
            var availability = GameActionAvailability.evaluate (
                item.game is Models.Games.Steam,
                item.is_non_steam,
                item.is_native,
                item.has_install_directory,
                item.has_prefix_directory,
                Globals.PROTONTRICKS_INSTALLED ||
                    Globals.PROTONTRICKS_FLATPAK_INSTALLED,
                (item.game as Models.Games.Steam)?.awacy_status,
                (item.game as Models.Games.Steam)?.awacy_name != null
            );
            launch_button.set_visible (availability.show_launch);
            launch_button.set_tooltip_text (_("Launch %s").printf (item.game.name));
            launch_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Launch %s").printf (item.game.name),
                -1
            );
            extra_button.bind (item);
            refresh_visibility ();
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

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            if (target.item == null)
                return false;
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;
            if (direction == Utils.ControllerNavigationDirection.UP)
                return vertical_focus ((!) target.item, -1);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) target.item, 1);
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

        void refresh_visibility () {
            set_visible (!selection_mode && target.item != null &&
                (launch_button.get_visible () || extra_button.button.get_visible ()));
        }
    }

    public class GameRow : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        Gtk.CheckButton select_check_button;
        Gtk.Label title_label;
        Gtk.Label tool_label;
        Gtk.Label prefix_label;
        GameActions actions;
        Gtk.Image navigation_image;
        Binding? selected_binding;
        GameListItem? item;
        ulong tool_title_handler = 0;
        unowned GameVerticalFocusRequest vertical_focus;
        unowned GameActivationRequest activation_request;

        public GameRow (GameVerticalFocusRequest vertical_focus,
            GameActivationRequest activation_request) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 4);
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
            title_label = compact_label (true);
            title_label.add_css_class ("heading");
            tool_label = compact_label (true);
            prefix_label = compact_label (false);
            prefix_label.add_css_class ("dim-label");

            var title_line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            title_line.append (select_check_button);
            title_line.append (title_label);
            navigation_image = new Gtk.Image.from_icon_name ("go-next-symbolic") {
                tooltip_text = _("Modify Game")
            };
            title_line.append (navigation_image);

            var details_line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            details_line.set_margin_start (30);
            details_line.append (tool_label);
            details_line.append (prefix_label);

            actions = new GameActions (on_vertical_focus, focus_selection);
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
            prefix_label.set_tooltip_text (null);
            refresh_tool_title ();
            actions.bind (item);
            update_accessibility (false);
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
            reset_property (Gtk.AccessibleProperty.LABEL);
            reset_property (Gtk.AccessibleProperty.DESCRIPTION);
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

        public void set_selection_mode (bool selection_mode) {
            actions.set_selection_mode (selection_mode);
            navigation_image.set_visible (!selection_mode);
            update_accessibility (selection_mode);
        }

        void update_accessibility (bool selection_mode) {
            if (item == null)
                return;
            update_property (
                Gtk.AccessibleProperty.LABEL, ((!) item).game.name,
                Gtk.AccessibleProperty.DESCRIPTION,
                selection_mode
                    ? _("Toggle selection for %s").printf (((!) item).game.name)
                    : _("Modify %s").printf (((!) item).game.name),
                -1
            );
        }

        bool on_vertical_focus (GameListItem item, int delta) {
            return vertical_focus (item, delta);
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
                return vertical_focus ((!) item, -1);
            if (direction == Utils.ControllerNavigationDirection.DOWN)
                return vertical_focus ((!) item, 1);
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
            activation_request ((!) item);
            return true;
        }
    }
}
