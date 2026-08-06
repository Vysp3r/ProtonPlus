namespace ProtonPlus.Widgets.Tools {
    public enum Filter {
        ALL,
        INSTALLED,
        USED,
        UNUSED
    }

    public class Box : Gtk.Box {
        Models.Launcher current_launcher { get; set; }
        Services.InstallJob? current_job;

        Gtk.Stack stack { get; set; }
        Gtk.Button back_button { get; set; }
        Gtk.Button refresh_button { get; set; }
        Gtk.Button open_button { get; set; }
        Gtk.Button migrate_button { get; set; }
        Gtk.SearchEntry search_entry { get; set; }
        Gtk.MenuButton search_button { get; set; }
        Gtk.MenuButton filter_button { get; set; }
        Adw.HeaderBar header_bar { get; set; }
        Gtk.ActionBar action_bar { get; set; }
        Gtk.CheckButton all_filter_button { get; set; }
        Adw.ViewStack groups_stack { get; set; }
        ReleasesBox releases_box { get; set; }
        ReleaseBox release_box { get; set; }
        MigrateBox migrate_box { get; set; }
        Adw.ViewSwitcher switcher { get; set; }
        Adw.ViewStack center_stack { get; set; }
        ulong background_updates_changed_handler = 0;
        ulong show_legacy_tools_changed_handler = 0;

        public signal void toast_sent (string title);

        private Filter _current_filter = Filter.ALL;
        public Filter current_filter {
            get { return _current_filter; }
            set {
                _current_filter = value;
                releases_box.filter = value;
                update_filter_button_state ();

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
            releases_box.job_selected.connect ((job) => {
                set_selected_job (job);
            });

            release_box = new ReleaseBox ();

            migrate_box = new MigrateBox ();
            migrate_box.finished.connect (() => {
                if (current_job != null)
                    set_selected_job (current_job, true);
                releases_box.refresh_usage_pills ();

                var child = groups_stack.get_first_child ();
                while (child != null) {
                    if (child is GroupBox) {
                        ((GroupBox) child).refresh ();
                    }
                    child = child.get_next_sibling ();
                }
            });

            stack = new Gtk.Stack () {
                vexpand = true
            };
            stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            stack.add_named (groups_stack, "groups");
            stack.add_named (releases_box, "releases");
            stack.add_named (release_box, "release");
            stack.add_named (migrate_box, "migrate");

            back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            back_button.add_css_class ("flat");
            back_button.set_tooltip_text (_ ("Back"));
            back_button.clicked.connect (() => {
                var visible_child = stack.get_visible_child_name ();
                if (visible_child == "migrate") {
                    stack.set_visible_child_name ("release");
                } else if (visible_child == "release") {
                    stack.set_visible_child_name ("releases");
                } else {
                    stack.set_visible_child_name ("groups");
                    refresh_group_boxes ();
                }
                search_entry.set_text ("");
            });

            open_button = new Gtk.Button.from_icon_name ("globe-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            open_button.clicked.connect (() => {
                if (current_job != null && current_job.release.page_url != null) {
                    Utils.System.open_uri (current_job.release.page_url);
                }
            });

            var migrate_button_content = new Adw.ButtonContent ();
            migrate_button_content.set_label (_ ("Migrate"));
            migrate_button_content.set_icon_name ("right-left-symbolic");

            migrate_button = new Gtk.Button () {
                valign = Gtk.Align.CENTER,
                visible = false,
                child = migrate_button_content,
            };
            migrate_button.set_tooltip_text (_ ("Migrate selected games to another tool"));
            migrate_button.clicked.connect (() => {
                if (current_job == null)
                    return;
                string internal_name = "";
                if (current_job.steam_tinker_launch_context != null) {
                    internal_name = "Proton-stl";
                } else if (current_job.tool is Models.Tools.ProviderTool) {
                    internal_name = ((Models.Tools.ProviderTool)current_job.tool).get_directory_name (current_job.title);
                } else {
                    internal_name = current_job.title;
                }
                migrate_box.init (release_box.get_selected_games (), internal_name, current_launcher);
                stack.set_visible_child_name ("migrate");
            });

            switcher = new Adw.ViewSwitcher () {
                stack = groups_stack,
                policy = Adw.ViewSwitcherPolicy.WIDE
            };

            refresh_button = new Gtk.Button.from_icon_name ("update-check-symbolic") {
                valign = Gtk.Align.CENTER
            };
            refresh_button.set_tooltip_text (_ ("Check for updates"));
            refresh_button.clicked.connect (on_refresh_clicked);

            search_entry = new Gtk.SearchEntry () {
                valign = Gtk.Align.CENTER,
                placeholder_text = _ ("Search"),
                width_request = 400,
            };
            search_entry.search_changed.connect (() => {
                var search_text = search_entry.get_text ();
                releases_box.search_text = search_text;
                update_search_button_state ();

                var child = groups_stack.get_first_child ();
                while (child != null) {
                    if (child is GroupBox) {
                        ((GroupBox) child).search_text = search_text;
                    }
                    child = child.get_next_sibling ();
                }
            });

            var search_popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            search_popover_box.append (search_entry);

            var search_popover = new Gtk.Popover ();
            search_popover.set_child (search_popover_box);

            search_button = new Gtk.MenuButton () {
                valign = Gtk.Align.CENTER,
                icon_name = "magnifying-glass-symbolic",
                popover = search_popover
            };
            search_button.set_tooltip_text (_ ("Search"));
            Window.register_popover_for_controller (search_popover, search_button, search_entry);

            filter_button = new Gtk.MenuButton () {
                valign = Gtk.Align.CENTER,
                icon_name = "filter-2-symbolic"
            };
            filter_button.set_tooltip_text (_ ("Filter"));

            all_filter_button = new Gtk.CheckButton.with_label (_ ("All"));
            all_filter_button.active = true;

            var installed_filter_button = new Gtk.CheckButton.with_label (_ ("Installed"));
            installed_filter_button.set_group (all_filter_button);

            var used_filter_button = new Gtk.CheckButton.with_label (_ ("Used"));
            used_filter_button.set_group (all_filter_button);

            var unused_filter_button = new Gtk.CheckButton.with_label (_ ("Unused"));
            unused_filter_button.set_group (all_filter_button);

            var filter_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12
            };
            filter_box.append (all_filter_button);
            filter_box.append (installed_filter_button);
            filter_box.append (used_filter_button);
            filter_box.append (unused_filter_button);

            var filter_popover = new Gtk.Popover ();
            filter_popover.set_child (filter_box);
            filter_button.set_popover (filter_popover);
            Window.register_popover_for_controller (filter_popover, filter_button, all_filter_button);

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

            center_stack = new Adw.ViewStack ();
            center_stack.add_named (switcher, "groups");
            center_stack.add_named (release_box.stack_switcher, "release");
            center_stack.add_named (migrate_box.games_button, "migrate");

            var center_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                halign = Gtk.Align.CENTER
            };
            center_box.append (center_stack);

            header_bar = new Adw.HeaderBar () {
                show_start_title_buttons = false,
                show_end_title_buttons = false,
                show_title = false
            };
            header_bar.pack_start (back_button);
            header_bar.pack_end (refresh_button);
            header_bar.pack_end (releases_box.refresh_button);
            header_bar.pack_end (filter_button);
            header_bar.pack_end (search_button);
            header_bar.pack_end (open_button);
            header_bar.pack_end (migrate_button);
            header_bar.pack_end (migrate_box.migrate_button);
            header_bar.pack_end (releases_box.repository_button);
            header_bar.pack_end (releases_box.variant_box);

            action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (center_box);

            stack.notify["visible-child-name"].connect (() => {
                var visible_child = stack.get_visible_child_name ();
                back_button.set_visible (visible_child != "groups");
                search_button.set_visible (visible_child != "release" && visible_child != "migrate");
                filter_button.set_visible (visible_child != "release" && visible_child != "migrate");
                var background_updates_enabled = Globals.SETTINGS != null
                                                 && Globals.SETTINGS.get_boolean ("background-updates");
                refresh_button.set_visible (
                    visible_child != "release"
                    && visible_child != "releases"
                    && visible_child != "migrate"
                    && !background_updates_enabled
                );
                update_header_title ();
                releases_box.set_header_controls_visible (visible_child == "releases");
                migrate_box.games_button.set_visible (visible_child == "migrate");
                migrate_box.migrate_button.set_visible (visible_child == "migrate");
                update_open_button_visibility ();

                if (visible_child == "groups") {
                    center_stack.set_visible_child_name ("groups");
                    center_stack.set_visible (groups_stack.get_pages ().get_n_items () > 1);
                    action_bar.set_visible (groups_stack.get_pages ().get_n_items () > 1);
                } else if (visible_child == "release") {
                    center_stack.set_visible_child_name ("release");
                    var has_multiple_views = release_box.has_multiple_views ();
                    center_stack.set_visible (has_multiple_views);
                    action_bar.set_visible (has_multiple_views);
                } else if (visible_child == "migrate") {
                    center_stack.set_visible_child_name ("migrate");
                    center_stack.set_visible (true);
                    action_bar.set_visible (true);
                } else {
                    center_stack.set_visible (false);
                    action_bar.set_visible (false);
                }
            });

            stack.notify_property ("visible-child-name");

            groups_stack.notify["visible-child"].connect (update_header_title);

            release_box.stack_switcher.stack.notify["visible-child-name"].connect (() => {
                update_open_button_visibility ();
            });

            release_box.selection_changed.connect (() => {
                update_open_button_visibility ();
            });

            append (header_bar);
            append (stack);
            append (action_bar);

            if (Globals.SETTINGS != null) {
                background_updates_changed_handler = Globals.SETTINGS.changed["background-updates"].connect (update_refresh_button_visibility);
                show_legacy_tools_changed_handler = Globals.SETTINGS.changed["show-legacy-tools"].connect (refresh_groups_for_legacy_tools);
            }
        }

        public override void dispose () {
            if (Globals.SETTINGS != null) {
                if (background_updates_changed_handler != 0) {
                    Globals.SETTINGS.disconnect (background_updates_changed_handler);
                    background_updates_changed_handler = 0;
                }

                if (show_legacy_tools_changed_handler != 0) {
                    Globals.SETTINGS.disconnect (show_legacy_tools_changed_handler);
                    show_legacy_tools_changed_handler = 0;
                }
            }

            base.dispose ();
        }

        void update_refresh_button_visibility () {
            stack.notify_property ("visible-child-name");
        }

        void update_search_button_state () {
            if (search_entry.get_text () != "") {
                search_button.add_css_class ("tools-filter-active");
                search_button.set_tooltip_text (_ ("Search is active"));
            } else {
                search_button.remove_css_class ("tools-filter-active");
                search_button.set_tooltip_text (_ ("Search"));
            }
        }

        void update_filter_button_state () {
            if (current_filter != Filter.ALL) {
                filter_button.add_css_class ("tools-filter-active");
                filter_button.set_tooltip_text (_ ("Filter is active"));
            } else {
                filter_button.remove_css_class ("tools-filter-active");
                filter_button.set_tooltip_text (_ ("Filter"));
            }
        }

        void update_header_title () {
            Gtk.Widget? title_widget = null;
            var visible_child = stack.get_visible_child_name ();

            if (visible_child == "groups") {
                var group_box = groups_stack.get_visible_child () as GroupBox;
                if (group_box != null)
                    title_widget = group_box.header_title;
            } else if (visible_child == "releases") {
                title_widget = releases_box.header_title;
            } else if (visible_child == "release") {
                title_widget = release_box.header_box;
            }

            header_bar.set_title_widget (title_widget);
            header_bar.set_show_title (title_widget != null);
        }

        void refresh_groups_for_legacy_tools () {
            var child = groups_stack.get_first_child ();
            while (child != null) {
                if (child is GroupBox)
                    ((GroupBox) child).refresh ();
                child = child.get_next_sibling ();
            }
        }

        void update_open_button_visibility () {
            var visible_child = stack.get_visible_child_name ();
            if (current_job != null && current_job.release.page_url != null)
                open_button.set_tooltip_text (current_job.release.page_url);
            else
                open_button.set_tooltip_text (null);
            open_button.set_visible (
                visible_child == "release"
                && current_job != null
                && current_job.release.page_url != null
            );
            migrate_button.set_visible (
                visible_child == "release"
                && release_box.stack_switcher.stack.visible_child_name == "games"
                && release_box.get_selected_games_count () > 0
            );
        }

        void refresh_group_boxes () {
            var child = groups_stack.get_first_child ();
            while (child != null) {
                if (child is GroupBox) {
                    ((GroupBox) child).refresh ();
                }
                child = child.get_next_sibling ();
            }
        }

        public void show_groups_page () {
            stack.set_visible_child_name ("groups");
            search_entry.set_text ("");
            all_filter_button.active = true;
            refresh_group_boxes ();
        }

        public void show_download (Services.InstallJob job) {
            stack.set_visible_child_name ("releases");
            releases_box.focus_job.begin (job);
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            current_launcher = launcher;

            Gtk.Widget? child;
            while ((child = groups_stack.get_first_child ()) != null) {
                groups_stack.remove (child);
            }

            foreach (var group in launcher.groups) {
                var group_box = new GroupBox (group);
                group_box.filter = current_filter;
                group_box.search_text = search_entry.get_text ();
                group_box.tool_selected.connect (set_selected_tool);
                groups_stack.add_titled_with_icon (group_box, group.title.down (), group.title, "layer-group-symbolic");
            }

            stack.notify_property ("visible-child-name");

            stack.set_visible_child_name ("groups");
        }

        void set_selected_tool (Models.Tool tool) {
            releases_box.set_selected_tool.begin (tool);

            stack.set_visible_child_name ("releases");
        }

        void set_selected_job (Services.InstallJob job, bool show_games = false) {
            current_job = job;

            release_box.set_selected_job (job, show_games);

            stack.set_visible_child_name ("release");
        }

        void on_refresh_clicked () {
            check_for_updates.begin ();
        }

        async void check_for_updates () {
            refresh_button.sensitive = false;
            toast_sent (_ ("Checking for updates"));

            var launchers = new List<Models.Launcher> ();
            launchers.append (current_launcher);
            var code = yield Services.InstallationService.instance.check_for_updates (launchers);

            switch (code) {
                case ReturnCode.RUNNERS_IN_USE:
                    toast_sent (_ ("Can't update while a game is running"));
                    break;
                case ReturnCode.NOTHING_TO_UPDATE:
                    toast_sent (_ ("Nothing to update"));
                    break;
                case ReturnCode.RUNNERS_UPDATED:
                case ReturnCode.RUNNER_UPDATED:
                    toast_sent (_ ("Everything is now up-to-date"));
                    break;
                default:
                    toast_sent (_ ("Couldn't check for updates (Reason: %s)").printf (get_return_code_message (code)));
                    break;
            }

            refresh_button.sensitive = true;
        }
    }
}
