namespace ProtonPlus.Widgets.Tools {
    public class GroupBox : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        public signal void tool_expansion_changed (Models.Tool tool, bool expanded);
        public signal void reset_filter_requested ();
        public signal void changelog_requested (Services.InstallJob job, Models.Release release);
        public signal void games_requested (Services.InstallJob job);
        public signal void rows_changed ();

        Gtk.ListBox list_box;
        Gtk.ListBox installed_list;
        Models.Group group;
        ulong invalidated_handler;
        ulong refreshed_handler;
        Gtk.Stack stack;
        Adw.StatusPage status_page;
        Gtk.Button empty_action_button;
        weak Gtk.Widget? controller_up_target;
        weak Gtk.Widget? controller_down_target;
        Adw.ExpanderRow? expanded_row;
        Models.Tool? expanded_tool;
        ReleasesBox? releases_section;
        Gtk.Box? releases_host;
        bool changing_expansion = false;
        uint visibility_change_generation = 0;
        uint installed_update_generation = 0;

        private Filter _filter = Filter.ALL;
        public Filter filter {
            get { return _filter; }
            set {
                visibility_change_generation++;
                installed_update_generation++;
                _filter = value;
                if (value == Filter.INSTALLED)
                    refresh_installed_rows ();
                list_box.invalidate_filter ();
                update_status_page ();
                update_visibility ();
                collapse_if_hidden ();
                rows_changed ();
            }
        }

