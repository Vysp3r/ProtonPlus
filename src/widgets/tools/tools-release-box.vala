namespace ProtonPlus.Widgets.Tools {
    public class ReleaseBox : Gtk.Box {
        public Adw.ViewSwitcher stack_switcher { get; set; }
        public Gtk.Stack header_stack { get; private set; }
        Adw.WindowTitle window_title { get; set; }
        ReleaseChangelog desc_text { get; set; }
        Gtk.ListBox list_box { get; set; }
        Gtk.CheckButton check_button { get; set; }
        Adw.ViewStack content_stack { get; set; }
        Gtk.Stack games_stack { get; set; }
        Adw.StatusPage status_page { get; set; }
        Adw.ViewSwitcherBar stack_switcher_bar { get; set; }
        Adw.ViewStackPage games_page { get; set; }
        bool updating_select_all = false;
        bool narrow_layout = false;

        public signal void selection_changed ();

        public ReleaseBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            window_title = new Adw.WindowTitle ("", "");

            content_stack = new Adw.ViewStack () {
                vexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };

            stack_switcher = new Adw.ViewSwitcher () {
                stack = content_stack,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            stack_switcher.set_policy (Adw.ViewSwitcherPolicy.WIDE);

            header_stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                transition_duration = 150
            };
            header_stack.add_named (window_title, "title");
            header_stack.add_named (stack_switcher, "views");

            stack_switcher_bar = new Adw.ViewSwitcherBar () {
                stack = content_stack
            };

            desc_text = new ReleaseChangelog ();

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");

            check_button = new Gtk.CheckButton ();
            check_button.set_tooltip_text (_("Select all games"));
            check_button.update_property (
                Gtk.AccessibleProperty.LABEL, _("Select all games"), -1
            );
            check_button.toggled.connect (() => {
                if (updating_select_all)
                    return;

                var is_active = check_button.get_active ();
                updating_select_all = true;
                var child = list_box.get_first_child ();
                while (child != null) {
                    if (child is GameRow) {
                        ((GameRow) child).selected = is_active;
                    }
                    child = child.get_next_sibling ();
                }
                updating_select_all = false;
                update_selection_state ();
            });

            var select_all_row = new Adw.ActionRow () {
                title = _("Select all games"),
                activatable_widget = check_button
            };
            select_all_row.add_prefix (check_button);
            list_box.append (select_all_row);

            var games_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                margin_start = 12,
                margin_end = 12,
                margin_top = 24,
                margin_bottom = 24
            };
            games_content.append (list_box);

            var games_clamp = new Adw.Clamp () {
                maximum_size = 720,
                tightening_threshold = 600,
                child = games_content
            };

            var scrolled_games = new Gtk.ScrolledWindow () {
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = games_clamp
            };

            status_page = new Adw.StatusPage () {
                title = _ ("No Games Use This Tool"),
                icon_name = "gamepad-symbolic",
                vexpand = true,
            };

            games_stack = new Gtk.Stack () {
                vexpand = true,
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                transition_duration = 150
            };
            games_stack.add_named (scrolled_games, "list");
            games_stack.add_named (status_page, "empty");

            content_stack.add_titled_with_icon (desc_text, "changelog", _ ("Changelog"), "book-open-symbolic");
            games_page = content_stack.add_titled_with_icon (games_stack, "games", _ ("Used By"), "gamepad-symbolic");

            var responsive_content = new Adw.BreakpointBin () {
                width_request = 360,
                height_request = 1,
                child = content_stack
            };
            var narrow_breakpoint = new Adw.Breakpoint (
                new Adw.BreakpointCondition.length (
                    Adw.BreakpointConditionLengthType.MAX_WIDTH,
                    600,
                    Adw.LengthUnit.SP
                )
            );
            narrow_breakpoint.apply.connect (() => {
                narrow_layout = true;
                update_view_navigation ();
            });
            narrow_breakpoint.unapply.connect (() => {
                narrow_layout = false;
                update_view_navigation ();
            });
            responsive_content.add_breakpoint (narrow_breakpoint);

            append (responsive_content);
            append (stack_switcher_bar);
        }

        public void set_selected_job (Services.InstallJob job, bool show_games = false) {
            var launcher = job.tool.group.launcher;
            var steam_launcher = launcher as Models.Launchers.Steam;
            games_page.set_visible (steam_launcher != null);
            update_view_navigation ();

            window_title.set_title (job.title);
            desc_text.set_markdown (job.release.description);
            window_title.set_subtitle (Utils.format_timestamp (job.release.release_date));

            if (show_games && steam_launcher != null)
                content_stack.set_visible_child_name ("games");
            else
                content_stack.set_visible_child_name ("changelog");

            var child = list_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                if (child is GameRow)
                    list_box.remove (child);
                child = next;
            }

            var tool_name = job.get_usage_identifier ();
            var has_games = false;

            if (steam_launcher != null) {
                foreach (var game in steam_launcher.get_compatibility_tool_usage_games (tool_name)) {
                    var row = new GameRow (game);
                    row.notify["selected"].connect (() => {
                        update_selection_state ();
                    });
                    list_box.append (row);
                    has_games = true;
                }
            }

            games_stack.set_visible_child_name (has_games ? "list" : "empty");
            update_selection_state ();
        }

        void update_view_navigation () {
            var show_views = games_page.get_visible ();
            header_stack.set_visible_child_name (
                show_views && !narrow_layout ? "views" : "title"
            );
            stack_switcher_bar.set_reveal (show_views && narrow_layout);
        }

        void update_selection_state () {
            if (updating_select_all)
                return;

            var selected = 0;
            var total = 0;
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow) {
                    total++;
                    if (((GameRow) child).selected)
                        selected++;
                }
                child = child.get_next_sibling ();
            }

            updating_select_all = true;
            check_button.set_inconsistent (selected > 0 && selected < total);
            check_button.set_active (total > 0 && selected == total);
            check_button.set_sensitive (total > 0);
            updating_select_all = false;
            selection_changed ();
        }

        public int get_selected_games_count () {
            var count = 0;
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow && ((GameRow) child).selected) {
                    count++;
                }
                child = child.get_next_sibling ();
            }
            return count;
        }

        public Gee.ArrayList<Models.Game> get_selected_games () {
            var selected_games = new Gee.ArrayList<Models.Game> ();
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is GameRow && ((GameRow) child).selected) {
                    selected_games.add (((GameRow) child).game);
                }
                child = child.get_next_sibling ();
            }
            return selected_games;
        }
    }
}
