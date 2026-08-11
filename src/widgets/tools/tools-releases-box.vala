namespace ProtonPlus.Widgets.Tools {
    public enum InlineExpansionTransition {
        NONE,
        EXPAND,
        COLLAPSE,
        SWITCH
    }

    public enum InlineReleaseRequestKind {
        INITIAL,
        REFRESH,
        LOAD_MORE
    }

    public class InlineReleaseInteractionState : Object {
        Object? owner;
        Object? navigation_owner;
        Object? navigation_item;
        double scroll_position = 0.0;

        public Object? expanded_owner {
            get { return owner; }
        }

        public InlineExpansionTransition expand (Object new_owner) {
            if (owner == new_owner)
                return InlineExpansionTransition.NONE;

            var transition = owner == null
                ? InlineExpansionTransition.EXPAND
                : InlineExpansionTransition.SWITCH;
            owner = new_owner;
            return transition;
        }

        public InlineExpansionTransition collapse (Object collapsed_owner) {
            if (owner != collapsed_owner)
                return InlineExpansionTransition.NONE;
            owner = null;
            return InlineExpansionTransition.COLLAPSE;
        }

        public bool is_expanded (Object candidate) {
            return owner == candidate;
        }

        public void remember_navigation (
            Object current_owner, Object selected_item, double position
        ) {
            navigation_owner = current_owner;
            navigation_item = selected_item;
            scroll_position = position;
        }

        public bool restore_navigation (
            Object current_owner, Object selected_item, out double position
        ) {
            position = scroll_position;
            return navigation_owner == current_owner && navigation_item == selected_item;
        }

        public void clear_navigation (Object cleared_owner) {
            if (navigation_owner != cleared_owner)
                return;
            navigation_owner = null;
            navigation_item = null;
            scroll_position = 0.0;
        }

        public static bool matches_filter (
            string query, string tool_title, bool expanded, bool has_loaded_release_match
        ) {
            var normalized = query.strip ().down ();
            return normalized == "" || tool_title.down ().contains (normalized) ||
                (expanded && has_loaded_release_match);
        }
    }

    public class InlineReleaseRequestGuard : Object {
        Object? owner;
        uint generation = 0;

        public uint select (Object selected_owner) {
            owner = selected_owner;
            generation++;
            return generation;
        }

        public void clear () {
            owner = null;
            generation++;
        }

        public bool is_current (Object selected_owner, uint request_generation) {
            return owner == selected_owner && generation == request_generation;
        }
    }

    public class ReleasesBox : Gtk.Box, Utils.ControllerDirectionalFocus {
        public signal void job_selected (Services.InstallJob job);

        Gtk.Box tool_box { get; set; }
        public Gtk.Label last_updated_label { get; private set; }
        public Gtk.Button refresh_button { get; private set; }
        public Gtk.Button repository_button { get; private set; }
        Gtk.ListBox list_box { get; set; }
        Gtk.Stack content_stack { get; set; }
        Adw.StatusPage status_page { get; set; }
        Adw.StatusPage error_page { get; set; }
        Gtk.Button error_retry_button { get; set; }
        Gtk.Box controls_box;
        Gtk.Box primary_controls_box;
        Gtk.Box action_controls_box;

        private Models.Tool? current_tool;
        // State changes are observed only for rows in the currently displayed
        // catalog.  Disconnect them before replacing the rows so completed
        // background jobs cannot refresh an unrelated tool's filters.
        private Gee.HashMap<Services.InstallJob, ulong> job_state_handlers = new Gee.HashMap<Services.InstallJob, ulong> ();
        // Incremented whenever a tool request replaces the visible tool state.
        // Async completions must match both this generation and their tool before
        // they are allowed to update the UI.
        private uint tool_request_generation = 0;
        private InlineReleaseRequestGuard request_guard = new InlineReleaseRequestGuard ();
        Models.Variant? selected_variant = null;
        private Gee.LinkedList<Models.Variant> displayed_variants = new Gee.LinkedList<Models.Variant> ();
        Gtk.DropDown variant_dropdown { get; set; }
        HashTable<Gtk.StringObject, Gtk.ListItem> variant_list_items;
        Gtk.Image? selected_variant_checkmark = null;
        public Gtk.Box variant_box { get; private set; }
        bool provider_has_compatible_variants = true;
        bool updating_variant_dropdown = false;
        private Gtk.ListBoxRow load_more_row;
        private Gtk.Button load_more_button;
        weak Gtk.Widget? controller_up_target;
        weak Gtk.Widget? controller_down_target;
        InlineReleaseRequestKind last_request_kind = InlineReleaseRequestKind.INITIAL;
        bool request_in_progress = false;
        bool error_active = false;
        bool narrow_controls_active = false;
        string last_announced_state = "";

        private Filter _filter = Filter.ALL;
        public Filter filter {
            get { return _filter; }
            set {
                _filter = value;
                list_box.invalidate_filter ();
                update_visibility ();
            }
        }

        private string _search_text = "";
        public string search_text {
            get { return _search_text; }
            set {
                _search_text = value;
                list_box.invalidate_filter ();
                update_visibility ();
            }
        }

        private static string get_tool_variant_settings_key (Models.Tool tool) {
            return tool.id;
        }

        private static string get_legacy_tool_variant_settings_key (Models.Tool tool) {
            return "%s::%s::%s".printf (tool.group.launcher.title, tool.group.title, tool.title);
        }

        private static string get_variant_tooltip (string variant_name) {
            switch (variant_name) {
            case "x86_64":
                return _("Standard 64-bit build for most Intel and AMD PCs.");
            case "x86_64_v3":
                return _("Optimized 64-bit build for Intel and AMD CPUs that support the x86-64-v3 instruction set.");
            case "arm64":
            case "aarch64":
                return _("64-bit ARM build. Choose this only on ARM64 hardware.");
            case "x86":
                return _("32-bit x86 build. Choose this only when a 32-bit runner is required.");
            case "wow64":
            case "x86_64_wow64":
                return _("64-bit build with WoW64 support for running 32-bit Windows applications.");
            case "default":
                return _("The provider's recommended build for most systems.");
            default:
                return _("Select the %s build variant.").printf (variant_name);
            }
        }

        private string get_saved_variant_name (Models.Tool tool) {
            if (Globals.SETTINGS == null)
                return "";

            return get_saved_variant_name_from_json (Globals.SETTINGS.get_string ("selected-tool-variants"), tool);
        }

        public static string get_saved_variant_name_from_json (string raw, Models.Tool tool) {
            if (raw == "")
                return "";

            var root_node = Utils.Parser.get_node_from_json (raw);
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT)
                return "";

            var root_obj = root_node.get_object ();
            var saved_variant_name = root_obj.get_string_member_with_default (get_tool_variant_settings_key (tool), "");
            if (saved_variant_name != "")
                return saved_variant_name;

            return root_obj.get_string_member_with_default (get_legacy_tool_variant_settings_key (tool), "");
        }

        private void save_selected_variant_name (Models.Tool tool, string variant_name) {
            if (Globals.SETTINGS == null)
                return;

            Globals.SETTINGS.set_string (
                "selected-tool-variants",
                get_json_with_saved_variant_name (
                    Globals.SETTINGS.get_string ("selected-tool-variants"), tool, variant_name
                )
            );
        }

        public static string get_json_with_saved_variant_name (string raw, Models.Tool tool, string variant_name) {
            Json.Object root_obj;
            var root_node = Utils.Parser.get_node_from_json (raw);
            if (root_node != null && root_node.get_node_type () == Json.NodeType.OBJECT) {
                root_obj = root_node.get_object ();
            } else {
                root_obj = new Json.Object ();
            }

            root_obj.set_string_member (get_tool_variant_settings_key (tool), variant_name);

            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (root_obj);

            var generator = new Json.Generator ();
            generator.set_root (node);
            return generator.to_data (null);
        }

        public ReleasesBox () {
            Object (orientation : Gtk.Orientation.VERTICAL, spacing : 0);

            variant_list_items = new HashTable<Gtk.StringObject, Gtk.ListItem> (null, null);

            last_updated_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
                xalign = 0.0f,
                wrap = true,
                css_classes = { "caption" }
            };

            refresh_button = new Gtk.Button.from_icon_name ("arrows-rotate-symbolic") {
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Check for new releases")
            };
            refresh_button.add_css_class ("flat");
            refresh_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Check for new releases"), -1
            );
            refresh_button.clicked.connect (on_refresh_clicked);

            repository_button = new Gtk.Button.from_icon_name ("globe-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            repository_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Open Repository"), -1
            );
            repository_button.set_tooltip_text (_("Open Repository"));
            repository_button.clicked.connect (() => {
                if (current_tool != null && current_tool.repository_url != "")
                    Utils.System.open_uri (current_tool.repository_url);
            });

            Gtk.Expression expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");

            variant_dropdown = new Gtk.DropDown (null, expression) {
                visible = false,
                tooltip_text = _("Choose which architecture or build variant to show.")
            };
            variant_dropdown.set_valign (Gtk.Align.CENTER);
            variant_dropdown.set_hexpand (false);
            variant_dropdown.notify["selected"].connect (on_variant_selected);

            var variant_list_factory = new Gtk.SignalListItemFactory ();
            variant_list_factory.setup.connect (on_variant_list_item_setup);
            variant_list_factory.bind.connect (on_variant_list_item_bind);
            variant_list_factory.unbind.connect (on_variant_list_item_unbind);
            variant_dropdown.set_list_factory (variant_list_factory);

            variant_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                visible = false,
                hexpand = false,
                valign = Gtk.Align.CENTER,
                margin_top = 0,
                margin_bottom = 0
            };

            variant_box.append (variant_dropdown);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-releases-card");
            list_box.set_filter_func (filter_func);

            load_more_button = new Gtk.Button.with_label (_("Load More")) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                halign = Gtk.Align.CENTER,
                hexpand = true
            };
            load_more_button.add_css_class ("pill");
            load_more_button.add_css_class ("suggested-action");
            load_more_button.clicked.connect (on_load_more_clicked);

            load_more_row = new Gtk.ListBoxRow () {
                child = load_more_button,
                activatable = false,
                selectable = false,
                focusable = false,
                visible = false
            };
            list_box.append (load_more_row);

            var spinner = new Adw.Spinner () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                hexpand = true,
                vexpand = false
            };
            spinner.set_size_request (32, 32);

            var spinner_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                vexpand = false,
                hexpand = true,
            };
            var loading_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                halign = Gtk.Align.CENTER,
                margin_top = 18,
                margin_bottom = 18
            };
            loading_box.append (spinner);
            loading_box.append (new Gtk.Label (_("Loading releases")));
            spinner_box.append (loading_box);

            content_stack = new Gtk.Stack () {
                vexpand = false,
                overflow = Gtk.Overflow.HIDDEN
            };

            status_page = new Adw.StatusPage () {
                title = _("No releases found"),
                description = _("No releases match the current filter."),
                icon_name = "edit-find-symbolic"
            };

            error_retry_button = new Gtk.Button.with_label (_("Retry")) {
                halign = Gtk.Align.CENTER
            };
            error_retry_button.add_css_class ("suggested-action");
            error_retry_button.clicked.connect (retry_current_request);
            error_page = new Adw.StatusPage () {
                title = _("Failed to Fetch Releases"),
                icon_name = "dialog-error-symbolic",
                child = error_retry_button
            };

            content_stack.add_named (list_box, "list");
            content_stack.add_named (spinner_box, "spinner");
            content_stack.add_named (status_page, "empty");
            content_stack.add_named (error_page, "error");

            tool_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_start = 12,
                margin_end = 12,
                margin_top = 6
            };
            primary_controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                hexpand = true
            };
            primary_controls_box.append (variant_box);
            primary_controls_box.append (last_updated_label);
            action_controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.END
            };
            action_controls_box.append (repository_button);
            action_controls_box.append (refresh_button);
            controls_box.append (primary_controls_box);
            controls_box.append (action_controls_box);

            var responsive_controls = new Adw.BreakpointBin () {
                width_request = 240,
                height_request = 40
            };
            responsive_controls.set_child (controls_box);
            var narrow_controls = new Adw.Breakpoint (
                new Adw.BreakpointCondition.length (
                    Adw.BreakpointConditionLengthType.MAX_WIDTH,
                    520,
                    Adw.LengthUnit.SP
                )
            );
            narrow_controls.apply.connect (() => set_narrow_controls (true));
            narrow_controls.unapply.connect (() => set_narrow_controls (false));
            responsive_controls.add_breakpoint (narrow_controls);

            tool_box.append (responsive_controls);
            tool_box.append (content_stack);
            append (tool_box);
        }

        void set_narrow_controls (bool narrow) {
            narrow_controls_active = narrow;
            variant_box.hexpand = narrow;
            variant_dropdown.hexpand = narrow;
            update_last_updated_visibility ();
        }

        void update_last_updated_visibility () {
            last_updated_label.set_visible (
                !narrow_controls_active && last_updated_label.get_label () != ""
            );
        }

        public void set_controller_up_target (Gtk.Widget? target) {
            controller_up_target = target;
        }

        public void set_controller_down_target (Gtk.Widget? target) {
            controller_down_target = target;
        }

        public async bool set_selected_tool (Models.Tool tool) {
            uint request_generation = request_guard.select (tool);
            tool_request_generation = request_generation;
            current_tool = tool;
            last_request_kind = InlineReleaseRequestKind.INITIAL;
            refresh_button.sensitive = false;
            set_request_in_progress (true);
            error_active = false;
            content_stack.set_visible_child_name ("spinner");
            announce_state (_("Loading releases"));
            reset_load_more_button ();

            disconnect_job_state_handlers ();
            list_box.remove_all ();

            update_repository_button (tool);
            update_last_updated_label ();
            update_variant_row (tool);

            var catalog = tool.release_catalog;
            if (catalog == null) {
                set_request_in_progress (false);
                content_stack.set_visible_child_name ("empty");
                refresh_button.sensitive = true;
                announce_state (_("No releases found"));
                return true;
            }

            var result = yield catalog.load (false);

            if (!is_current_tool_request (tool, request_generation))
                return false;
            set_request_in_progress (false);
            refresh_button.sensitive = true;

            if (!result.succeeded) {
                show_error (result.code);
                return false;
            }

            // Directory and legacy-tag fallback resolution depends on the
            // available release names.  Refresh explicitly after that catalog
            // changes; list filters themselves remain pure state readers.
            tool.group.refresh_installed_state ();
            add_release_rows (tool, result.releases);

            list_box.append (load_more_row);
            load_more_row.visible = catalog.has_more && can_show_provider_release_rows ();

            content_stack.set_visible_child_name ("list");
            apply_selected_variant_to_rows ();
            update_last_updated_label ();
            update_visibility ();
            announce_state (_("Releases loaded"));
            return true;
        }

        public void clear_selected_tool () {
            request_guard.clear ();
            tool_request_generation++;
            current_tool = null;
            disconnect_job_state_handlers ();
            list_box.remove_all ();
            reset_load_more_button ();
            refresh_button.sensitive = true;
            set_request_in_progress (false);
            error_active = false;
            last_announced_state = "";
            content_stack.set_visible_child_name ("empty");
        }

        public bool is_showing_tool (Models.Tool tool) {
            return current_tool == tool;
        }

        public bool is_loading_tool (Models.Tool tool) {
            return current_tool == tool && request_in_progress;
        }

        public bool has_release_title_match (string query) {
            if (query.strip () == "")
                return true;
            var normalized = query.strip ().down ();
            var child = list_box.get_first_child ();
            while (child != null) {
                var job = child.get_data<Services.InstallJob> ("job");
                if (job != null && job.title.down ().contains (normalized))
                    return true;
                child = child.get_next_sibling ();
            }
            return false;
        }

        void announce_state (string message) {
            if (last_announced_state == message)
                return;
            last_announced_state = message;
            content_stack.update_property (Gtk.AccessibleProperty.LABEL, message, -1);
            content_stack.announce (message, Gtk.AccessibleAnnouncementPriority.MEDIUM);
        }

        void set_request_in_progress (bool in_progress) {
            request_in_progress = in_progress;
            content_stack.update_state (
                Gtk.AccessibleState.BUSY, in_progress, -1
            );
        }

        void show_error (ReturnCode code) {
            error_active = true;
            error_page.set_description (get_return_code_message (code));
            content_stack.set_visible_child_name ("error");
            announce_state (_("Failed to Fetch Releases"));
        }

        void retry_current_request () {
            if (current_tool == null)
                return;
            if (last_request_kind == InlineReleaseRequestKind.REFRESH)
                set_selected_tool_forced.begin ((!) current_tool);
            else if (last_request_kind == InlineReleaseRequestKind.LOAD_MORE)
                on_load_more_clicked.begin ();
            else
                set_selected_tool.begin ((!) current_tool);
        }

        public bool focus_first_controller_target () {
            var control = find_inline_control (null, true);
            if (control != null)
                return ((!) control).grab_focus ();

            return focus_first_content_target ();
        }

        bool focus_first_content_target () {
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is ReleaseRow && child.get_mapped () &&
                    child.is_visible () && child.get_child_visible () &&
                    child.is_sensitive () && child.get_focusable ())
                    return child.grab_focus ();
                child = child.get_next_sibling ();
            }

            if (load_more_row.get_mapped () && load_more_row.is_visible () &&
                load_more_row.get_child_visible () && load_more_button.is_sensitive ())
                return load_more_button.grab_focus ();

            if (error_retry_button.get_mapped () && error_retry_button.is_visible () &&
                error_retry_button.is_sensitive ())
                return error_retry_button.grab_focus ();

            return controller_up_target != null &&
                ((!) controller_up_target).get_mapped () &&
                ((!) controller_up_target).is_visible () &&
                ((!) controller_up_target).is_sensitive () &&
                ((!) controller_up_target).grab_focus ();
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;

            var inline_control = find_inline_control_ancestor ((!) focused);
            if (inline_control != null) {
                if (direction == Utils.ControllerNavigationDirection.UP)
                    return focus_controller_up_target ();
                if (direction == Utils.ControllerNavigationDirection.DOWN)
                    return focus_first_content_target ();
                if (direction == Utils.ControllerNavigationDirection.LEFT ||
                    direction == Utils.ControllerNavigationDirection.RIGHT) {
                    var target = find_inline_control (
                        (!) inline_control,
                        direction == Utils.ControllerNavigationDirection.RIGHT
                    );
                    return target != null
                        ? ((!) target).grab_focus ()
                        : ((!) inline_control).grab_focus ();
                }
                return false;
            }

            if (focused == error_retry_button || ((!) focused).is_ancestor (error_retry_button)) {
                if (direction == Utils.ControllerNavigationDirection.UP) {
                    var target = find_inline_control (null, false);
                    return target != null
                        ? ((!) target).grab_focus ()
                        : focus_controller_up_target ();
                }
                if (direction == Utils.ControllerNavigationDirection.DOWN)
                    return focus_controller_down_target ();
                return false;
            }

            if (focused != load_more_row && !((!) focused).is_ancestor (load_more_row))
                return false;

            if (direction == Utils.ControllerNavigationDirection.UP) {
                var child = list_box.get_last_child ();
                while (child != null) {
                    if (child is ReleaseRow && child.get_mapped () &&
                        child.is_visible () && child.get_child_visible () &&
                        child.is_sensitive () && child.get_focusable ())
                        return child.grab_focus ();
                    child = child.get_prev_sibling ();
                }
            }

            if (direction == Utils.ControllerNavigationDirection.DOWN &&
                focus_controller_down_target ())
                return true;

            return load_more_button.grab_focus ();
        }

        bool focus_controller_up_target () {
            return controller_up_target != null &&
                ((!) controller_up_target).get_mapped () &&
                ((!) controller_up_target).is_visible () &&
                ((!) controller_up_target).is_sensitive () &&
                ((!) controller_up_target).grab_focus ();
        }

        bool focus_controller_down_target () {
            return controller_down_target != null &&
                ((!) controller_down_target).get_mapped () &&
                ((!) controller_down_target).is_visible () &&
                ((!) controller_down_target).is_sensitive () &&
                ((!) controller_down_target).grab_focus ();
        }

        Gtk.Widget? find_inline_control_ancestor (Gtk.Widget focused) {
            Gtk.Widget[] controls = { variant_dropdown, repository_button, refresh_button };
            foreach (var control in controls) {
                if (focused == control || focused.is_ancestor (control))
                    return control;
            }
            return null;
        }

        Gtk.Widget? find_inline_control (Gtk.Widget? current, bool forward) {
            Gtk.Widget[] controls = { variant_dropdown, repository_button, refresh_button };
            int start = forward ? 0 : controls.length - 1;
            int step = forward ? 1 : -1;
            bool accept = current == null;
            for (int index = start; index >= 0 && index < controls.length; index += step) {
                var control = controls[index];
                if (!accept) {
                    if (control == current)
                        accept = true;
                    continue;
                }
                if (control == current)
                    continue;
                if (control.get_mapped () && control.is_visible () &&
                    control.is_sensitive () && control.get_focusable ())
                    return control;
            }
            return null;
        }

        private void on_variant_list_item_setup (Object object) {
            var list_item = object as Gtk.ListItem;
            var label = new Gtk.Label (null) {
                xalign = 0.0f,
                hexpand = true
            };
            var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic") {
                visible = false
            };
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                hexpand = true
            };
            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true,
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 12,
                margin_end = 12
            };
            content.append (label);
            content.append (checkmark);
            row.append (content);

            object.set_data ("variant-label", label);
            object.set_data ("variant-checkmark", checkmark);
            object.set_data ("variant-row", row);
            list_item.set_child (row);
        }

        private void on_variant_list_item_bind (Object object) {
            var list_item = object as Gtk.ListItem;
            var variant = list_item.item as Gtk.StringObject;
            if (variant == null)
                return;

            variant_list_items.set (variant, list_item);

            var variant_name = variant.string;
            var tooltip = get_variant_tooltip (variant_name);
            var label = object.get_data<Gtk.Label> ("variant-label");
            var checkmark = object.get_data<Gtk.Image> ("variant-checkmark");
            var row = object.get_data<Gtk.Box> ("variant-row");
            var list_row = row.get_parent ();

            label.set_label (variant_name);
            if (list_row != null)
                list_row.set_tooltip_text (tooltip);
            checkmark.set_visible (variant == variant_dropdown.selected_item);
            if (checkmark.visible)
                selected_variant_checkmark = checkmark;
        }

        private void on_variant_list_item_unbind (Object object) {
            var list_item = object as Gtk.ListItem;
            var variant = list_item.item as Gtk.StringObject;
            if (variant != null && variant_list_items.get (variant) == list_item)
                variant_list_items.remove (variant);

            var checkmark = object.get_data<Gtk.Image> ("variant-checkmark");
            if (checkmark == selected_variant_checkmark)
                selected_variant_checkmark = null;
        }

        private void update_variant_list_item_checkmark () {
            if (selected_variant_checkmark != null)
                selected_variant_checkmark.set_visible (false);

            var selected_item = variant_dropdown.selected_item as Gtk.StringObject;
            var list_item = selected_item != null ? variant_list_items.get (selected_item) : null;
            if (list_item == null) {
                selected_variant_checkmark = null;
                return;
            }

            selected_variant_checkmark = list_item.get_data<Gtk.Image> ("variant-checkmark");
            selected_variant_checkmark.set_visible (true);
        }

        private void on_refresh_clicked () {
            if (current_tool == null)
                return;
            set_selected_tool_forced.begin (current_tool);
        }

        private async void set_selected_tool_forced (Models.Tool tool) {
            uint request_generation = request_guard.select (tool);
            tool_request_generation = request_generation;
            current_tool = tool;
            last_request_kind = InlineReleaseRequestKind.REFRESH;
            set_request_in_progress (true);
            error_active = false;
            content_stack.set_visible_child_name (has_release_rows () ? "list" : "spinner");
            refresh_button.sensitive = false;
            announce_state (_("Loading releases"));
            reset_load_more_button ();
            load_more_button.sensitive = false;

            var catalog = tool.release_catalog;
            if (catalog == null) {
                set_request_in_progress (false);
                content_stack.set_visible_child_name ("empty");
                refresh_button.sensitive = true;
                reset_load_more_button ();
                return;
            }

            var result = yield catalog.refresh ();

            if (!is_current_tool_request (tool, request_generation))
                return;
            set_request_in_progress (false);

            if (!result.succeeded) {
                refresh_button.sensitive = true;
                reset_load_more_button ();
                show_error (result.code);
                return;
            }

            disconnect_job_state_handlers ();
            list_box.remove_all ();
            tool.group.refresh_installed_state ();
            add_release_rows (tool, result.releases);

            list_box.append (load_more_row);
            load_more_row.visible = catalog.has_more && can_show_provider_release_rows ();

            content_stack.set_visible_child_name ("list");
            apply_selected_variant_to_rows ();
            update_last_updated_label ();
            update_visibility ();
            refresh_button.sensitive = true;
            reset_load_more_button ();
            announce_state (_("Releases loaded"));
        }

        private void update_variant_row (Models.Tool tool) {
            selected_variant = null;
            displayed_variants.clear ();
            provider_has_compatible_variants = true;
            variant_dropdown.set_visible (false);
            variant_box.set_visible (false);

            var provider_tool = tool as Models.Tools.ProviderTool;
            if (provider_tool == null) {
                status_page.set_description (_("No releases match the current filter."));
                return;
            }

            displayed_variants = Models.VariantSelector.compatible_variants (
                provider_tool.variants, Globals.CPU_CAPABILITIES
            );
            provider_has_compatible_variants = displayed_variants.size > 0;
            if (!provider_has_compatible_variants) {
                status_page.set_description (_("No compatible variants are available for this system."));
                return;
            }

            status_page.set_description (_("No releases match the current filter."));
            selected_variant = Models.VariantSelector.select_variant (
                displayed_variants, Globals.CPU_CAPABILITIES, get_saved_variant_name (tool)
            );
            if (!Models.VariantSelector.should_show_dropdown (displayed_variants))
                return;

            var model = new Gtk.StringList (null);
            int selected_index = 0;
            int index = 0;
            foreach (var variant in displayed_variants) {
                model.append (variant.name);
                if (variant == selected_variant)
                    selected_index = index;
                index++;
            }

            updating_variant_dropdown = true;
            variant_dropdown.model = model;
            variant_dropdown.selected = (uint) selected_index;
            updating_variant_dropdown = false;
            update_variant_list_item_checkmark ();
            variant_dropdown.set_visible (true);
            variant_box.set_visible (true);
        }

        private void update_repository_button (Models.Tool tool) {
            if (tool.repository_url != "")
                repository_button.update_property (
                    Gtk.AccessibleProperty.DESCRIPTION,
                    tool.repository_url,
                    -1
                );
            else
                repository_button.reset_property (
                    Gtk.AccessibleProperty.DESCRIPTION
                );
            repository_button.set_visible (tool.repository_url != "");
        }

        private void on_variant_selected () {
            if (updating_variant_dropdown || current_tool == null || displayed_variants.size <= 1)
                return;

            int selected_index = (int) variant_dropdown.selected;
            var variant = Models.VariantSelector.variant_at_display_index (displayed_variants, selected_index);
            if (variant == null)
                return;

            update_variant_list_item_checkmark ();

            if (selected_variant == variant)
                return;

            selected_variant = variant;
            save_selected_variant_name (current_tool, variant.name);
            apply_selected_variant_to_rows ();
        }

        private Models.Variant? resolve_release_variant (Models.Release release, Services.InstallJob.Mode mode) {
            return Models.VariantSelector.resolve_release_variant (
                release, selected_variant, Globals.CPU_CAPABILITIES,
                mode == Services.InstallJob.Mode.LATEST
            );
        }

        private bool apply_selected_variant_to_job (Services.InstallJob job) {
            if (!(job.tool is Models.Tools.ProviderTool))
                return true;

            var variant = resolve_release_variant (job.release, job.mode);
            if (variant == null || variant.download_url == null || variant.download_url == "") {
                // Keep state, usage, folder, and removal checks bound to the
                // selected installation slot even when this release has no
                // installable asset for it.  The row then disables only the
                // unavailable install/update action.
                if (selected_variant != null) {
                    job.set_selected_variant (
                        ((!) selected_variant).name,
                        null,
                        ((!) selected_variant).id
                    );
                }
                return false;
            }

            job.set_selected_variant (variant.name, variant.resolved_asset (), variant.id);
            return true;
        }

        private void apply_selected_variant_to_rows () {
            var child = list_box.get_first_child ();
            while (child != null) {
                var job = child.get_data<Services.InstallJob> ("job");
                if (job != null) {
                    var row = child as ReleaseRow;
                    var available = apply_selected_variant_to_job (job);
                    if (row != null)
                        ((!) row).set_release_action_available (available);
                }

                child = child.get_next_sibling ();
            }

            list_box.invalidate_filter ();
            update_visibility ();
        }

        private void update_last_updated_label () {
            if (current_tool == null || current_tool.release_catalog == null ||
                current_tool.release_catalog.last_updated == "") {
                last_updated_label.set_label ("");
                last_updated_label.set_visible (false);
                return;
            }

            var timestamp = Utils.format_timestamp (current_tool.release_catalog.last_updated);
            if (timestamp != "") {
                last_updated_label.set_label (_("Last updated: %s").printf (timestamp));
            } else {
                last_updated_label.set_label ("");
            }

            update_last_updated_visibility ();
        }

        public void refresh_usage_pills () {
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is ReleaseRow) {
                    ((ReleaseRow) child).refresh_usage_pill ();
                }
                child = child.get_next_sibling ();
            }
            list_box.invalidate_filter ();
            update_visibility ();
        }

        public ReleaseRow? focus_job_row (Services.InstallJob target, bool highlight = false) {
            var row = find_job_row (target);
            if (row == null || !((!) row).get_mapped () || !((!) row).is_visible () ||
                !((!) row).get_child_visible ())
                return null;
            ((!) row).grab_focus ();
            if (highlight) {
                ((!) row).add_css_class ("download-highlight");
                var weak_row = WeakRef ((!) row);
                Timeout.add (1200, () => {
                    var current_row = weak_row.get () as ReleaseRow;
                    if (current_row != null)
                        ((!) current_row).remove_css_class ("download-highlight");
                    return Source.REMOVE;
                });
            }
            return row;
        }

        private ReleaseRow? find_job_row (Services.InstallJob target) {
            var child = list_box.get_first_child ();
            while (child != null) {
                var job = child.get_data<Services.InstallJob> ("job");
                if (job != null && (job == target || jobs_have_same_identity (job, target))) {
                    return child as ReleaseRow;
                }
                child = child.get_next_sibling ();
            }

            return null;
        }

        private bool jobs_have_same_identity (Services.InstallJob left, Services.InstallJob right) {
            if (left.tool.id != right.tool.id || left.mode != right.mode)
                return false;

            if (left.release.upstream_release_id != "" && right.release.upstream_release_id != "")
                return left.release.upstream_release_id == right.release.upstream_release_id;

            return left.release.source_tag != "" && right.release.source_tag != "" &&
                   left.release.source_tag == right.release.source_tag;
        }

        private void add_release_rows (Models.Tool tool, Gee.LinkedList<Models.Release> releases) {
            if (tool is Models.Tools.ProviderTool && releases.size > 0)
                add_release_row (releases[0], Services.InstallJob.Mode.LATEST);
            foreach (var release in releases)
                add_release_row (release);
        }

        private void add_release_row (
            Models.Release release,
            Services.InstallJob.Mode mode = Services.InstallJob.Mode.VERSIONED
        ) {
            if (current_tool == null)
                return;
            var job = new Services.InstallJob (release, current_tool, mode);
            var release_action_available = apply_selected_variant_to_job (job);

            var active_job = Utils.DownloadManager.instance.get_active_download (job);
            if (active_job != null)
                job = active_job;

            if (job_state_handlers.has_key (job))
                job.disconnect (job_state_handlers.get (job));
            job_state_handlers.set (job, job.notify["state"].connect (() => {
                if (job.state != Services.InstallJob.State.BUSY_INSTALLING &&
                    job.state != Services.InstallJob.State.BUSY_REMOVING &&
                    job.state != Services.InstallJob.State.BUSY_UPDATING) {
                    list_box.invalidate_filter ();
                    update_visibility ();
                }
            }));

            ReleaseRow row;
            if (job.steam_tinker_launch_context != null) {
                row = new STLReleaseRow (job);
                if (active_job == null)
                    Services.InstallationService.instance.refresh_steam_tinker_launch_release.begin (job);
            } else {
                row = new ReleaseRow (job, release_action_available);
            }
            var row_up_target = find_inline_control (null, false);
            row.set_controller_up_target (
                row_up_target != null ? (!) row_up_target : controller_up_target
            );
            row.set_controller_down_target (controller_down_target);
            row.set_data ("job", job);
            row.job_selected.connect ((selected_job) => job_selected (selected_job));
            list_box.append (row);
        }

        private void disconnect_job_state_handlers () {
            foreach (var entry in job_state_handlers.entries)
                entry.key.disconnect (entry.value);
            job_state_handlers.clear ();
        }

        public override void dispose () {
            disconnect_job_state_handlers ();
            base.dispose ();
        }

        private async void on_load_more_clicked () {
            if (current_tool == null)
                return;

            Models.Tool tool = current_tool;
            uint request_generation = tool_request_generation;
            last_request_kind = InlineReleaseRequestKind.LOAD_MORE;
            error_active = false;
            content_stack.set_visible_child_name ("list");
            refresh_button.sensitive = false;
            load_more_button.sensitive = false;
            load_more_button.set_label (_("Loading…"));
            announce_state (_("Loading releases"));

            var catalog = tool.release_catalog;
            if (catalog == null) {
                reset_load_more_button ();
                refresh_button.sensitive = true;
                return;
            }

            var result = yield catalog.load_more ();

            if (!is_current_tool_request (tool, request_generation))
                return;

            if (result.succeeded) {
                foreach (var release in result.releases) {
                    add_release_row (release, Services.InstallJob.Mode.VERSIONED);
                }
                tool.group.refresh_installed_state ();
                list_box.remove (load_more_row);
                list_box.append (load_more_row);
            } else {
                reset_load_more_button ();
                refresh_button.sensitive = true;
                show_error (result.code);
                return;
            }

            load_more_row.visible = catalog.has_more && can_show_provider_release_rows ();
            reset_load_more_button ();
            refresh_button.sensitive = true;
            update_visibility ();
            announce_state (_("Releases loaded"));
        }

        void reset_load_more_button () {
            load_more_button.sensitive = true;
            load_more_button.set_label (_("Load More"));
        }

        private bool is_current_tool_request (Models.Tool tool, uint request_generation) {
            return current_tool == tool && request_guard.is_current (tool, request_generation);
        }

        private bool can_show_provider_release_rows () {
            return !(current_tool is Models.Tools.ProviderTool) || provider_has_compatible_variants;
        }

        void update_visibility () {
            if (request_in_progress || error_active)
                return;

            bool has_visible = false;
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is Gtk.ListBoxRow && child != load_more_row) {
                    if (filter_func ((Gtk.ListBoxRow) child)) {
                        has_visible = true;
                        break;
                    }
                }
                child = child.get_next_sibling ();
            }

            if (has_visible || (load_more_row != null && load_more_row.visible)) {
                content_stack.set_visible_child_name ("list");
            } else {
                content_stack.set_visible_child_name ("empty");
                announce_state (_("No releases found"));
            }
        }

        bool has_release_rows () {
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child.get_data<Services.InstallJob> ("job") != null)
                    return true;
                child = child.get_next_sibling ();
            }
            return false;
        }

        bool filter_func (Gtk.ListBoxRow row) {
            var job = row.get_data<Services.InstallJob> ("job");
            if (job == null)
                return true;

            if (search_text != "" &&
                !job.release.title.down ().contains (search_text.down ()) &&
                !job.title.down ().contains (search_text.down ()))
                return false;

            var provider_tool = current_tool as Models.Tools.ProviderTool;
            if (provider_tool != null && !provider_has_compatible_variants)
                return false;

            if (filter == Filter.ALL)
                return true;

            if (filter == Filter.INSTALLED)
                return job.state == Services.InstallJob.State.UP_TO_DATE || job.state == Services.InstallJob.State.UPDATE_AVAILABLE;

            var usage_count = job.tool.group.launcher.get_compatibility_tool_usage_count (job.get_usage_identifier ());

            if (filter == Filter.USED)
                return usage_count > 0;

            if (filter == Filter.UNUSED)
                return usage_count == 0;

            return true;
        }
    }
}
