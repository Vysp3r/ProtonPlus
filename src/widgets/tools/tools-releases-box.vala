namespace ProtonPlus.Widgets.Tools {
    public class ReleasesBox : Gtk.Box {
        public signal void release_selected (Models.Release release);

        Gtk.Box tool_box { get; set; }
        Gtk.Label title_label { get; set; }
        Gtk.Label desc_label { get; set; }
        Gtk.Box header_box { get; set; }
        Gtk.ListBox list_box { get; set; }
        Gtk.Stack content_stack { get; set; }
        Adw.StatusPage status_page { get; set; }

        private Models.Tool? current_tool;
        private Gtk.ListBoxRow load_more_row;
        private Gtk.Button load_more_button;

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

        public ReleasesBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            var icon = new Gtk.Image.from_icon_name ("layer-group-symbolic");

            title_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            desc_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "caption" },
                wrap = true,
                xalign = 0
            };

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            title_box.append (title_label);
            title_box.append (desc_label);

            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (icon);
            header_box.append (title_box);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-releases-card");
            list_box.set_filter_func (filter_func);

            load_more_button = new Gtk.Button.with_label (_ ("Load More")) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                halign = Gtk.Align.CENTER,
                hexpand = true
            };
            load_more_button.add_css_class ("pill");
            load_more_button.clicked.connect (on_load_more_clicked);

            load_more_row = new Gtk.ListBoxRow () {
                child = load_more_button,
                activatable = false,
                selectable = false,
                visible = false
            };
            list_box.append (load_more_row);

            var scrolled = new Gtk.ScrolledWindow () {
                child = list_box,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC
            };

            var spinner = new Adw.Spinner () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                hexpand = true,
                vexpand = true
            };
            spinner.set_size_request (32, 32);

            var spinner_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                vexpand = true,
                hexpand = true,
            };
            spinner_box.append (spinner);

            content_stack = new Gtk.Stack () {
                vexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };
            content_stack.add_css_class ("card");

            status_page = new Adw.StatusPage () {
                title = _ ("No releases found"),
                description = _ ("No releases match the current filter."),
                icon_name = "magnifying-glass-symbolic"
            };

            content_stack.add_named (scrolled, "list");
            content_stack.add_named (spinner_box, "spinner");
            content_stack.add_named (status_page, "empty");

            tool_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            tool_box.append (header_box);
            tool_box.append (content_stack);

            var clamp = new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 5,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                child = tool_box,
            };

            append (clamp);
        }

        public async void set_selected_tool (Models.Tool tool) {
            current_tool = tool;
            content_stack.set_visible_child_name ("spinner");

            list_box.remove_all ();

            title_label.set_label (tool.title);
            desc_label.set_label (tool.description);

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield tool.get_releases_async (out code);
            if (code != ReturnCode.RELEASES_LOADED) {
                Adw.AlertDialog dialog;

                switch (code) {
                    case ReturnCode.API_LIMIT_REACHED:
                        dialog = new Main.WarningDialog (_ ("API limit reached"), _ ("Try again in a few minutes."));
                        break;
                    case ReturnCode.CONNECTION_ISSUE:
                        dialog = new Main.WarningDialog (_ ("Unable to reach the API"), _ ("Make sure you're connected to the internet."));
                        break;
                    case ReturnCode.CONNECTION_REFUSED:
                        dialog = new Main.WarningDialog (_ ("Unable to reach the API"), _ ("Make sure your DNS is not blocking this."));
                        break;
                    case ReturnCode.CONNECTION_UNKNOWN:
                        dialog = new Main.WarningDialog (_ ("Unable to reach the API"), _ ("The requested website does not seem to be valid."));
                        break;
                    case ReturnCode.INVALID_ACCESS_TOKEN:
                        dialog = new Main.WarningDialog (_ ("Invalid access token"), _ ("Make sure the access token you provided is valid."));
                        break;
                    default:
                        dialog = new Main.ErrorDialog (_ ("Unknown error"), _ ("Please report this issue on GitHub."));
                        break;
                }

                content_stack.set_visible_child_name ("list");

                dialog.present ((Gtk.Window) this.get_root ());

                return;
            }

            foreach (var release in releases) {
                add_release_row (release);
            }

            list_box.append (load_more_row);
            load_more_row.visible = tool.has_more;

            content_stack.set_visible_child_name ("list");
            update_visibility ();
        }

        private void add_release_row (Models.Release release) {
            ReleaseRow row;
            if (release is Models.Releases.SteamTinkerLaunch)
            row = new STLReleaseRow (release);
            else
            row = new ReleaseRow (release);

            row.set_data ("release", release);
            row.release_selected.connect ((release) => release_selected (release));

            list_box.append (row);
        }

        private async void on_load_more_clicked () {
            if (current_tool == null)
            return;

            load_more_button.sensitive = false;

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield current_tool.load_more (out code);

            if (code == ReturnCode.RELEASES_LOADED) {
                foreach (var release in releases) {
                    current_tool.releases.add (release);
                    add_release_row (release);
                }
                list_box.remove (load_more_row);
                list_box.append (load_more_row);
            }

            load_more_row.visible = current_tool.has_more;
            load_more_button.sensitive = true;
            update_visibility ();
        }

        void update_visibility () {
            bool has_visible = false;
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is Gtk.ListBoxRow && child != load_more_row) {
                    if (filter_func ((Gtk.ListBoxRow) child)) {
                        has_visible = true;
                        break;
                    }
                }
                child = child.get_next_sibling ();
            }

            if (has_visible || (load_more_row != null && load_more_row.visible)) {
                content_stack.set_visible_child_name ("list");
            } else {
                content_stack.set_visible_child_name ("empty");
            }
        }

        bool filter_func (Gtk.ListBoxRow row) {
            var release = row.get_data<Models.Release> ("release");
            if (release == null)
            return true;

            if (search_text != "" && !release.title.down ().contains (search_text.down ()))
            return false;

            if (filter == Filter.ALL)
            return true;

            if (filter == Filter.INSTALLED)
            return release.state == Models.Release.State.UP_TO_DATE || release.state == Models.Release.State.UPDATE_AVAILABLE;

            var usage_count = release.runner.group.launcher.get_compatibility_tool_usage_count (release.title != "SteamTinkerLaunch" ? release.title : "Proton-stl");

            if (filter == Filter.USED)
            return usage_count > 0;

            if (filter == Filter.UNUSED)
            return usage_count == 0;

            return true;
        }
    }
}