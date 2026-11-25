namespace ProtonPlus.Widgets.Tools {
    public enum Filter {
        ALL,
        INSTALLED,
        USED
    }

    public class Box : Gtk.Box, Utils.ControllerNavigationHost,
        Utils.ControllerPageShortcuts, Utils.ControllerDirectionalFocus {
        Models.Launcher? current_launcher { get; set; }
        Services.InstallJob? current_job;
        bool updating_tools;

        Adw.NavigationView navigation_view { get; set; }
        Adw.NavigationPage groups_page { get; set; }
        Adw.NavigationPage migrate_page { get; set; }
        Gtk.Button refresh_button { get; set; }
        Gtk.Box view_options;
        Gtk.ToggleButton browse_button;
        Gtk.ToggleButton installed_button;
        Gtk.Box toolbar_content;
        Adw.BreakpointBin toolbar;
        Adw.Breakpoint toolbar_wrap;
        Gtk.Box sections;
        Gtk.ScrolledWindow scrolled;
        Adw.StatusPage installed_empty;
        Gtk.Button browse_tools_button;
        ReleasesBox releases_box { get; set; }
        MigrateBox migrate_box { get; set; }
        Header.Presentation migrate_presentation { get; set; }
        ulong show_legacy_tools_changed_handler = 0;
        ulong show_niche_tools_changed_handler = 0;
        ulong migrate_back_handler = 0;
        GroupBox? expanded_group {
            get { return interaction_state.expanded_owner as GroupBox; }
        }
        Services.InstallJob? pending_download_job;
        InlineReleaseInteractionState interaction_state = new InlineReleaseInteractionState ();

        public signal void toast_sent (string title);
        public signal void header_presentation_changed (Header.Presentation? presentation);

        private Filter _current_filter = Filter.ALL;
        public Filter current_filter {
            get { return _current_filter; }
            set {
                if (_current_filter == value)
                    return;
                _current_filter = value;
                if (value == Filter.INSTALLED)
                    installed_button.active = true;
                else
                    browse_button.active = true;
                var focused = get_root ()?.get_focus ();
                if (focused != null && focused.is_ancestor (scrolled))
                    active_view_button ().grab_focus ();
                collapse_current_expansion (false);
                for (var child = sections.get_first_child (); child != null; child = child.get_next_sibling ())
                    ((GroupBox) child).filter = value;
                update_section_navigation ();
                scrolled.vadjustment.value = 0;
                releases_box.filter = value;
            }
        }

        public Box () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            sections = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
            browse_tools_button = new Gtk.Button.with_label (_("Browse Tools")) {
                halign = Gtk.Align.CENTER,
                css_classes = { "suggested-action" }
            };
            browse_tools_button.clicked.connect (switch_to_browse);
            installed_empty = new Adw.StatusPage () {
                title = _("No installed tools"),
                description = _("Install a compatibility tool to see it here."),
                icon_name = "package-x-generic-symbolic",
                child = browse_tools_button,
                visible = false
            };
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.append (sections);
            content.append (installed_empty);
            scrolled = new Gtk.ScrolledWindow () {
                child = new Gtk.Viewport (null, null) {
                    child = clamp_content (content),
                    scroll_to_focus = true
                },
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };
            var root_page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            releases_box = new ReleasesBox ();
            releases_box.changelog_requested.connect (show_changelog_dialog);
            releases_box.games_requested.connect ((job) => {
                show_games_dialog (job);
            });
            releases_box.reset_filter_requested.connect (switch_to_browse);

            migrate_box = new MigrateBox ();
            migrate_box.finished.connect (() => {
                if (get_visible_page_tag () == "migrate")
                    pop_page ();
                else
                    navigate_to_canonical_page ("groups");
                releases_box.refresh_usage_pills ();

                refresh_group_boxes ();
            });

            groups_page = new Adw.NavigationPage.with_tag (root_page_box, _ ("Tools"), "groups");
            migrate_page = new Adw.NavigationPage.with_tag (migrate_box, _ ("Migrate"), "migrate");

            navigation_view = new Adw.NavigationView () {
                vexpand = true
            };
            navigation_view.add (groups_page);
            navigation_view.add (migrate_page);

            refresh_button = new Gtk.Button.with_label (_("Update Tools")) {
                halign = Gtk.Align.END, valign = Gtk.Align.CENTER, sensitive = false
            };
            refresh_button.set_tooltip_text (_ ("Update installed tools"));
            refresh_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Update installed tools"), -1
            );
            refresh_button.clicked.connect (on_refresh_clicked);

            browse_button = new Gtk.ToggleButton.with_label (_("Browse")) { active = true };
            installed_button = new Gtk.ToggleButton.with_label (_("Installed"));
            installed_button.set_group (browse_button);
            view_options = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                valign = Gtk.Align.CENTER, halign = Gtk.Align.START, hexpand = true,
                css_classes = { "linked" }
            };
            view_options.append (browse_button);
            view_options.append (installed_button);
            browse_button.toggled.connect (() => {
                if (browse_button.active)
                    current_filter = Filter.ALL;
            });
            installed_button.toggled.connect (() => {
                if (installed_button.active)
                    current_filter = Filter.INSTALLED;
            });

            toolbar_content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            toolbar_content.append (view_options);
            toolbar_content.append (refresh_button);
            refresh_button.notify["sensitive"].connect (update_section_navigation);
            toolbar = new Adw.BreakpointBin () { child = toolbar_content };
            var wrap = new Adw.Breakpoint (new Adw.BreakpointCondition.length (
                Adw.BreakpointConditionLengthType.MAX_WIDTH, 0, Adw.LengthUnit.PX
            ));
            // Breakpoint setters on the bin can crash during teardown with libadwaita 1.7.
            wrap.apply.connect (() => set_toolbar_orientation (Gtk.Orientation.VERTICAL));
            wrap.unapply.connect (() => set_toolbar_orientation (Gtk.Orientation.HORIZONTAL));
            toolbar_wrap = wrap;
            toolbar.add_breakpoint ((owned) wrap);
            toolbar.map.connect (update_toolbar_breakpoint);
            toolbar.notify["scale-factor"].connect (update_toolbar_breakpoint);
            update_toolbar_breakpoint ();
            root_page_box.append (clamp_content (toolbar));
            root_page_box.append (scrolled);

            var migrate_title = new Adw.WindowTitle (_ ("Migrate"), "");
            migrate_presentation = new Header.Presentation (migrate_title);
            migrate_back_handler = migrate_presentation.back_requested.connect (() => {
                controller_navigate_back ();
            });
            migrate_presentation.add_end_action (migrate_box.games_button);
            migrate_presentation.add_end_action (migrate_box.migrate_button);

            navigation_view.notify["visible-page"].connect (() => {
                var migrating = get_visible_page_tag () == "migrate";
                migrate_box.games_button.set_visible (migrating);
                migrate_box.migrate_button.set_visible (migrating);
                header_presentation_changed (get_header_presentation ());
            });

            navigation_view.popped.connect ((page) => {
                if (page.get_tag () == "migrate") {
                    refresh_group_boxes ();
                    restore_current_release_focus ();
                    current_job = null;
                }
            });

            navigation_view.notify_property ("visible-page");

            append (navigation_view);

            if (Globals.SETTINGS != null) {
                show_legacy_tools_changed_handler = Globals.SETTINGS.changed["show-legacy-tools"].connect (refresh_group_boxes);
                show_niche_tools_changed_handler = Globals.SETTINGS.changed["show-niche-tools"].connect (refresh_group_boxes);
            }
        }

        public override void dispose () {
            collapse_current_expansion (false);
            pending_download_job = null;
            current_job = null;
            if (migrate_back_handler != 0) {
                migrate_presentation.disconnect (migrate_back_handler);
                migrate_back_handler = 0;
            }
            if (Globals.SETTINGS != null) {
                if (show_legacy_tools_changed_handler != 0) {
                    Globals.SETTINGS.disconnect (show_legacy_tools_changed_handler);
                    show_legacy_tools_changed_handler = 0;
                }
                if (show_niche_tools_changed_handler != 0) {
                    Globals.SETTINGS.disconnect (show_niche_tools_changed_handler);
                    show_niche_tools_changed_handler = 0;
                }
            }

            base.dispose ();
        }

        Gtk.Widget active_view_button () {
            if (installed_button.active)
                return installed_button;
            return browse_button;
        }

        void switch_to_browse () {
            current_filter = Filter.ALL;
            browse_button.grab_focus ();
        }

        static Adw.Clamp clamp_content (Gtk.Widget child) {
            return new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                child = child
            };
        }

        void update_toolbar_breakpoint () {
            int options_width, update_width;
            view_options.measure (Gtk.Orientation.HORIZONTAL, -1, out options_width, null, null, null);
            refresh_button.measure (Gtk.Orientation.HORIZONTAL, -1, out update_width, null, null, null);
            toolbar.width_request = int.max (options_width, update_width);
            toolbar_wrap.condition = new Adw.BreakpointCondition.length (
                Adw.BreakpointConditionLengthType.MAX_WIDTH, options_width + update_width + toolbar_content.spacing - 1,
                Adw.LengthUnit.PX
            );
            update_toolbar_height ();
        }

        void set_toolbar_orientation (Gtk.Orientation orientation) {
            toolbar_content.orientation = orientation;
            update_toolbar_height ();
            update_section_navigation ();
        }

        void update_toolbar_height () {
            int height;
            toolbar_content.measure (Gtk.Orientation.VERTICAL, -1, out height, null, null, null);
            toolbar.height_request = height;
        }

        Gtk.Widget? first_section_target () {
            for (var child = sections.get_first_child (); child != null; child = child.get_next_sibling ()) {
                var target = ((GroupBox) child).get_section_focus ();
                if (target != null && target.get_mapped ())
                    return target;
            }
            return installed_empty.get_mapped () ? browse_tools_button : null;
        }

        void update_section_navigation () {
            GroupBox? previous = null;
            var up = toolbar_content.orientation == Gtk.Orientation.VERTICAL && refresh_button.sensitive
                ? (Gtk.Widget) refresh_button : active_view_button ();
            var previous_up = up;
            bool has_visible_section = false;
            for (var child = sections.get_first_child (); child != null; child = child.get_next_sibling ()) {
                var group_box = (GroupBox) child;
                has_visible_section |= group_box.visible;
                var first = group_box.get_section_focus ();
                var last = group_box.get_section_focus (true);
                if (first == null || last == null)
                    continue;
                previous?.set_controller_boundaries (previous_up, first);
                previous = group_box;
                previous_up = up;
                up = last;
            }
            previous?.set_controller_boundaries (previous_up, null);
            installed_empty.visible = current_filter == Filter.INSTALLED && !has_visible_section;
        }

        public bool controller_focus_direction (Object focused_object, Utils.ControllerNavigationDirection direction) {
            var wrapped = toolbar_content.orientation == Gtk.Orientation.VERTICAL;
            var focused = focused_object as Gtk.Widget;
            if (focused == browse_tools_button && direction == Utils.ControllerNavigationDirection.UP)
                return (wrapped && refresh_button.sensitive ? (Gtk.Widget) refresh_button : active_view_button ()).grab_focus ();

            if (focused != browse_button && focused != installed_button && focused != refresh_button)
                return false;

            switch (direction) {
                case Utils.ControllerNavigationDirection.DOWN:
                    if (wrapped && focused != refresh_button && refresh_button.sensitive)
                        return refresh_button.grab_focus ();
                    return first_section_target ()?.grab_focus () ?? false;
                case Utils.ControllerNavigationDirection.UP:
                    return wrapped && focused == refresh_button && active_view_button ().grab_focus ();
                case Utils.ControllerNavigationDirection.LEFT:
                    if (focused == refresh_button)
                        return installed_button.grab_focus ();
                    return focused == installed_button && browse_button.grab_focus ();
                case Utils.ControllerNavigationDirection.RIGHT:
                    if (focused == browse_button)
                        return installed_button.grab_focus ();
                    return focused == installed_button && refresh_button.sensitive && refresh_button.grab_focus ();
                default:
                    return false;
            }
        }

        public Header.Presentation? get_header_presentation () {
            switch (get_visible_page_tag ()) {
                case "migrate":
                    return migrate_presentation;
                default:
                    return null;
            }
        }

        void refresh_group_boxes () {
            for (var child = sections.get_first_child (); child != null; child = child.get_next_sibling ())
                ((GroupBox) child).refresh ();
        }

        GroupBox? find_group_for_tool (Models.Tool tool) {
            for (var child = sections.get_first_child (); child != null; child = child.get_next_sibling ()) {
                var group_box = (GroupBox) child;
                if (group_box.contains_tool (tool))
                    return group_box;
            }
            return null;
        }

        void collapse_current_expansion (bool restore_focus) {
            var group_box = expanded_group;
            if (group_box == null)
                return;
            // The expansion callback owns clearing selection and navigation.
            ((!) group_box).collapse_expanded_tool (restore_focus);
        }

        void focus_download_job (Services.InstallJob job, GroupBox group_box) {
            if (expanded_group != group_box || !group_box.is_expanded_tool (job.tool) ||
                !releases_box.is_showing_tool (job.tool))
                return;

            if (releases_box.focus_job_row (job, true) == null)
                group_box.get_expanded_row ()?.grab_focus ();
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
                if (releases_box.focus_job_row (job) == null)
                    group_box.get_expanded_row ()?.grab_focus ();
                scrolled.vadjustment.value = scroll_position;
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
                case "migrate":
                    navigation_view.replace ({ groups_page, migrate_page });
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
            refresh_group_boxes ();
        }

        public string get_controller_page_id () {
            return "tools:%s".printf (get_visible_page_tag ());
        }

        public Object? get_controller_page_root () {
            return navigation_view.get_visible_page ().get_child ();
        }

        public Object? get_controller_initial_focus () {
            if (get_visible_page_tag () == "groups")
                return first_section_target () ?? active_view_button ();

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
            return false;
        }

        public bool search_available () {
            return false;
        }

        public bool controller_can_open_filter () {
            return view_options.get_mapped () && view_options.is_sensitive ();
        }

        public bool controller_open_search () {
            return false;
        }

        public bool controller_open_filter () {
            if (!controller_can_open_filter ())
                return false;
            return active_view_button ().grab_focus ();
        }

        public void show_download (Services.InstallJob job) {
            current_filter = Filter.ALL;
            navigate_to_canonical_page ("groups");
            pending_download_job = job;
            var group_box = find_group_for_tool (job.tool);
            if (group_box == null) {
                pending_download_job = null;
                return;
            }
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

        static void connect_group_actions (Box box, GroupBox group_box) {
            var owner_ref = WeakRef (box);
            var group_ref = WeakRef (group_box);
            group_box.tool_expansion_changed.connect ((tool, expanded) => {
                var owner = owner_ref.get () as Box;
                var group = group_ref.get () as GroupBox;
                if (owner != null && group != null)
                    owner.on_tool_expansion_changed (group, tool, expanded);
            });
            group_box.changelog_requested.connect ((job, release) => {
                var owner = owner_ref.get () as Box;
                owner?.show_changelog_dialog (job, release);
            });
            group_box.games_requested.connect ((job) => {
                var owner = owner_ref.get () as Box;
                owner?.show_games_dialog (job);
            });
            group_box.rows_changed.connect (() => {
                var owner = owner_ref.get () as Box;
                var group = group_ref.get () as GroupBox;
                if (owner != null && group?.get_parent () == owner.sections)
                    owner.update_section_navigation ();
            });
            group_box.reset_filter_requested.connect (() => {
                var owner = owner_ref.get () as Box;
                owner?.switch_to_browse ();
            });
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            collapse_current_expansion (false);
            releases_box.clear_selected_tool ();
            pending_download_job = null;
            current_job = null;
            current_launcher = launcher;

            Gtk.Widget? child;
            while ((child = sections.get_first_child ()) != null)
                sections.remove (child);

            foreach (var group in launcher.groups) {
                var group_box = new GroupBox (group);
                group_box.filter = current_filter;
                connect_group_actions (this, group_box);
                sections.append (group_box);
            }

            update_section_navigation ();
            scrolled.vadjustment.value = 0;
            reset_to_root ();
            refresh_button.sensitive = !updating_tools;
        }

        void on_tool_expansion_changed (GroupBox group_box, Models.Tool tool, bool expanded) {
            if (!expanded) {
                interaction_state.clear_navigation (group_box);
                if (expanded_group == group_box) {
                    if (pending_download_job != null && ((!) pending_download_job).tool == tool)
                        pending_download_job = null;
                    releases_box.clear_selected_tool ();
                    interaction_state.collapse (group_box);
                }
                return;
            }

            var previous_group = interaction_state.expanded_owner as GroupBox;
            if (previous_group != null && previous_group != group_box)
                ((!) previous_group).collapse_expanded_tool (false);

            interaction_state.expand (group_box);
            group_box.attach_release_section (tool, releases_box);
            releases_box.filter = current_filter;
            if (releases_box.is_showing_tool (tool)) {
                if (pending_download_job != null &&
                    ((!) pending_download_job).tool == tool &&
                    !releases_box.is_loading_tool (tool)) {
                    var target = (!) pending_download_job;
                    pending_download_job = null;
                    focus_download_job (target, group_box);
                }
                return;
            }
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

        void remember_release_navigation (Services.InstallJob job) {
            if (expanded_group != null && ((!) expanded_group).is_expanded_tool (job.tool)) {
                interaction_state.remember_navigation (
                    (!) expanded_group, job, scrolled.vadjustment.value
                );
            }
        }

        void show_changelog_dialog (Services.InstallJob job, Models.Release release) {
            var dialog = new ReleaseChangelogDialog (job, release);
            Window.present_dialog_for_controller (dialog, this);
        }

        void show_games_dialog (Services.InstallJob job) {
            if (!(job.tool.group.launcher is Models.Launchers.Steam))
                return;

            var dialog = new ReleaseGamesDialog (job);
            dialog.migrate_requested.connect ((games) => {
                remember_release_navigation (job);
                current_job = job;
                migrate_box.init (
                    games, job.get_usage_identifier (), job.tool.group.launcher
                );
                push_page (migrate_page);
            });
            Window.present_dialog_for_controller (dialog, this);
        }

        void on_refresh_clicked () {
            check_for_updates.begin ();
        }

        async void check_for_updates () {
            var launcher = current_launcher;
            if (launcher == null || updating_tools)
                return;
            updating_tools = true;
            refresh_button.sensitive = false;
            toast_sent (_ ("Updating installed tools"));

            var launchers = new List<Models.Launcher> ();
            launchers.append (launcher);
            var code = yield Services.InstallationService.instance.check_for_updates (launchers);

            switch (code) {
                case ReturnCode.RUNNERS_IN_USE:
                    toast_sent (_ ("Can't update while a game is running"));
                    break;
                case ReturnCode.NOTHING_TO_UPDATE:
                    toast_sent (_ ("Nothing to update"));
                    break;
                case ReturnCode.SYMLINKED_TOOL_DIRECTORY:
                    toast_sent (get_return_code_message (code));
                    break;
                case ReturnCode.RUNNERS_UPDATED:
                case ReturnCode.RUNNER_UPDATED:
                    toast_sent (_ ("Eligible installed tools are up to date"));
                    break;
                default:
                    toast_sent (_ ("Couldn't update installed tools (Reason: %s)").printf (get_return_code_message (code)));
                    break;
            }

            updating_tools = false;
            refresh_button.sensitive = true;
        }
    }
}
