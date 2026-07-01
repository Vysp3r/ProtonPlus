namespace ProtonPlus.Widgets.Tools {
    public class ReleasesBox : Gtk.Box {
        public signal void release_selected (Models.Release release);

        Gtk.Box tool_box { get; set; }
        Gtk.Label title_label { get; set; }
        Gtk.Label desc_label { get; set; }
        Gtk.Label last_updated_label { get; set; }
        Gtk.Button refresh_button { get; set; }
        Gtk.Box header_box { get; set; }
        Gtk.ListBox list_box { get; set; }
        Gtk.Stack content_stack { get; set; }
        Adw.StatusPage status_page { get; set; }

        private Models.Tool? current_tool;
        Models.Variant? selected_variant = null;
        Adw.SplitButton variant_button { get; set; }
        Gtk.Popover variant_popover { get; set; }
        Gtk.Box variant_popover_box { get; set; }
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

        private string get_tool_variant_settings_key (Models.Tool tool) {
            return "%s::%s::%s".printf (tool.group.launcher.title, tool.group.title, tool.title);
        }

        private string get_saved_variant_name (Models.Tool tool) {
            if (Globals.SETTINGS == null)
                return "";

            var raw = Globals.SETTINGS.get_string ("selected-tool-variants");
            if (raw == "")
                return "";

            var root_node = Utils.Parser.get_node_from_json (raw);
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT)
                return "";

            var root_obj = root_node.get_object ();
            return root_obj.get_string_member_with_default (get_tool_variant_settings_key (tool), "");
        }

        private void save_selected_variant_name (Models.Tool tool, string variant_name) {
            if (Globals.SETTINGS == null)
                return;

            Json.Object root_obj;

            var raw = Globals.SETTINGS.get_string ("selected-tool-variants");
            var root_node = Utils.Parser.get_node_from_json (raw);
            if (root_node != null && root_node.get_node_type () == Json.NodeType.OBJECT) {
                root_obj = root_node.get_object ();
            } else {
                root_obj = new Json.Object ();
            }

            root_obj.set_string_member (get_tool_variant_settings_key (tool), variant_name);

            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (root_obj);

            var generator = new Json.Generator ();
            generator.set_root (node);
            Globals.SETTINGS.set_string ("selected-tool-variants", generator.to_data (null));
        }

        public ReleasesBox () {
            Object (orientation : Gtk.Orientation.VERTICAL, spacing : 0);

            var icon = new Gtk.Image.from_icon_name ("screwdriver-wrench-symbolic") {
                valign = Gtk.Align.CENTER
            };

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

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                valign = Gtk.Align.CENTER
            };
            title_box.append (title_label);
            title_box.append (desc_label);

            var info_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true,
                valign = Gtk.Align.CENTER
            };
            info_box.append (icon);
            info_box.append (title_box);

            last_updated_label = new Gtk.Label (null) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
                css_classes = { "caption" }
            };

            refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Check for new releases")
            };
            refresh_button.add_css_class ("flat");
            refresh_button.clicked.connect (on_refresh_clicked);

            variant_popover = new Gtk.Popover ();
            variant_popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            variant_popover_box.set_margin_top (6);
            variant_popover_box.set_margin_bottom (6);
            variant_popover_box.set_margin_start (6);
            variant_popover_box.set_margin_end (6);

            variant_button = new Adw.SplitButton ();
            variant_button.add_css_class ("flat");
            variant_button.set_valign (Gtk.Align.CENTER);
            variant_button.set_dropdown_tooltip (_("Choose a variant"));
            variant_popover.set_child (variant_popover_box);
            variant_button.set_popover (variant_popover);
            variant_button.set_visible (false);

            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (info_box);
            header_box.append (variant_button);
            header_box.append (last_updated_label);
            header_box.append (refresh_button);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-releases-card");
            list_box.set_filter_func (filter_func);

            load_more_button = new Gtk.Button.with_label (_("Load More")) {
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
                halign = Gtk.Align.CENTER,
                hexpand = true
            };
            load_more_button.add_css_class ("pill");
            load_more_button.add_css_class ("suggested-action");
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
                title = _("No releases found"),
                description = _("No releases match the current filter."),
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
                margin_top = 12,
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
            update_last_updated_label ();
            update_variant_btn (tool);

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield tool.get_releases_async (false, out code);

            if (code != ReturnCode.RELEASES_LOADED) {
                Adw.AlertDialog dialog;

                switch (code) {
                case ReturnCode.API_LIMIT_REACHED:
                    dialog = new Main.WarningDialog (_("API limit reached"), _("Try again in a few minutes."));
                    break;
                case ReturnCode.CONNECTION_ISSUE:
                    dialog = new Main.WarningDialog (_("Unable to reach the API"), _("Make sure you're connected to the internet."));
                    break;
                case ReturnCode.CONNECTION_REFUSED:
                    dialog = new Main.WarningDialog (_("Unable to reach the API"), _("Make sure your DNS is not blocking this."));
                    break;
                case ReturnCode.CONNECTION_UNKNOWN:
                    dialog = new Main.WarningDialog (_("Unable to reach the API"), _("The requested website does not seem to be valid."));
                    break;
                case ReturnCode.INVALID_ACCESS_TOKEN:
                    dialog = new Main.WarningDialog (_("Invalid access token"), _("Make sure the access token you provided is valid."));
                    break;
                default:
                    dialog = new Main.ErrorDialog (
                        _("Failed to Fetch Releases"),
                        _("ProtonPlus could not retrieve the list of available releases. Please check your internet connection and try again."),
                        ""
                    );
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
            apply_selected_variant_to_rows ();
            update_last_updated_label ();
            update_visibility ();
        }

        private void on_refresh_clicked () {
            if (current_tool == null)return;
            set_selected_tool_forced.begin (current_tool);
        }

        private async void set_selected_tool_forced (Models.Tool tool) {
            current_tool = tool;
            content_stack.set_visible_child_name ("spinner");

            list_box.remove_all ();

            title_label.set_label (tool.title);
            desc_label.set_label (tool.description);

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield tool.get_releases_async (true, out code);

            if (code != ReturnCode.RELEASES_LOADED) {
                Adw.AlertDialog dialog;

                switch (code) {
                case ReturnCode.API_LIMIT_REACHED:
                    dialog = new Main.WarningDialog (_("API limit reached"), _("Try again in a few minutes."));
                    break;
                case ReturnCode.CONNECTION_ISSUE:
                    dialog = new Main.WarningDialog (_("Unable to reach the API"), _("Make sure you're connected to the internet."));
                    break;
                case ReturnCode.CONNECTION_REFUSED:
                    dialog = new Main.WarningDialog (_("Unable to reach the API"), _("Make sure your DNS is not blocking this."));
                    break;
                case ReturnCode.CONNECTION_UNKNOWN:
                    dialog = new Main.WarningDialog (_("Unable to reach the API"), _("The requested website does not seem to be valid."));
                    break;
                case ReturnCode.INVALID_ACCESS_TOKEN:
                    dialog = new Main.WarningDialog (_("Invalid access token"), _("Make sure the access token you provided is valid."));
                    break;
                default:
                    dialog = new Main.ErrorDialog (
                        _("Failed to Fetch Releases"),
                        _("ProtonPlus could not retrieve the list of available releases. Please check your internet connection and try again."),
                        ""
                    );
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
            apply_selected_variant_to_rows ();
            update_last_updated_label ();
            update_visibility ();
        }

        private void update_variant_btn (Models.Tool tool) {
            selected_variant = null;
            variant_button.set_visible (false);

            Gtk.Widget? child;
            while ((child = variant_popover_box.get_first_child ()) != null) {
                variant_popover_box.remove (child);
            }

            if (tool.variants.size <= 1) {
                return;
            }

            foreach (var variant in tool.variants) {
                var variant_row = new Gtk.Button ();
                variant_row.label = variant.name;
                variant_row.halign = Gtk.Align.FILL;
                variant_row.hexpand = true;
                variant_row.add_css_class ("flat");
                variant_row.clicked.connect (() => {
                    selected_variant = variant;
                    variant_button.set_label (variant.name);
                    save_selected_variant_name (tool, variant.name);
                    variant_popover.popdown ();
                    apply_selected_variant_to_rows ();
                });

                variant_popover_box.append (variant_row);

                if (variant.is_default == true) {
                    selected_variant = variant;
                }
            }

            var saved_variant_name = get_saved_variant_name (tool);
            if (saved_variant_name != "") {
                foreach (var variant in tool.variants) {
                    if (variant.name == saved_variant_name) {
                        selected_variant = variant;
                        break;
                    }
                }
            }

            if (selected_variant == null) {
                selected_variant = tool.variants.get (0);
            }

            variant_button.set_label (selected_variant.name);
            variant_button.set_visible (true);
        }

        private string? get_variant_download_url (Models.Release release, string variant_name) {
            foreach (var variant in release.variants) {
                if (variant.name == variant_name && variant.download_url != null && variant.download_url != "") {
                    return variant.download_url;
                }
            }

            return null;
        }

        private string? get_default_variant_download_url (Models.Release release) {
            foreach (var variant in release.variants) {
                if (variant.is_default && variant.download_url != null && variant.download_url != "") {
                    return variant.download_url;
                }
            }

            return null;
        }

        private bool is_latest_release (Models.Release release) {
            return release is Models.Releases.Latest;
        }

        private void apply_selected_variant_to_rows () {
            var child = list_box.get_first_child ();
            while (child != null) {
                var release = child.get_data<Models.Release> ("release");
                if (release != null) {
                    if (is_latest_release (release)) {
                        release.set_selected_variant (null);
                        child = child.get_next_sibling ();
                        continue;
                    }

                    string? selected_variant_url = null;

                    if (selected_variant != null) {
                        selected_variant_url = get_variant_download_url (release, selected_variant.name);
                    }

                    if (selected_variant_url != null) {
                        release.download_url = selected_variant_url;
                        release.set_selected_variant (selected_variant.name);
                    } else {
                        var default_url = get_default_variant_download_url (release);
                        if (default_url != null) {
                            release.download_url = default_url;
                        }

                        var default_variant_name = "";
                        foreach (var variant in release.variants) {
                            if (variant.is_default) {
                                default_variant_name = variant.name;
                                break;
                            }
                        }

                        release.set_selected_variant (default_variant_name != "" ? default_variant_name : null);
                    }
                }

                child = child.get_next_sibling ();
            }

            list_box.invalidate_filter ();
            update_visibility ();
        }

        private void update_last_updated_label () {
            if (current_tool == null || current_tool.last_updated == null || current_tool.last_updated == "") {
                last_updated_label.set_label ("");
                return;
            }

            var date = new DateTime.from_iso8601 (current_tool.last_updated, null);
            if (date != null) {
                last_updated_label.set_label (_("Last updated: %s").printf (date.format ("%Y-%m-%d %H:%M")));
            } else {
                last_updated_label.set_label ("");
            }
        }

        public void refresh_usage_pills () {
            var child = list_box.get_first_child ();
            while (child != null) {
                if (child is ReleaseRow) {
                    ((ReleaseRow) child).refresh_usage_pill ();
                }
                child = child.get_next_sibling ();
            }
            list_box.invalidate_filter ();
            update_visibility ();
        }

        private void add_release_row (Models.Release release) {
            ReleaseRow row;
            if (release is Models.Releases.SteamTinkerLaunch)
                row = new STLReleaseRow (release);
            else
                row = new ReleaseRow (release);

            //var firstVariant = release.variants.first ();
            //print ("Add Release row: %s, %s\n", firstVariant.name, firstVariant.download_url);
            row.set_data ("release", release);
            row.release_selected.connect ((release) => release_selected (release));

            list_box.append (row);

            if (selected_variant != null) {
                if (is_latest_release (release)) {
                    release.set_selected_variant (null);
                    return;
                }

                var selected_variant_url = get_variant_download_url (release, selected_variant.name);
                if (selected_variant_url != null) {
                    release.download_url = selected_variant_url;
                    release.set_selected_variant (selected_variant.name);
                } else {
                    var default_url = get_default_variant_download_url (release);
                    if (default_url != null) {
                        release.download_url = default_url;
                    }

                    var default_variant_name = "";
                    foreach (var variant in release.variants) {
                        if (variant.is_default) {
                            default_variant_name = variant.name;
                            break;
                        }
                    }

                    release.set_selected_variant (default_variant_name != "" ? default_variant_name : null);
                }
            }
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

                Utils.CacheManager.save_releases.begin (current_tool);
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

            if (is_latest_release (release))
                return true;

            if (selected_variant != null && current_tool != null && current_tool.variants.size > 1) {
                if (get_variant_download_url (release, selected_variant.name) == null) {
                    return false;
                }
            }

            if (filter == Filter.ALL)
                return true;

            if (filter == Filter.INSTALLED)
                return release.state == Models.Release.State.UP_TO_DATE || release.state == Models.Release.State.UPDATE_AVAILABLE;

            var usage_count = release.runner.group.launcher.get_compatibility_tool_usage_count (
                release.title != "SteamTinkerLaunch" ? release.title : "Proton-stl"
            );

            if (filter == Filter.USED)
                return usage_count > 0;

            if (filter == Filter.UNUSED)
                return usage_count == 0;

            return true;
        }
    }
}
