namespace ProtonPlus.Widgets.Tools {
    public class GroupBox : Gtk.Box, Utils.ControllerDirectionalFocus,
        Utils.ControllerActivationHandler {
        public signal void tool_expansion_changed (Models.Tool tool, bool expanded);
        public signal void clear_search_requested ();
        public signal void reset_filter_requested ();
        public Gtk.Box header_title { get; private set; }
        public Gtk.Box header_actions { get; private set; }
        Gtk.ListBox list_box;
        Gtk.ScrolledWindow scrolled;
        Gtk.Stack stack;
        Adw.StatusPage status_page;
        Gtk.Button empty_action_button;
        weak Gtk.Widget? controller_up_target;
        Adw.ExpanderRow? expanded_row;
        Models.Tool? expanded_tool;
        ReleasesBox? releases_section;
        Gtk.Box? releases_host;
        bool changing_expansion = false;
        uint visibility_change_generation = 0;

        private Filter _filter = Filter.ALL;
        public Filter filter {
            get { return _filter; }
            set {
                visibility_change_generation++;
                _filter = value;
                list_box.invalidate_filter ();
                update_status_page ();
                update_visibility ();
                collapse_if_hidden ();
                update_release_section_boundary ();
            }
        }

        private string _search_text = "";
        public string search_text {
            get { return _search_text; }
            set {
                visibility_change_generation++;
                _search_text = value;
                list_box.invalidate_filter ();
                update_status_page ();
                update_visibility ();
                collapse_if_hidden ();
                update_release_section_boundary ();
            }
        }

        public GroupBox (Models.Group group, Gtk.Widget? controller_up_target = null) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            this.controller_up_target = controller_up_target;

            // Build this once before Gtk begins repeatedly invoking the filter
            // and comparator callbacks below.
            group.refresh_installed_state ();

            var icon = new Gtk.Image.from_icon_name ("layer-group-symbolic");

            var title_label = new Gtk.Label (group.title) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            var desc_label = new Gtk.Label (group.description) {
                halign = Gtk.Align.START,
                css_classes = { "caption" },
                wrap = true,
                xalign = 0
            };

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            title_box.append (title_label);
            title_box.append (desc_label);

            header_title = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true,
                margin_start = 12
            };
            header_title.append (icon);
            header_title.append (title_box);

