namespace ProtonPlus.Widgets.Tools {
    public class Box : Gtk.Box {
        Models.Launcher current_launcher { get; set; }

        Adw.ViewStack stack { get; set; }
        Gtk.Button back_button { get; set; }
        Adw.ViewStack groups_stack { get; set; }
        ReleasesBox releases_box { get; set; }

        public Box () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            groups_stack = new Adw.ViewStack () {
                vexpand = true
            };

            releases_box = new ReleasesBox ();

            stack = new Adw.ViewStack () {
                vexpand = true
            };
            stack.add_named (groups_stack, "groups");
            stack.add_named (releases_box, "releases");

            back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            back_button.add_css_class ("flat");
            back_button.set_tooltip_text (_ ("Back"));
            back_button.clicked.connect (() => {
                stack.set_visible_child_name ("groups");
            });

            var switcher = new Adw.ViewSwitcher () {
                stack = groups_stack,
                policy = Adw.ViewSwitcherPolicy.WIDE
            };

            var refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                valign = Gtk.Align.CENTER
            };
            refresh_button.set_tooltip_text (_ ("Check for updates"));
            refresh_button.clicked.connect (on_refresh_clicked);

            var action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (switcher);
            action_bar.pack_start (back_button);
            action_bar.pack_end (refresh_button);

            stack.notify["visible-child-name"].connect (() => {
                back_button.set_visible (stack.get_visible_child_name () == "releases");
                switcher.set_visible (stack.get_visible_child_name () == "groups");
            });

            append (stack);
            append (action_bar);
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            current_launcher = launcher;

            var child = groups_stack.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                groups_stack.remove (child);
                child = next;
            }

            foreach (var group in launcher.groups) {
                var group_box = new GroupBox(group);
                group_box.tool_selected.connect (set_selected_tool);
                groups_stack.add_titled_with_icon (group_box, group.title.down (), group.title, "layer-group-symbolic");
            }

            stack.set_visible_child_name ("groups");
        }

        void set_selected_tool (Models.Tool tool) {
            releases_box.set_selected_tool.begin (tool);

            stack.set_visible_child_name ("releases");
        }

        void on_refresh_clicked () {
            check_for_updates.begin ();
        }

        async void check_for_updates () {
            var launchers = new List<Models.Launcher> ();
            launchers.append (current_launcher);
            yield Models.Tool.check_for_updates (launchers);
        }
    }
}