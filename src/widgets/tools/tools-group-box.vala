namespace ProtonPlus.Widgets.Tools {
    public class GroupBox : Gtk.Box {
        public signal void tool_selected (Models.Tool tool);
        Gtk.ListBox list_box;
        Gtk.Stack stack;
        Adw.StatusPage status_page;

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

        public GroupBox (Models.Group group) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

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

            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (icon);
            header_box.append (title_box);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-tools-card");
            list_box.set_filter_func (filter_func);

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

            var group_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            group_box.append (header_box);
            group_box.append (stack);

            var clamp = new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 5,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                child = group_box,
            };

            append (clamp);

            update_visibility ();
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

        Adw.ActionRow create_tool_card (Models.Tool tool) {
            var icon = new Gtk.Image.from_icon_name ("screwdriver-wrench-symbolic");

            var row = new Adw.ActionRow () {
                title = tool.title,
                subtitle = tool.description,
                activatable = true,
            };
            row.activated.connect (() => tool_selected (tool));
            row.add_prefix (icon);

            return row;
        }

        bool filter_func (Gtk.ListBoxRow row) {
            var tool = row.get_data<Models.Tool> ("tool");
            if (tool == null)
            return true;

            if (search_text != "" && !tool.title.down ().contains (search_text.down ()))
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
    }
}