            header_actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var collection_toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true
            };
            collection_toolbar.add_css_class ("tools-collection-toolbar");
            collection_toolbar.append (header_title);
            collection_toolbar.append (header_actions);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                valign = Gtk.Align.START
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-tools-card");
            list_box.set_filter_func (filter_func);
            list_box.set_sort_func (sort_func);

            group.installed_tool_index_invalidated.connect (() => {
                group.refresh_installed_state ();
            });
            group.installed_state_refreshed.connect (() => refresh ());

            scrolled = new Gtk.ScrolledWindow () {
                child = list_box,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                overflow = Gtk.Overflow.HIDDEN
            };

            status_page = new Adw.StatusPage () {
                title = _ ("No tools found"),
                description = _ ("No tools match the current filter."),
                icon_name = "edit-find-symbolic"
            };
            empty_action_button = new Gtk.Button () {
                halign = Gtk.Align.CENTER,
                visible = false
            };
            empty_action_button.add_css_class ("suggested-action");
            empty_action_button.clicked.connect (() => {
                if (search_text.strip () != "")
                    clear_search_requested ();
                else if (filter != Filter.ALL)
                    reset_filter_requested ();
            });
            status_page.set_child (empty_action_button);

            stack = new Gtk.Stack () {
                vexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };
            stack.add_named (scrolled, "list");
            stack.add_named (status_page, "empty");

            foreach (var tool in group.tools) {
                var row = create_tool_card (tool);
                row.set_data ("tool", tool);
                list_box.append (row);

            }

            list_box.invalidate_sort ();

            var group_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            group_box.append (collection_toolbar);
            group_box.append (stack);

            var clamp = new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                child = group_box,
            };

            append (clamp);

            update_visibility ();
        }

        public bool controller_focus_direction (
            Object focused_object, Utils.ControllerNavigationDirection direction
        ) {
            var focused = focused_object as Gtk.Widget;
            var focused_row = find_expander_row_ancestor (focused);
            if (focused_row == null)
                return false;

            bool in_release_section = releases_section != null && focused != null &&
                (focused == releases_section || ((!) focused).is_ancestor ((!) releases_section));
            if (in_release_section)
                return false;

            var actions_button = focused_row.get_data<Gtk.MenuButton> (
                "tool-actions-button"
            );
            bool in_header_actions = actions_button != null && focused != null &&
                (focused == actions_button ||
                 ((!) focused).is_ancestor ((!) actions_button));
            if (in_header_actions)
                return focus_from_header_actions (
                    focused_row, (!) actions_button, direction
                );

            if (direction == Utils.ControllerNavigationDirection.RIGHT &&
                actions_button != null && ((!) actions_button).get_mapped () &&
                ((!) actions_button).is_visible () &&
                ((!) actions_button).is_sensitive () &&
                ((!) actions_button).get_can_focus ())
                return ((!) actions_button).grab_focus ();

            if (direction == Utils.ControllerNavigationDirection.LEFT) {
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

            if (direction != Utils.ControllerNavigationDirection.UP ||
                focused_row != find_first_visible_row ())
                return false;

            return controller_up_target != null &&
                ((!) controller_up_target).get_mapped () &&
                ((!) controller_up_target).is_visible () &&
                ((!) controller_up_target).is_sensitive () &&
                ((!) controller_up_target).grab_focus ();
        }

        bool focus_from_header_actions (
            Adw.ExpanderRow row, Gtk.MenuButton actions_button,
            Utils.ControllerNavigationDirection direction
        ) {
            if (direction == Utils.ControllerNavigationDirection.LEFT)
                return row.grab_focus ();
            if (direction == Utils.ControllerNavigationDirection.RIGHT)
                return actions_button.grab_focus ();
            if (direction == Utils.ControllerNavigationDirection.DOWN &&
                row == expanded_row && releases_section != null)
                return ((!) releases_section).focus_first_controller_target ();
            if (direction != Utils.ControllerNavigationDirection.UP &&
                direction != Utils.ControllerNavigationDirection.DOWN)
                return false;

            var adjacent = find_adjacent_visible_row (row, direction);
            if (adjacent != null)
                return ((!) adjacent).grab_focus ();
            return direction == Utils.ControllerNavigationDirection.UP &&
                controller_up_target != null &&
                ((!) controller_up_target).get_mapped () &&
                ((!) controller_up_target).is_visible () &&
                ((!) controller_up_target).is_sensitive () &&
                ((!) controller_up_target).grab_focus ();
        }

        public bool controller_activate (Object focused_object) {
            var focused = focused_object as Gtk.Widget;
            var row = find_expander_row_ancestor (focused);
            if (row == null || focused == null)
                return false;

            var actions_button = ((!) row).get_data<Gtk.MenuButton> (
                "tool-actions-button"
            );
            if (actions_button != null &&
                (focused == actions_button ||
                 ((!) focused).is_ancestor ((!) actions_button))) {
                ((!) actions_button).popup ();
                return true;
            }

            ((!) row).expanded = !((!) row).expanded;
            return true;
        }

        Adw.ExpanderRow? find_adjacent_visible_row (
            Adw.ExpanderRow row, Utils.ControllerNavigationDirection direction
        ) {
            Gtk.Widget? child = direction == Utils.ControllerNavigationDirection.UP
                ? row.get_prev_sibling () : row.get_next_sibling ();
            while (child != null) {
                if (child is Adw.ExpanderRow && child.get_mapped () &&
                    child.is_visible () && child.get_child_visible () &&
                    child.is_sensitive () && child.get_focusable ())
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

        Gtk.ListBoxRow? find_first_visible_row () {
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is Gtk.ListBoxRow && child.get_mapped () &&
                    child.is_visible () && child.get_child_visible () &&
                    child.is_sensitive () && child.get_focusable ())
                    return (Gtk.ListBoxRow) child;
                child = child.get_next_sibling ();
            }
            return null;
        }

        public Object? get_controller_initial_focus () {
            var row = find_first_visible_row ();
            if (row != null)
                return row;
            return empty_action_button.visible ? empty_action_button : null;
        }

        public void clear_header_actions () {
            Gtk.Widget? child;
            while ((child = header_actions.get_first_child ()) != null)
                header_actions.remove ((!) child);
        }

        public void populate_header_actions (
            Gtk.Widget refresh, Gtk.Widget filter, Gtk.Widget search
        ) {
            clear_header_actions ();
            header_actions.append (refresh);
            header_actions.append (filter);
            header_actions.append (search);
        }

        void update_status_page () {
            if (search_text.strip () != "") {
                status_page.set_title (_ ("No matching tools"));
                status_page.set_description (_ ("Try a different search term or clear the search."));
                status_page.set_icon_name ("edit-find-symbolic");
                empty_action_button.set_label (_ ("Clear Search"));
                empty_action_button.set_visible (true);
                return;
            }

            empty_action_button.set_visible (filter != Filter.ALL);
            if (filter != Filter.ALL)
                empty_action_button.set_label (_ ("Reset Filters"));
            switch (filter) {
                case Filter.INSTALLED:
                    status_page.set_title (_ ("No installed tools"));
                    status_page.set_description (_ ("Install a compatibility tool to see it here."));
                    status_page.set_icon_name ("box-open-symbolic");
                    break;
                case Filter.USED:
                    status_page.set_title (_ ("No tools in use"));
                    status_page.set_description (_ ("No games currently use a tool from this group."));
                    status_page.set_icon_name ("gamepad2-symbolic");
                    break;
                case Filter.UNUSED:
                    status_page.set_title (_ ("No unused tools"));
                    status_page.set_description (_ ("Every tool in this group is currently in use."));
                    status_page.set_icon_name ("check-round-outline-symbolic");
                    break;
                default:
                    status_page.set_title (_ ("No tools found"));
                    status_page.set_description (_ ("No tools are available in this group."));
                    status_page.set_icon_name ("edit-find-symbolic");
                    break;
            }
        }

        void update_visibility () {
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
            refresh_tool_state_metadata ();
            list_box.invalidate_filter ();
            list_box.invalidate_sort ();
            update_status_page ();
            update_visibility ();
            collapse_if_hidden ();
            update_release_section_boundary ();
        }

        void refresh_tool_state_metadata () {
            var child = list_box.get_first_child ();
            while (child != null) {
                var row = child as Adw.ExpanderRow;
                if (row != null) {
                    var tool = ((!) row).get_data<Models.Tool> ("tool");
                    var state_label = ((!) row).get_data<Gtk.Label> ("state-label");
                    if (tool != null && state_label != null)
                        update_tool_state_metadata ((!) state_label, tool);
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

            var actions_button = new Gtk.MenuButton () {
                icon_name = "view-more-symbolic",
                valign = Gtk.Align.CENTER,
                visible = false,
                tooltip_text = _("Tool Actions")
            };
            actions_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                "%s — %s".printf (_("Tool Actions"), tool.title),
                -1
            );
            row.set_data ("tool-actions-button", actions_button);
            var actions_header_host = new Gtk.Box (
                Gtk.Orientation.HORIZONTAL, 0
            ) {
                visible = false,
                valign = Gtk.Align.CENTER
            };
            actions_header_host.append (actions_button);
            row.set_data ("tool-actions-header-host", actions_header_host);
            row.add_suffix (actions_header_host);

            // Keep one lightweight host per row so the reusable release section
            // can move without dynamically adding and removing expander rows.
            var release_host = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            row.set_data ("inline-release-host", release_host);
            row.add_row (release_host);
            row.notify["expanded"].connect (() => on_row_expanded_changed (row, tool));

            if (tool is Models.Tools.ProviderTool) {
                var provider_tool = (Models.Tools.ProviderTool) tool;
                if (provider_tool.tag != null && provider_tool.tag != "") {
                    var tag_label = new Gtk.Label (
                        Utils.safe_translate (provider_tool.tag)
                    ) {
                        valign = Gtk.Align.CENTER,
                        css_classes = { "tool-metadata-pill" }
                    };
                    if (provider_tool.tag == "Recommended")
                        tag_label.set_tooltip_text (
                            _ ("Recommended compatibility tool")
                        );

                    metadata_box.append (tag_label);
                }

            }

            var state_label = new Gtk.Label ("") {
                valign = Gtk.Align.CENTER,
                css_classes = { "tool-metadata-pill" }
            };
            row.set_data ("state-label", state_label);
            metadata_box.append (state_label);
            update_tool_state_metadata (state_label, tool);

            return row;
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
                bool focus_was_inside = releases_section != null && focused != null &&
                    (((!) focused) == releases_section ||
                     ((!) focused).is_ancestor ((!) releases_section));
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
            releases_section = section;
            releases_host = host;
            var actions_button = ((!) expanded_row).get_data<Gtk.MenuButton> (
                "tool-actions-button"
            );
            var actions_header_host = ((!) expanded_row).get_data<Gtk.Box> (
                "tool-actions-header-host"
            );
            if (actions_button != null && actions_header_host != null)
                section.attach_actions_button (
                    (!) actions_header_host, (!) actions_button
                );
            section.set_controller_up_target ((!) expanded_row);
            section.set_controller_down_target (find_adjacent_visible_row (
                (!) expanded_row, Utils.ControllerNavigationDirection.DOWN
            ));
        }

        void detach_release_section () {
            if (releases_section == null)
                return;

            var section = (!) releases_section;
            var host = releases_host;
            releases_section = null;
            releases_host = null;
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

        public double get_scroll_position () {
            return scrolled.get_vadjustment ().get_value ();
        }

        public void restore_scroll_position (double position) {
            Idle.add (() => {
                var adjustment = scrolled.get_vadjustment ();
                var maximum = double.max (
                    adjustment.lower, adjustment.upper - adjustment.page_size
                );
                adjustment.set_value (double.min (
                    maximum, double.max (adjustment.lower, position)
                ));
                return Source.REMOVE;
            });
        }

        public void focus_release_widget (Gtk.Widget widget, bool center = true) {
            widget.grab_focus ();
            if (!center)
                return;
            Idle.add (() => {
                Graphene.Rect bounds;
                if (widget.compute_bounds (list_box, out bounds)) {
                    var adjustment = scrolled.get_vadjustment ();
                    var maximum = double.max (adjustment.lower,
                        adjustment.upper - adjustment.page_size);
                    var value = bounds.origin.y -
                        ((adjustment.page_size - bounds.size.height) / 2.0);
                    adjustment.set_value (double.min (maximum,
                        double.max (adjustment.lower, value)));
                }
                return Source.REMOVE;
            });
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
                    var target = find_first_visible_row ();
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
            ((!) releases_section).set_controller_down_target (find_adjacent_visible_row (
                (!) expanded_row, Utils.ControllerNavigationDirection.DOWN
            ));
        }

        void update_tool_state_metadata (
            Gtk.Label state_label, Models.Tool tool
        ) {
            if (tool.is_used ()) {
                state_label.set_label (_ ("Used by games"));
                state_label.set_tooltip_text (_ ("One or more releases of this tool is installed and currently used by one or more games"));
                state_label.set_visible (true);
            } else if (tool.is_installed ()) {
                state_label.set_label (_ ("Installed"));
                state_label.set_tooltip_text (_ ("One or more releases of this tool is installed, but not currently used by any games"));
                state_label.set_visible (true);
            } else {
                state_label.set_visible (false);
            }

            var metadata_box = state_label.get_parent () as Gtk.Box;
            if (metadata_box == null)
                return;
            bool has_visible_metadata = false;
            var child = ((!) metadata_box).get_first_child ();
            while (child != null) {
                if (child.get_visible ()) {
                    has_visible_metadata = true;
                    break;
                }
                child = child.get_next_sibling ();
            }
            ((!) metadata_box).set_visible (has_visible_metadata);
        }

        bool filter_func (Gtk.ListBoxRow row) {
            var tool = row.get_data<Models.Tool> ("tool");
            if (tool == null)
            return true;

            var expanded = tool == expanded_tool && releases_section != null;
            var has_release_match = expanded &&
                ((!) releases_section).has_release_title_match (search_text);
            if (!InlineReleaseInteractionState.matches_filter (
                search_text, tool.title, expanded, has_release_match
            ))
                return false;

            if (Globals.SETTINGS != null && !Globals.SETTINGS.get_boolean ("show-legacy-tools") && tool.legacy)
            return false;

            if (filter == Filter.ALL)
            return true;

            if (filter == Filter.INSTALLED)
            return tool.is_installed ();

            if (filter == Filter.USED)
            return tool.is_used ();

            if (filter == Filter.UNUSED)
            return !tool.is_used ();

            return true;
        }

        int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
            var tool1 = row1.get_data<Models.Tool> ("tool");
            var tool2 = row2.get_data<Models.Tool> ("tool");

            if (tool1 == null || tool2 == null)
                return 0;

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
