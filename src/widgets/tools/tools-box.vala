namespace ProtonPlus.Widgets.Tools {
    public enum Filter {
        ALL,
        INSTALLED,
        USED,
        UNUSED
    }

    public class Box : Gtk.Box, Utils.ControllerNavigationHost,
        Utils.ControllerPageShortcuts {
        Models.Launcher current_launcher { get; set; }
        Services.InstallJob? current_job;

        Adw.NavigationView navigation_view { get; set; }
        Adw.NavigationPage groups_page { get; set; }
        Adw.NavigationPage release_page { get; set; }
        Adw.NavigationPage migrate_page { get; set; }
        Gtk.Button refresh_button { get; set; }
        Gtk.Button open_button { get; set; }
        Gtk.Button migrate_button { get; set; }
        Gtk.SearchEntry search_entry { get; set; }
        Gtk.MenuButton search_button { get; set; }
        Gtk.MenuButton filter_button { get; set; }
        Gtk.ActionBar action_bar { get; set; }
        Gtk.CheckButton all_filter_button { get; set; }
        Adw.ViewStack groups_stack { get; set; }
        ReleasesBox releases_box { get; set; }
        ReleaseBox release_box { get; set; }
        MigrateBox migrate_box { get; set; }
        Adw.ViewSwitcher switcher { get; set; }
        Adw.ViewStack center_stack { get; set; }
        Gtk.Box root_page_box { get; set; }
        Gtk.Box root_title_box { get; set; }
        Gtk.Box root_actions_box { get; set; }
        Header.Presentation release_presentation { get; set; }
        Header.Presentation migrate_presentation { get; set; }
        ulong background_updates_changed_handler = 0;
        ulong show_legacy_tools_changed_handler = 0;
        ulong release_back_handler = 0;
        ulong migrate_back_handler = 0;
        GroupBox? expanded_group;
        Services.InstallJob? pending_download_job;
        InlineReleaseInteractionState interaction_state = new InlineReleaseInteractionState ();

        public signal void toast_sent (string title);
        public signal void header_presentation_changed (Header.Presentation? presentation);

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

            root_title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                hexpand = true
            };
            root_actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var root_heading = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            root_heading.append (root_title_box);
            root_heading.append (root_actions_box);
            var root_heading_clamp = new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 12,
                margin_start = 12,
                margin_end = 12,
                child = root_heading
            };
            root_page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                vexpand = true
            };
            root_page_box.append (root_heading_clamp);
            root_page_box.append (groups_stack);

            releases_box = new ReleasesBox ();
            releases_box.job_selected.connect ((job) => {
                set_selected_job (job);
            });
            releases_box.clear_search_requested.connect (() => {
                search_entry.set_text ("");
                search_button.grab_focus ();
            });
            releases_box.reset_filter_requested.connect (() => {
                all_filter_button.active = true;
                filter_button.grab_focus ();
            });

            release_box = new ReleaseBox ();

            migrate_box = new MigrateBox ();
            migrate_box.finished.connect (() => {
                if (current_job != null) {
                    release_box.set_selected_job (current_job, true);
                    if (get_visible_page_tag () == "migrate" &&
                        navigation_view.get_previous_page (migrate_page) == release_page)
                        pop_page ();
                    else
                        navigate_to_canonical_page ("release");
                }
                releases_box.refresh_usage_pills ();

                var child = groups_stack.get_first_child ();
                while (child != null) {
                    if (child is GroupBox) {
                        ((GroupBox) child).refresh ();
                    }
                    child = child.get_next_sibling ();
                }
            });

            groups_page = new Adw.NavigationPage.with_tag (root_page_box, _ ("Tools"), "groups");
            release_page = new Adw.NavigationPage.with_tag (release_box, _ ("Details"), "release");
            migrate_page = new Adw.NavigationPage.with_tag (migrate_box, _ ("Migrate"), "migrate");

            navigation_view = new Adw.NavigationView () {
                vexpand = true
            };
            navigation_view.add (groups_page);
            navigation_view.add (release_page);
            navigation_view.add (migrate_page);

            open_button = new Gtk.Button.from_icon_name ("globe-symbolic") {
                valign = Gtk.Align.CENTER,
                visible = false
            };
            open_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Open Release Page"), -1
            );
            open_button.set_tooltip_text (_("Open Release Page"));
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
                var internal_name = current_job.get_usage_identifier ();
                migrate_box.init (release_box.get_selected_games (), internal_name, current_launcher);
                push_page (migrate_page);
            });

            switcher = new Adw.ViewSwitcher () {
                stack = groups_stack,
                policy = Adw.ViewSwitcherPolicy.WIDE
            };

            refresh_button = new Gtk.Button.from_icon_name ("update-check-symbolic") {
                valign = Gtk.Align.CENTER
            };
            refresh_button.set_tooltip_text (_ ("Check for updates"));
            refresh_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Check for updates"), -1
            );
            refresh_button.clicked.connect (on_refresh_clicked);

            search_entry = new Gtk.SearchEntry () {
                valign = Gtk.Align.CENTER,
                placeholder_text = _ ("Search"),
                width_request = 280,
            };
            Utils.TextInputMetadataPolicy.apply (search_entry, Utils.TextInputFieldKind.SEARCH);
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
            search_entry.stop_search.connect (() => {
                if (search_entry.get_text () != "") {
                    search_entry.set_text ("");
                    return;
                }
                search_popover.popdown ();
                search_button.grab_focus ();
            });

            search_button = new Gtk.MenuButton () {
                valign = Gtk.Align.CENTER,
                icon_name = "edit-find-symbolic",
                popover = search_popover
            };
            search_button.set_tooltip_text (_ ("Search"));
            search_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Search"), -1
            );
            Window.register_popover_for_controller (search_popover, search_button, search_entry);

            filter_button = new Gtk.MenuButton () {
                valign = Gtk.Align.CENTER,
                icon_name = "filter-2-symbolic"
            };
            filter_button.set_tooltip_text (_ ("Filter"));
            filter_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Filter"), -1
            );

            all_filter_button = new Gtk.CheckButton.with_label (_ ("All"));
            all_filter_button.active = true;

            var installed_filter_button = new Gtk.CheckButton.with_label (_ ("Installed"));
            installed_filter_button.set_group (all_filter_button);

            var used_filter_button = new Gtk.CheckButton.with_label (_ ("Used"));
            used_filter_button.set_group (all_filter_button);

            var unused_filter_button = new Gtk.CheckButton.with_label (_ ("Unused"));
            unused_filter_button.set_group (all_filter_button);

            var filter_box = new ProtonPlus.Widgets.ControllerChoiceBox () {
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

            var center_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                halign = Gtk.Align.CENTER
            };
            center_box.append (center_stack);

            release_presentation = new Header.Presentation (release_box.header_box);
            release_back_handler = release_presentation.back_requested.connect (() => {
                controller_navigate_back ();
            });
            release_presentation.add_end_action (open_button);
            release_presentation.add_end_action (migrate_button);

            var migrate_title = new Adw.WindowTitle (_ ("Migrate"), "");
            migrate_presentation = new Header.Presentation (migrate_title);
            migrate_back_handler = migrate_presentation.back_requested.connect (() => {
                controller_navigate_back ();
            });
            migrate_presentation.add_end_action (migrate_box.games_button);
            migrate_presentation.add_end_action (migrate_box.migrate_button);

            action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (center_box);

            navigation_view.notify["visible-page"].connect (() => {
                var visible_child = get_visible_page_tag ();
                if (visible_child != "groups")
                    clear_root_heading ();
                search_button.set_visible (visible_child != "release" && visible_child != "migrate");
                filter_button.set_visible (visible_child != "release" && visible_child != "migrate");
                var background_updates_enabled = Globals.SETTINGS != null
                                                 && Globals.SETTINGS.get_boolean ("background-updates");
                refresh_button.set_visible (
                    visible_child != "release"
                    && visible_child != "migrate"
                    && !background_updates_enabled
                );
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
                    center_stack.set_visible (false);
                    action_bar.set_visible (false);
                } else {
                    center_stack.set_visible (false);
                    action_bar.set_visible (false);
                }

                header_presentation_changed (get_header_presentation ());
                if (visible_child == "groups")
                    update_root_heading ();
            });

            navigation_view.popped.connect ((page) => {
                if (page.get_tag () == "release") {
                    refresh_group_boxes ();
                    restore_current_release_focus ();
                }
            });

            navigation_view.notify_property ("visible-page");

            groups_stack.notify["visible-child"].connect (() => {
                if (expanded_group != null && groups_stack.get_visible_child () != expanded_group)
                    collapse_current_expansion (false);
                if (get_visible_page_tag () == "groups")
                    update_root_heading ();
            });

            release_box.stack_switcher.stack.notify["visible-child-name"].connect (() => {
                update_open_button_visibility ();
            });

            release_box.selection_changed.connect (() => {
                update_open_button_visibility ();
            });

            append (navigation_view);
            append (action_bar);

            if (Globals.SETTINGS != null) {
                background_updates_changed_handler = Globals.SETTINGS.changed["background-updates"].connect (update_refresh_button_visibility);
                show_legacy_tools_changed_handler = Globals.SETTINGS.changed["show-legacy-tools"].connect (refresh_groups_for_legacy_tools);
            }
        }

        public override void dispose () {
            collapse_current_expansion (false);
            pending_download_job = null;
            current_job = null;
            if (release_back_handler != 0) {
                release_presentation.disconnect (release_back_handler);
                release_back_handler = 0;
            }
            if (migrate_back_handler != 0) {
                migrate_presentation.disconnect (migrate_back_handler);
                migrate_back_handler = 0;
            }
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
            navigation_view.notify_property ("visible-page");
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

        void clear_box (Gtk.Box box) {
            Gtk.Widget? child;
            while ((child = box.get_first_child ()) != null)
                box.remove ((!) child);
        }

        void clear_root_heading () {
            clear_box (root_title_box);
            clear_box (root_actions_box);
        }

        void update_root_heading () {
            clear_root_heading ();
            var group_box = groups_stack.get_visible_child () as GroupBox;
            if (group_box != null)
                root_title_box.append (((!) group_box).header_title);
            root_actions_box.append (refresh_button);
            root_actions_box.append (filter_button);
            root_actions_box.append (search_button);
        }

        public Header.Presentation? get_header_presentation () {
            switch (get_visible_page_tag ()) {
                case "release":
                    return release_presentation;
                case "migrate":
                    return migrate_presentation;
                default:
                    return null;
            }
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
            var visible_child = get_visible_page_tag ();
            if (current_job != null && current_job.release.page_url != null)
                open_button.update_property (
                    Gtk.AccessibleProperty.DESCRIPTION,
                    current_job.release.page_url,
                    -1
                );
            else
                open_button.reset_property (Gtk.AccessibleProperty.DESCRIPTION);
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

        GroupBox? find_group_for_tool (Models.Tool tool) {
            var child = groups_stack.get_first_child ();
            while (child != null) {
                var group_box = child as GroupBox;
                if (group_box != null && ((!) group_box).contains_tool (tool))
                    return group_box;
                child = child.get_next_sibling ();
            }
            return null;
        }

        void collapse_current_expansion (bool restore_focus) {
            var group_box = expanded_group;
            if (group_box == null)
                return;
            interaction_state.clear_navigation ((!) group_box);
            ((!) group_box).collapse_expanded_tool (restore_focus);
            if (expanded_group == group_box)
                expanded_group = null;
            interaction_state.collapse ((!) group_box);
            releases_box.clear_selected_tool ();
        }

        void focus_download_job (Services.InstallJob job, GroupBox group_box) {
            if (expanded_group != group_box || !group_box.is_expanded_tool (job.tool) ||
                !releases_box.is_showing_tool (job.tool))
                return;

            var row = releases_box.focus_job_row (job, true);
            if (row != null)
                group_box.focus_release_widget ((!) row);
            else {
                var fallback = group_box.get_expanded_row ();
                if (fallback != null)
                    ((!) fallback).grab_focus ();
            }
        }

        void restore_current_release_focus () {
            if (current_job == null || expanded_group == null)
                return;
            var job = (!) current_job;
            var group_box = (!) expanded_group;
            double scroll_position;
            if (!interaction_state.restore_navigation (group_box, job, out scroll_position))
                return;
            Idle.add (() => {
                if (get_visible_page_tag () != "groups" || expanded_group != group_box ||
                    !group_box.is_expanded_tool (job.tool))
                    return Source.REMOVE;
                var row = releases_box.focus_job_row (job);
                if (row != null)
                    group_box.focus_release_widget ((!) row, false);
                else {
                    var fallback = group_box.get_expanded_row ();
                    if (fallback != null)
                        ((!) fallback).grab_focus ();
                }
                group_box.restore_scroll_position (scroll_position);
                return Source.REMOVE;
            });
        }

        string get_visible_page_tag () {
            return navigation_view.get_visible_page ().get_tag () ?? "groups";
        }

        bool navigation_stack_contains (Adw.NavigationPage page) {
            var navigation_stack = navigation_view.get_navigation_stack ();
            for (uint i = 0; i < navigation_stack.get_n_items (); i++) {
                if (navigation_stack.get_item (i) == page)
                    return true;
            }
            return false;
        }

        void push_page (Adw.NavigationPage page) {
            if (navigation_view.get_visible_page () == page)
                return;
            if (navigation_stack_contains (page)) {
                navigation_view.pop_to_page (page);
                return;
            }
            navigation_view.push (page);
        }

        bool pop_page () {
            return navigation_view.pop ();
        }

        void reset_to_root () {
            navigation_view.replace ({ groups_page });
        }

        void navigate_to_canonical_page (string tag) {
            switch (tag) {
                case "groups":
                    reset_to_root ();
                    break;
                case "release":
                    navigation_view.replace ({ groups_page, release_page });
                    break;
                case "migrate":
                    navigation_view.replace ({ groups_page, release_page, migrate_page });
                    break;
                default:
                    warning ("Unknown Tools navigation page: %s", tag);
                    reset_to_root ();
                    break;
            }
        }

        public void show_groups_page () {
            reset_to_root ();
            collapse_current_expansion (true);
            search_entry.set_text ("");
            all_filter_button.active = true;
            refresh_group_boxes ();
        }

        public string get_controller_page_id () {
            return "tools:%s".printf (get_visible_page_tag ());
        }

        public Object? get_controller_page_root () {
            return navigation_view.get_visible_page ().get_child ();
        }

        public Object? get_controller_initial_focus () {
            if (get_visible_page_tag () == "groups") {
                var group = groups_stack.get_visible_child () as GroupBox;
                return group?.get_controller_initial_focus ();
            }

            var root = navigation_view.get_visible_page ().get_child ();
            return root == null ? null : find_first_focusable (root);
        }

        Gtk.Widget? find_first_focusable (Gtk.Widget root) {
            if (!root.get_mapped () || !root.is_visible () || !root.is_sensitive ())
                return null;
            if (root.get_focusable ())
                return root;

            var child = root.get_first_child ();
            while (child != null) {
                var target = find_first_focusable (child);
                if (target != null)
                    return target;
                child = child.get_next_sibling ();
            }
            return null;
        }

        public bool controller_navigate_back () {
            if (get_visible_page_tag () == "groups" && expanded_group != null) {
                collapse_current_expansion (true);
                return true;
            }
            return pop_page ();
        }

        public bool controller_can_navigate_back () {
            return get_visible_page_tag () != "groups" || expanded_group != null;
        }

        public bool controller_can_switch_page () {
            return false;
        }

        public bool controller_prefers_initial_focus_after_switch () {
            return false;
        }

        public bool controller_switch_page (int delta) {
            return false;
        }

        public bool controller_can_open_search () {
            return search_button.get_mapped () && search_button.is_visible () &&
                search_button.is_sensitive ();
        }

        public bool search_available () {
            return get_visible_page_tag () == "groups" &&
                search_button.is_visible () && search_button.is_sensitive ();
        }

        public bool controller_can_open_filter () {
            return filter_button.get_mapped () && filter_button.is_visible () &&
                filter_button.is_sensitive ();
        }

        public bool controller_open_search () {
            if (!controller_can_open_search ())
                return false;
            search_button.popup ();
            Idle.add (() => {
                if (search_entry.get_mapped ())
                    search_entry.grab_focus ();
                return Source.REMOVE;
            });
            return true;
        }

        public bool controller_open_filter () {
            if (!controller_can_open_filter ())
                return false;
            filter_button.popup ();
            return true;
        }

        public void show_download (Services.InstallJob job) {
            navigate_to_canonical_page ("groups");
            pending_download_job = job;
            var group_box = find_group_for_tool (job.tool);
            if (group_box == null) {
                pending_download_job = null;
                return;
            }
            groups_stack.set_visible_child ((!) group_box);
            if (((!) group_box).is_expanded_tool (job.tool) && releases_box.is_showing_tool (job.tool)) {
                if (releases_box.is_loading_tool (job.tool))
                    return;
                pending_download_job = null;
                focus_download_job (job, (!) group_box);
                return;
            }
            if (!((!) group_box).expand_tool (job.tool))
                pending_download_job = null;
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            collapse_current_expansion (false);
            releases_box.clear_selected_tool ();
            pending_download_job = null;
            current_job = null;
            current_launcher = launcher;

            Gtk.Widget? child;
            while ((child = groups_stack.get_first_child ()) != null) {
                groups_stack.remove (child);
            }

            foreach (var group in launcher.groups) {
                var group_box = new GroupBox (group, search_button);
                group_box.filter = current_filter;
                group_box.search_text = search_entry.get_text ();
                group_box.tool_expansion_changed.connect ((tool, expanded) => {
                    on_tool_expansion_changed (group_box, tool, expanded);
                });
                group_box.clear_search_requested.connect (() => {
                    search_entry.set_text ("");
                    search_button.grab_focus ();
                });
                group_box.reset_filter_requested.connect (() => {
                    all_filter_button.active = true;
                    filter_button.grab_focus ();
                });
                groups_stack.add_titled_with_icon (group_box, group.title.down (), group.title, "layer-group-symbolic");
            }

            navigation_view.notify_property ("visible-page");

            reset_to_root ();
        }

        void on_tool_expansion_changed (GroupBox group_box, Models.Tool tool, bool expanded) {
            if (!expanded) {
                interaction_state.collapse (group_box);
                interaction_state.clear_navigation (group_box);
                if (expanded_group == group_box) {
                    if (pending_download_job != null && ((!) pending_download_job).tool == tool)
                        pending_download_job = null;
                    releases_box.clear_selected_tool ();
                    expanded_group = null;
                }
                return;
            }

            var previous_group = interaction_state.expanded_owner as GroupBox;
            interaction_state.expand (group_box);
            if (previous_group != null && previous_group != group_box)
                ((!) previous_group).collapse_expanded_tool (false);

            expanded_group = group_box;
            group_box.attach_release_section (tool, releases_box);
            releases_box.filter = current_filter;
            releases_box.search_text = search_entry.get_text ();
            releases_box.set_selected_tool.begin (tool, (obj, result) => {
                bool loaded = releases_box.set_selected_tool.end (result);
                if (expanded_group != group_box || !group_box.is_expanded_tool (tool) ||
                    !releases_box.is_showing_tool (tool))
                    return;

                if (pending_download_job != null && ((!) pending_download_job).tool == tool) {
                    var target = (!) pending_download_job;
                    pending_download_job = null;
                    focus_download_job (target, group_box);
                    return;
                }

                if (!loaded)
                    return;
            });
        }

        void set_selected_job (Services.InstallJob job, bool show_games = false) {
            if (expanded_group != null && ((!) expanded_group).is_expanded_tool (job.tool)) {
                interaction_state.remember_navigation (
                    (!) expanded_group, job, ((!) expanded_group).get_scroll_position ()
                );
            }
            current_job = job;

            release_box.set_selected_job (job, show_games);

            push_page (release_page);
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
