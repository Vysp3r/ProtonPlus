namespace ProtonPlus.Widgets.Tools {
    public enum Filter {
        ALL,
        INSTALLED,
        USED,
        UNUSED
    }

    public class Box : Gtk.Box {
        Models.Launcher current_launcher { get; set; }
        Models.Release? current_release;

        Adw.ViewStack stack { get; set; }
        Gtk.Button back_button { get; set; }
        Gtk.Button open_button { get; set; }
        Adw.ViewStack groups_stack { get; set; }
        ReleasesBox releases_box { get; set; }
        ReleaseBox release_box { get; set; }

        private Filter _current_filter = Filter.ALL;
        public Filter current_filter {
            get { return _current_filter; }
            set {
                _current_filter = value;
                releases_box.filter = value;

                var child = groups_stack.get_first_child ();
                while (child != null) {
                    if (child is GroupBox) {
                        ((GroupBox)child).filter = value;
                    }
                    child = child.get_next_sibling ();
                }
            }
        }

        public Box () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            groups_stack = new Adw.ViewStack () {
                vexpand = true
            };

            releases_box = new ReleasesBox ();
            releases_box.release_selected.connect (set_selected_release);

            release_box = new ReleaseBox ();

            stack = new Adw.ViewStack () {
                vexpand = true
            };
            stack.add_named (groups_stack, "groups");
            stack.add_named (releases_box, "releases");
            stack.add_named (release_box, "release");

            back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            back_button.add_css_class ("flat");
            back_button.set_tooltip_text (_ ("Back"));
            back_button.clicked.connect (() => {
                stack.set_visible_child_name (stack.get_visible_child_name () == "release" ? "releases" : "groups");
            });

            open_button = new Gtk.Button.from_icon_name ("globe-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            open_button.set_tooltip_text (_ ("Open in browser"));
            open_button.clicked.connect (() => {
                if (current_release != null && current_release.page_url != null) {
                    Utils.System.open_uri (current_release.page_url);
                }
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

            var filter_button = new Gtk.MenuButton () {
                valign = Gtk.Align.CENTER,
                icon_name = "filter-2-symbolic"
            };
            filter_button.set_tooltip_text (_ ("Filter"));

            var all_filter_button = new Gtk.CheckButton.with_label (_ ("All"));
            all_filter_button.active = true;

            var installed_filter_button = new Gtk.CheckButton.with_label (_ ("Installed"));
            installed_filter_button.set_group (all_filter_button);

            var used_filter_button = new Gtk.CheckButton.with_label (_ ("Used"));
            used_filter_button.set_group (all_filter_button);

            var unused_filter_button = new Gtk.CheckButton.with_label (_ ("Unused"));
            unused_filter_button.set_group (all_filter_button);

            var filter_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10) {
                margin_top = 10,
                margin_bottom = 10,
                margin_start = 10,
                margin_end = 10
            };
            filter_box.append (all_filter_button);
            filter_box.append (installed_filter_button);
            filter_box.append (used_filter_button);
            filter_box.append (unused_filter_button);

            var filter_popover = new Gtk.Popover ();
            filter_popover.set_child (filter_box);
            filter_button.set_popover (filter_popover);

            all_filter_button.toggled.connect (() => {
                if (all_filter_button.active) {
                    current_filter = Filter.ALL;
                    filter_popover.popdown ();
                }
            });

            installed_filter_button.toggled.connect (() => {
                if (installed_filter_button.active) {
                    current_filter = Filter.INSTALLED;
                    filter_popover.popdown ();
                }
            });

            used_filter_button.toggled.connect (() => {
                if (used_filter_button.active) {
                    current_filter = Filter.USED;
                    filter_popover.popdown ();
                }
            });

            unused_filter_button.toggled.connect (() => {
                if (unused_filter_button.active) {
                    current_filter = Filter.UNUSED;
                    filter_popover.popdown ();
                }
            });

            var action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (switcher);
            action_bar.pack_start (back_button);
            action_bar.pack_end (refresh_button);
            action_bar.pack_end (filter_button);
            action_bar.pack_end (open_button);

            stack.notify["visible-child-name"].connect (() => {
                back_button.set_visible (stack.get_visible_child_name () != "groups");
                filter_button.set_visible (stack.get_visible_child_name () != "release");
                refresh_button.set_visible (stack.get_visible_child_name () != "release");
                open_button.set_visible (stack.get_visible_child_name () == "release" && current_release != null && current_release.page_url != null);
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
                group_box.filter = current_filter;
                group_box.tool_selected.connect (set_selected_tool);
                groups_stack.add_titled_with_icon (group_box, group.title.down (), group.title, "layer-group-symbolic");
            }

            stack.set_visible_child_name ("groups");
        }

        void set_selected_tool (Models.Tool tool) {
            releases_box.set_selected_tool.begin (tool);

            stack.set_visible_child_name ("releases");
        }

        void set_selected_release (Models.Release release) {
            current_release = release;

            release_box.set_selected_release (release);

            stack.set_visible_child_name ("release");
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