        public GroupBox (Models.Group group, Gtk.Widget? controller_up_target = null) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 6);
            this.controller_up_target = controller_up_target;
            this.group = group;

            // Build this once before Gtk begins repeatedly invoking the filter
            // and comparator callbacks below.
            group.refresh_installed_state ();

            var title_label = new Gtk.Label (group.title) {
                xalign = 0,
                css_classes = { "title-4" }
            };
            var subtitle_label = new Gtk.Label (group.description) {
                xalign = 0,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                visible = group.description != "",
                css_classes = { "caption" }
            };
            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { hexpand = true };
            title_box.append (title_label);
            title_box.append (subtitle_label);
            var category_heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true,
                valign = Gtk.Align.CENTER,
                margin_start = 12,
                overflow = Gtk.Overflow.HIDDEN
            };
            category_heading.append (new Gtk.Image.from_icon_name ("view-grid-symbolic"));
            category_heading.append (title_box);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                valign = Gtk.Align.START
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-tools-card");
            configure_list_callbacks (this);

            invalidated_handler = group.installed_tool_index_invalidated.connect (refresh_installed_state);
            refreshed_handler = group.installed_state_refreshed.connect (refresh);

            status_page = new Adw.StatusPage () {
                css_classes = { "compact" }
            };
            empty_action_button = new Gtk.Button () {
                halign = Gtk.Align.CENTER,
                visible = false
            };
            empty_action_button.add_css_class ("suggested-action");
            empty_action_button.clicked.connect (activate_empty_action);
            status_page.set_child (empty_action_button);

            stack = new Gtk.Stack () {
                hhomogeneous = false,
                vhomogeneous = false
            };
            stack.add_named (list_box, "list");
            installed_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                valign = Gtk.Align.START,
                css_classes = { "boxed-list", "tools-tools-card" }
            };
            stack.add_named (installed_list, "installed");
            stack.add_named (status_page, "empty");
            map.connect (check_installed_updates);
            unmap.connect (() => installed_update_generation++);

            foreach (var tool in group.tools) {
                var row = create_tool_card (tool);
                row.set_data ("tool", tool);
                list_box.append (row);
            }

            list_box.invalidate_sort ();

            append (category_heading);
            append (stack);

            update_status_page ();
            update_visibility ();
        }

        static void connect_expansion (GroupBox box, Adw.ExpanderRow row, Models.Tool tool) {
            var owner_ref = WeakRef (box);
            var row_ref = WeakRef (row);
            row.notify["expanded"].connect (() => {
                var owner = owner_ref.get () as GroupBox;
                var current_row = row_ref.get () as Adw.ExpanderRow;
                if (owner != null && current_row != null)
                    owner.on_row_expanded_changed (current_row, tool);
            });
        }

        void refresh_installed_state () {
            group.refresh_installed_state ();
        }

        void activate_empty_action () {
            if (filter != Filter.ALL)
                reset_filter_requested ();
        }

        static void configure_list_callbacks (GroupBox box) {
            // GtkListBox owns these delegates. They must not retain its parent.
            var owner_ref = WeakRef (box);
            box.list_box.set_filter_func ((row) => {
                var owner = owner_ref.get () as GroupBox;
                return owner != null && owner.filter_func (row);
            });
            box.list_box.set_sort_func ((a, b) => {
                var owner = owner_ref.get () as GroupBox;
                return owner != null ? owner.sort_func (a, b) : 0;
            });
        }

        public override void dispose () {
            detach_release_section ();
            if (invalidated_handler != 0) {
                group.disconnect (invalidated_handler);
                invalidated_handler = 0;
            }
            if (refreshed_handler != 0) {
                group.disconnect (refreshed_handler);
                refreshed_handler = 0;
            }
            base.dispose ();
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            var focused_row = find_expander_row_ancestor (focused);
            if (focused_row == null)
                return focused == empty_action_button && focus_section_boundary (direction);

            bool in_release_section = releases_section != null && focused != null &&
                (focused == releases_section || ((!) focused).is_ancestor ((!) releases_section));
            if (in_release_section)
                return false;

            var tool_actions = releases_section?.actions_button;
            bool actions_focused = tool_actions != null && focused != null &&
                (focused == tool_actions || ((!) focused).is_ancestor ((!) tool_actions));
            if (direction == Utils.ControllerNavigationDirection.RIGHT && focused_row == expanded_row &&
                tool_actions != null && tool_actions.get_mapped ())
                return actions_focused || tool_actions.grab_focus ();
            if (direction == Utils.ControllerNavigationDirection.LEFT) {
                if (actions_focused)
                    return focused_row.grab_focus ();
                if (focused_row.expanded)
                    focused_row.expanded = false;
                return true;
            }

            if (direction == Utils.ControllerNavigationDirection.DOWN &&
                focused_row == expanded_row && releases_section != null)
                return ((!) releases_section).focus_first_controller_target ();

            if (direction == Utils.ControllerNavigationDirection.UP ||
                direction == Utils.ControllerNavigationDirection.DOWN) {
                var adjacent = find_adjacent_visible_row (focused_row, direction);
                if (adjacent != null)
                    return ((!) adjacent).grab_focus ();
            }

            return focus_section_boundary (direction);
        }

        bool focus_section_boundary (Utils.ControllerNavigationDirection direction) {
            Gtk.Widget? target = null;
            if (direction == Utils.ControllerNavigationDirection.UP)
                target = controller_up_target;
            else if (direction == Utils.ControllerNavigationDirection.DOWN)
                target = controller_down_target;
            return target != null && target.get_mapped () && target.grab_focus ();
        }

        public bool controller_activate (Object focused_object) {
            var focused = focused_object as Gtk.Widget;
            if (focused == null)
                return false;
            if (focused == empty_action_button)
                return ((Gtk.Widget) empty_action_button).activate ();

            var tool_actions = releases_section?.actions_button;
            if (tool_actions != null && (focused == tool_actions || ((!) focused).is_ancestor ((!) tool_actions))) {
                tool_actions.popup ();
                return true;
            }

            var row = find_expander_row_ancestor (focused);
            if (row == null)
                return false;

            ((!) row).expanded = !((!) row).expanded;
            return true;
        }

        Adw.ExpanderRow? find_adjacent_visible_row (
            Adw.ExpanderRow row, Utils.ControllerNavigationDirection direction
        ) {
            Gtk.Widget? child = direction == Utils.ControllerNavigationDirection.UP
                ? row.get_prev_sibling () : row.get_next_sibling ();
            while (child != null) {
                if (child is Adw.ExpanderRow && is_row_focusable (child))
                    return (Adw.ExpanderRow) child;
                child = direction == Utils.ControllerNavigationDirection.UP
                    ? child.get_prev_sibling () : child.get_next_sibling ();
            }
            return null;
        }

        Adw.ExpanderRow? find_expander_row_ancestor (Gtk.Widget? widget) {
            Gtk.Widget? current = widget;
            while (current != null && current != list_box) {
                if (current is Adw.ExpanderRow)
                    return (Adw.ExpanderRow) current;
                current = current.get_parent ();
            }
            return null;
        }

        static bool is_row_focusable (Gtk.Widget row) {
            return row.visible && row.get_child_visible () && row.is_sensitive () && row.get_focusable ();
        }

        public Gtk.Widget? get_section_focus (bool last = false) {
            if (!visible)
                return null;
            if (stack.get_visible_child () == status_page)
                return empty_action_button.visible ? empty_action_button : null;

            var list = filter == Filter.INSTALLED ? installed_list : list_box;
            var child = last ? list.get_last_child () : list.get_first_child ();
            while (child != null) {
                if (child is Gtk.ListBoxRow && is_row_focusable (child))
                    return child;
                child = last ? child.get_prev_sibling () : child.get_next_sibling ();
            }
            return null;
        }

        public void set_controller_boundaries (Gtk.Widget up, Gtk.Widget? down) {
            controller_up_target = up;
            controller_down_target = down;
            var first = installed_list.get_first_child () as ReleaseRow;
            first?.set_controller_up_targets (up, up, up);
            var last = installed_list.get_last_child () as ReleaseRow;
            last?.set_controller_down_target (down);
            update_release_section_boundary ();
        }

        void update_status_page () {
            empty_action_button.set_visible (filter == Filter.USED);
            if (filter == Filter.USED)
                empty_action_button.set_label (_ ("Reset Filters"));
            switch (filter) {
                case Filter.USED:
                    status_page.set_title (_ ("No tools in use"));
                    status_page.set_description (_ ("No games currently use a tool from this group."));
                    status_page.set_icon_name ("input-gaming-symbolic");
                    break;
                default:
                    status_page.set_title (_ ("No tools found"));
                    status_page.set_description (_ ("No tools are available in this group."));
                    status_page.set_icon_name ("edit-find-symbolic");
                    break;
            }
        }

        void update_visibility () {
            if (filter == Filter.INSTALLED) {
                stack.set_visible_child_name ("installed");
                visible = installed_list.get_first_child () != null;
                return;
            }
            visible = true;
            bool has_visible = false;
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is Gtk.ListBoxRow) {
                    if (filter_func ((Gtk.ListBoxRow) child)) {
                        has_visible = true;
                        break;
                    }
                }
                child = child.get_next_sibling ();
            }

            if (has_visible) {
                stack.set_visible_child_name ("list");
            } else {
                stack.set_visible_child_name ("empty");
            }
        }

        public void refresh () {
            visibility_change_generation++;
            if (filter == Filter.INSTALLED)
                refresh_installed_rows ();
            refresh_tool_state_metadata ();
            list_box.invalidate_filter ();
            list_box.invalidate_sort ();
            update_status_page ();
            update_visibility ();
            collapse_if_hidden ();
            releases_section?.refresh_installed_rows ();
            rows_changed ();
        }

        void refresh_installed_rows () {
            var focused = get_root ()?.get_focus ();
            var focused_row = focused as ReleaseRow ?? focused?.get_ancestor (typeof (ReleaseRow)) as ReleaseRow;
            var restore_focus = focused_row != null && focused_row.get_parent () == installed_list;
            var focused_job = focused_row != null ? focused_row.get_data<Services.InstallJob> ("job") : null;
            var focused_path = focused_job?.install_location;
            installed_list.remove_all ();

            ReleaseRow? replacement = null;
            var inventory = group.installed_tool_inventory;
            foreach (var tool in group.tools) {
                var entries = inventory.get_installations_for_tool (tool);
                if (entries.is_empty)
                    continue;
                var rows_without_details = new Gee.ArrayList<ReleaseRow> ();
                foreach (var entry in entries) {
                    var row = ReleasesBox.create_installed_row (tool, entry, inventory, true);
                    connect_installed_row (this, row);
                    installed_list.append (row);
                    if (row.needs_cached_release_details ())
                        rows_without_details.add (row);
                    if (entry.path == focused_path)
                        replacement = row;
                }
                ReleasesBox.read_installed_release_details.begin (tool, rows_without_details);
            }

            if (restore_focus) {
                var target = (Gtk.Widget?) replacement ?? installed_list.get_first_child () ?? controller_up_target;
                target?.grab_focus ();
            }
            check_installed_updates ();
        }

        void check_installed_updates () {
            var generation = ++installed_update_generation;
            if (filter != Filter.INSTALLED || !get_mapped () || installed_list.get_first_child () == null)
                return;
            var service = Services.InstallationService.instance;
            foreach (var tool in service.get_update_candidates (group))
                check_tool_updates.begin (service, tool, generation);
        }

        async void check_tool_updates (Services.InstallationService service, Models.Tool tool, uint generation) {
            Gee.List<Services.AvailableToolUpdate> updates;
            var code = yield service.find_available_updates (tool, out updates);
            if (generation != installed_update_generation ||
                (code != ReturnCode.UPDATE_AVAILABLE && code != ReturnCode.NOTHING_TO_UPDATE))
                return;
            var releases_by_path = new Gee.HashMap<string, Models.Release> ();
            foreach (var update in updates)
                releases_by_path.set (update.install_location, update.release);
            for (var child = installed_list.get_first_child (); child != null; child = child.get_next_sibling ()) {
                var job = child.get_data<Services.InstallJob> ("job");
                if (job.tool == tool)
                    ((ReleaseRow) child).set_checked_update (releases_by_path.get (job.install_location));
            }
        }

        static void connect_installed_row (GroupBox group_box, ReleaseRow row) {
            var owner_ref = WeakRef (group_box);
            row.changelog_requested.connect ((job, release) => {
                var owner = owner_ref.get () as GroupBox;
                owner?.changelog_requested (job, release);
            });
            row.games_requested.connect ((job) => {
                var owner = owner_ref.get () as GroupBox;
                owner?.games_requested (job);
            });
        }

        void refresh_tool_state_metadata () {
            var child = list_box.get_first_child ();
            while (child != null) {
                var row = child as Adw.ExpanderRow;
                if (row != null) {
                    var tool = ((!) row).get_data<Models.Tool> ("tool");
                    var state_label = ((!) row).get_data<Gtk.Label> ("state-label");
                    if (tool != null && state_label != null)
                        update_tool_state_metadata ((!) row, (!) state_label, tool);
                }
                child = child.get_next_sibling ();
            }
        }

        Adw.ExpanderRow create_tool_card (Models.Tool tool) {
            var row = new Adw.ExpanderRow () {
                title = "",
                subtitle = "",
            };
            row.update_property (
                Gtk.AccessibleProperty.LABEL,
                "%s. %s".printf (tool.title, tool.description),
                -1
            );
            update_expanded_accessibility (row);

            var title_label = new Gtk.Label (tool.title) {
                halign = Gtk.Align.START,
                xalign = 0.0f,
                ellipsize = Pango.EllipsizeMode.END
            };
            var description_label = new Gtk.Label (tool.description) {
                halign = Gtk.Align.START,
                xalign = 0.0f,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                lines = 2,
                css_classes = { "subtitle", "dim-label" }
            };
            var metadata_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.START,
                margin_top = 6,
                margin_bottom = 4
            };

            var text_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                hexpand = true
            };
            text_box.append (title_label);
            text_box.append (description_label);
            text_box.append (metadata_box);

            var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                hexpand = true,
                margin_start = 12,
                margin_top = 8,
                margin_bottom = 8
            };
            content_box.append (text_box);
            row.add_prefix (content_box);

            // Keep one lightweight host per row so the reusable release section
            // can move without dynamically adding and removing expander rows.
            var release_host = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            row.set_data ("inline-release-host", release_host);
            row.add_row (release_host);
            connect_expansion (this, row, tool);

            var state_label = create_metadata_pill ("");
            row.set_data ("state-label", state_label);
            metadata_box.append (state_label);
            if (tool.niche)
                metadata_box.append (create_metadata_pill (
                    _ ("Niche"), _ ("A newer, lesser-known, or game-specific compatibility tool.")
                ));
            if (tool.legacy) {
                var obsolete_label = create_metadata_pill (
                    _ ("Obsolete"), _ ("Active maintenance has ended for this tool.")
                );
                obsolete_label.add_css_class ("tool-metadata-obsolete");
                metadata_box.append (obsolete_label);
            }
            update_tool_state_metadata (row, state_label, tool);

            return row;
        }

        Gtk.Label create_metadata_pill (string label, string? tooltip = null) {
            return new Gtk.Label (label) {
                valign = Gtk.Align.CENTER,
                ellipsize = Pango.EllipsizeMode.END,
                tooltip_text = tooltip,
                css_classes = { "tool-metadata-pill" }
            };
        }

        void on_row_expanded_changed (Adw.ExpanderRow row, Models.Tool tool) {
            update_expanded_accessibility (row);
            if (changing_expansion)
                return;

            if (row.expanded) {
                if (expanded_row != null && expanded_row != row)
                    collapse_expanded_tool (false);
                expanded_row = row;
                expanded_tool = tool;
                tool_expansion_changed (tool, true);
            } else if (expanded_row == row) {
                var root = get_root ();
                var focused = root?.get_focus ();
                var tool_actions = releases_section?.actions_button;
                bool focus_was_inside = releases_section != null && focused != null &&
                    (focused == releases_section || ((!) focused).is_ancestor ((!) releases_section)
                    || focused == tool_actions || (tool_actions != null && ((!) focused).is_ancestor ((!) tool_actions)));
                detach_release_section ();
                expanded_row = null;
                expanded_tool = null;
                if (focus_was_inside)
                    row.grab_focus ();
                tool_expansion_changed (tool, false);
            }
        }

        void update_expanded_accessibility (Adw.ExpanderRow row) {
            row.update_state (Gtk.AccessibleState.EXPANDED, row.expanded, -1);
        }

        public bool contains_tool (Models.Tool tool) {
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child.get_data<Models.Tool> ("tool") == tool)
                    return true;
                child = child.get_next_sibling ();
            }
            return false;
        }

        public bool is_expanded_tool (Models.Tool tool) {
            return expanded_tool == tool && expanded_row != null && ((!) expanded_row).expanded;
        }

        public bool expand_tool (Models.Tool tool) {
            if (!tool.is_visible_in_catalog (Globals.SETTINGS))
                return false;

            var child = list_box.get_first_child ();
            while (child != null) {
                if (child.get_data<Models.Tool> ("tool") == tool && child is Adw.ExpanderRow) {
                    var row = (Adw.ExpanderRow) child;
                    if (!row.expanded)
                        row.expanded = true;
                    else if (expanded_row != row) {
                        expanded_row = row;
                        expanded_tool = tool;
                        tool_expansion_changed (tool, true);
                    }
                    return true;
                }
                child = child.get_next_sibling ();
            }
            return false;
        }

        public void attach_release_section (Models.Tool tool, ReleasesBox section) {
            if (!is_expanded_tool (tool) || expanded_row == null)
                return;

            detach_release_section ();
            var host = ((!) expanded_row).get_data<Gtk.Box> ("inline-release-host");
            if (host == null)
                return;

            // A stale group callback must not leave the shared section parented
            // when another row takes ownership of it.
            var current_parent = section.get_parent () as Gtk.Box;
            if (current_parent != null)
                ((!) current_parent).remove (section);
            ((!) host).append (section);
            ((!) expanded_row).add_suffix (section.actions_button);
            releases_section = section;
            releases_host = host;
            section.set_controller_up_target ((!) expanded_row);
            update_release_section_boundary ();
        }

        void detach_release_section () {
            if (releases_section == null)
                return;

            var section = (!) releases_section;
            var host = releases_host;
            releases_section = null;
            releases_host = null;
            section.actions_button.popdown ();
            if (expanded_row != null && section.actions_button.is_ancestor ((!) expanded_row))
                ((!) expanded_row).remove (section.actions_button);
            if (host != null && section.get_parent () == host)
                ((!) host).remove (section);
        }

        public void collapse_expanded_tool (bool restore_focus = true) {
            if (expanded_row == null)
                return;

            var row = (!) expanded_row;
            var tool = expanded_tool;
            detach_release_section ();
            changing_expansion = true;
            row.expanded = false;
            update_expanded_accessibility (row);
            changing_expansion = false;
            expanded_row = null;
            expanded_tool = null;
            if (restore_focus)
                row.grab_focus ();
            if (tool != null)
                tool_expansion_changed ((!) tool, false);
        }

        public Gtk.Widget? get_expanded_row () {
            return expanded_row;
        }

        void collapse_if_hidden () {
            if (expanded_row == null)
                return;
            if (!filter_func ((Gtk.ListBoxRow) (!) expanded_row)) {
                var root = get_root ();
                var focused = root?.get_focus ();
                var hidden_row = (!) expanded_row;
                bool replace_focus = focused != null &&
                    (focused == hidden_row || ((!) focused).is_ancestor (hidden_row));
                collapse_expanded_tool (false);
                if (!replace_focus)
                    return;
                var expected_generation = visibility_change_generation;
                Idle.add (() => {
                    if (expected_generation != visibility_change_generation ||
                        expanded_row != null)
                        return Source.REMOVE;
                    var target = get_section_focus ();
                    if (target != null)
                        ((!) target).grab_focus ();
                    else if (controller_up_target != null)
                        ((!) controller_up_target).grab_focus ();
                    return Source.REMOVE;
                });
            }
        }

        void update_release_section_boundary () {
            if (releases_section == null || expanded_row == null)
                return;
            var next_row = find_adjacent_visible_row (
                (!) expanded_row, Utils.ControllerNavigationDirection.DOWN
            );
            ((!) releases_section).set_controller_down_target ((Gtk.Widget?) next_row ?? controller_down_target);
        }

        void update_tool_state_metadata (
            Adw.ExpanderRow row, Gtk.Label state_label, Models.Tool tool
        ) {
            var used = tool.is_used ();
            var installed = tool.is_installed ();
            if (used) {
                state_label.set_label (_ ("Used by games"));
                state_label.set_tooltip_text (_ ("At least one game is configured to use an installed release of this tool."));
                state_label.add_css_class ("tool-metadata-used");
            } else if (installed) {
                state_label.set_label (_ ("Installed"));
                state_label.set_tooltip_text (_ ("At least one release is installed for this launcher."));
                state_label.remove_css_class ("tool-metadata-used");
            }
            state_label.set_visible (installed);

            var metadata_box = state_label.get_parent ();
            var description = new StringBuilder ();
            for (var child = metadata_box.get_first_child (); child != null; child = child.get_next_sibling ()) {
                if (!child.get_visible ())
                    continue;
                if (description.len > 0)
                    description.append (", ");
                description.append (((Gtk.Label) child).label);
            }
            metadata_box.set_visible (description.len > 0);
            row.update_property (Gtk.AccessibleProperty.DESCRIPTION, description.str, -1);
        }

        bool filter_func (Gtk.ListBoxRow row) {
            var tool = row.get_data<Models.Tool> ("tool");
            if (tool == null)
            return true;

            if (!tool.is_visible_in_catalog (Globals.SETTINGS))
                return false;

            if (filter == Filter.INSTALLED)
                return false;

            if (tool is Models.Tools.SteamTinkerLaunch && !tool.is_installed ())
                return false;
            if (Globals.SETTINGS != null && !Globals.SETTINGS.get_boolean ("show-legacy-tools") && tool.legacy &&
                !(tool is Models.Tools.SteamTinkerLaunch && tool.is_installed ()))
            return false;

            if (filter == Filter.ALL)
            return true;

            if (filter == Filter.USED)
            return tool.is_used ();

            return true;
        }

        int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
            var tool1 = row1.get_data<Models.Tool> ("tool");
            var tool2 = row2.get_data<Models.Tool> ("tool");

            if (tool1 == null || tool2 == null)
                return 0;

            if (tool1.legacy != tool2.legacy)
                return tool1.legacy ? 1 : -1;
            if (!tool1.legacy && tool1.niche != tool2.niche)
                return tool1.niche ? 1 : -1;

            var tool1_installed = tool1.is_installed ();
            var tool2_installed = tool2.is_installed ();
            var tool1_used = tool1.is_used ();
            var tool2_used = tool2.is_used ();
            var result = 0;

            if (tool1_installed != tool2_installed)
                result += tool1_installed ? -1000000 : 1000000;

            result += (tool1.sort_priority - tool2.sort_priority) * 1000;

            if (tool1_used != tool2_used)
                result += tool1_used ? -1 : 1;

            if (result != 0)
                return result;

            return strcmp (tool1.title.down (), tool2.title.down ());
        }
    }
}
