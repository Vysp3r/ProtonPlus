namespace ProtonPlus.Widgets.Tools {
    public class GroupBox : Gtk.Box {
        public signal void tool_selected (Models.Tool tool);
        public Gtk.Box header_title { get; private set; }
        Gtk.ListBox list_box;
        Gtk.Stack stack;
        Adw.StatusPage status_page;

        private Filter _filter = Filter.ALL;
        public Filter filter {
            get { return _filter; }
            set {
                _filter = value;
                list_box.invalidate_filter ();
                update_status_page ();
                update_visibility ();
            }
        }

        private string _search_text = "";
        public string search_text {
            get { return _search_text; }
            set {
                _search_text = value;
                list_box.invalidate_filter ();
                update_status_page ();
                update_visibility ();
            }
        }

        public GroupBox (Models.Group group) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

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

            header_title = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_title.append (icon);
            header_title.append (title_box);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-tools-card");
            list_box.set_filter_func (filter_func);
            list_box.set_sort_func (sort_func);

            group.installed_tool_index_invalidated.connect (() => {
                group.refresh_installed_state ();
            });
            group.installed_state_refreshed.connect (() => refresh ());

            var scrolled = new Gtk.ScrolledWindow () {
                child = list_box,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                overflow = Gtk.Overflow.HIDDEN
            };

            status_page = new Adw.StatusPage () {
                title = _ ("No tools found"),
                description = _ ("No tools match the current filter."),
                icon_name = "magnifying-glass-symbolic"
            };

            stack = new Gtk.Stack () {
                vexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };
            stack.add_css_class ("card");
            stack.add_named (scrolled, "list");
            stack.add_named (status_page, "empty");

            foreach (var tool in group.tools) {
                var row = create_tool_card (tool);
                row.set_data ("tool", tool);
                list_box.append (row);

            }

            list_box.invalidate_sort ();

            var group_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
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

        void update_status_page () {
            if (search_text.strip () != "") {
                status_page.set_title (_ ("No matching tools"));
                status_page.set_description (_ ("Try a different search term or clear the search."));
                status_page.set_icon_name ("magnifying-glass-symbolic");
                return;
            }

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
                    status_page.set_icon_name ("magnifying-glass-symbolic");
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
            refresh_tool_state_pills ();
            list_box.invalidate_filter ();
            list_box.invalidate_sort ();
            update_status_page ();
            update_visibility ();
        }

        void refresh_tool_state_pills () {
            var child = list_box.get_first_child ();
            while (child != null) {
                var row = child as Adw.ActionRow;
                if (row != null) {
                    var tool = row.get_data<Models.Tool> ("tool");
                    var state_pill = row.get_data<Gtk.Label> ("state-pill");
                    if (tool != null && state_pill != null)
                        update_tool_state_pill (state_pill, tool);
                }
                child = child.get_next_sibling ();
            }
        }

        Adw.ActionRow create_tool_card (Models.Tool tool) {
            var icon = new Gtk.Image.from_icon_name ("screwdriver-wrench-symbolic");

            var row = new Adw.ActionRow () {
                title = tool.title,
                subtitle = tool.description,
                activatable = true,
            };
            row.activated.connect (() => tool_selected (tool));
            row.add_prefix (icon);

            if (tool is Models.Tools.ProviderTool) {
                var provider_tool = (Models.Tools.ProviderTool) tool;
                if (provider_tool.tag != null && provider_tool.tag != "") {
                    var pill = new Gtk.Label (Utils.safe_translate (provider_tool.tag));
                    pill.add_css_class ("tag-pill");
                    pill.set_valign (Gtk.Align.CENTER);
                    if (provider_tool.tag == "Recommended")
                        pill.set_tooltip_text (_ ("Recommended compatibility tool"));

                    row.add_suffix (pill);
                }

            }

            var state_pill = new Gtk.Label ("");
            state_pill.set_valign (Gtk.Align.CENTER);
            row.set_data ("state-pill", state_pill);
            row.add_suffix (state_pill);
            update_tool_state_pill (state_pill, tool);

            return row;
        }

        void update_tool_state_pill (Gtk.Label pill, Models.Tool tool) {
            pill.remove_css_class ("installed-pill");
            pill.remove_css_class ("in-use-pill");

            if (tool.is_used ()) {
                pill.set_label (_ ("In use"));
                pill.set_tooltip_text (_ ("One or more releases of this tool is installed and currently used by one or more games"));
                pill.add_css_class ("in-use-pill");
                pill.set_visible (true);
            } else if (tool.is_installed ()) {
                pill.set_label (_ ("Installed"));
                pill.set_tooltip_text (_ ("One or more releases of this tool is installed, but not currently used by any games"));
                pill.add_css_class ("installed-pill");
                pill.set_visible (true);
            } else {
                pill.set_visible (false);
            }
        }

        bool filter_func (Gtk.ListBoxRow row) {
            var tool = row.get_data<Models.Tool> ("tool");
            if (tool == null)
            return true;

            if (search_text != "" && !tool.title.down ().contains (search_text.down ()))
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
