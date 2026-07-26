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
        Gtk.ScrolledWindow scrolled { get; set; }
        Gtk.Stack content_stack { get; set; }
        Adw.StatusPage status_page { get; set; }

        private Models.Tool? current_tool;
        // Incremented whenever a tool request replaces the visible tool state.
        // Async completions must match both this generation and their tool before
        // they are allowed to update the UI.
        private uint tool_request_generation = 0;
        Models.Variant? selected_variant = null;
        Gtk.DropDown variant_dropdown { get; set; }
        Gtk.Box variant_box { get; set; }
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

        private static string get_tool_variant_settings_key (Models.Tool tool) {
            return tool.id;
        }

        private static string get_legacy_tool_variant_settings_key (Models.Tool tool) {
            return "%s::%s::%s".printf (tool.group.launcher.title, tool.group.title, tool.title);
        }

        private string get_saved_variant_name (Models.Tool tool) {
            if (Globals.SETTINGS == null)
                return "";

            return get_saved_variant_name_from_json (Globals.SETTINGS.get_string ("selected-tool-variants"), tool);
        }

        public static string get_saved_variant_name_from_json (string raw, Models.Tool tool) {
            if (raw == "")
                return "";

            var root_node = Utils.Parser.get_node_from_json (raw);
            if (root_node == null || root_node.get_node_type () != Json.NodeType.OBJECT)
                return "";

            var root_obj = root_node.get_object ();
            var saved_variant_name = root_obj.get_string_member_with_default (get_tool_variant_settings_key (tool), "");
            if (saved_variant_name != "")
                return saved_variant_name;

            return root_obj.get_string_member_with_default (get_legacy_tool_variant_settings_key (tool), "");
        }

        private void save_selected_variant_name (Models.Tool tool, string variant_name) {
            if (Globals.SETTINGS == null)
                return;

            Globals.SETTINGS.set_string (
                "selected-tool-variants",
                get_json_with_saved_variant_name (
                    Globals.SETTINGS.get_string ("selected-tool-variants"), tool, variant_name
                )
            );
        }

        public static string get_json_with_saved_variant_name (string raw, Models.Tool tool, string variant_name) {
            Json.Object root_obj;
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
            return generator.to_data (null);
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

            Gtk.Expression expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");

            variant_dropdown = new Gtk.DropDown (null, expression) {
                visible = false
            };
            variant_dropdown.set_valign (Gtk.Align.CENTER);
            variant_dropdown.set_hexpand (false);
            variant_dropdown.notify["selected"].connect (on_variant_selected);

            variant_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                visible = false,
                hexpand = false,
                valign = Gtk.Align.CENTER,
                margin_top = 0,
                margin_bottom = 0
            };

            variant_box.append (variant_dropdown);

            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (info_box);
            header_box.append (variant_box);
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

            scrolled = new Gtk.ScrolledWindow () {
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
            uint request_generation = ++tool_request_generation;
            current_tool = tool;
            content_stack.set_visible_child_name ("spinner");
            load_more_button.sensitive = true;

            list_box.remove_all ();

            title_label.set_label (tool.title);
            desc_label.set_label (tool.description);
            update_last_updated_label ();
            update_variant_row (tool);

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield tool.get_releases_async (false, out code);

            if (!is_current_tool_request (tool, request_generation))
                return;

            if (code != ReturnCode.RELEASES_LOADED) {
                Adw.AlertDialog dialog = new Main.ErrorDialog (
                    _("Failed to Fetch Releases"),
                    get_return_code_message (code),
                    ""
                );

                content_stack.set_visible_child_name ("list");

                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());

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
            if (current_tool == null)
                return;
            set_selected_tool_forced.begin (current_tool);
        }

        private async void set_selected_tool_forced (Models.Tool tool) {
            uint request_generation = ++tool_request_generation;
            current_tool = tool;
            content_stack.set_visible_child_name ("spinner");
            load_more_button.sensitive = true;

            list_box.remove_all ();

            title_label.set_label (tool.title);
            desc_label.set_label (tool.description);

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield tool.get_releases_async (true, out code);

            if (!is_current_tool_request (tool, request_generation))
                return;

            if (code != ReturnCode.RELEASES_LOADED) {
                Adw.AlertDialog dialog = new Main.ErrorDialog (
                    _("Failed to Fetch Releases"),
                    get_return_code_message (code),
                    ""
                );

                content_stack.set_visible_child_name ("list");

                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());

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

        private void update_variant_row (Models.Tool tool) {
            selected_variant = null;
            variant_dropdown.set_visible (false);
            variant_box.set_visible (false);

            if (tool.variants.size <= 1) {
                return;
            }

            var model = new Gtk.StringList (null);
            int selected_index = -1;
            int default_index = -1;
            int index = 0;

            var saved_variant_name = get_saved_variant_name (tool);

            foreach (var variant in tool.variants) {
                model.append (variant.name);

                if (variant.is_default == true) {
                    selected_variant = variant;
                    default_index = index;
                }

                if (saved_variant_name != "" && variant.name == saved_variant_name) {
                    selected_variant = variant;
                    selected_index = index;
                }

                index++;
            }

            if (selected_variant == null) {
                selected_variant = tool.variants.get (0);
                selected_index = 0;
            } else if (selected_index == -1) {
                selected_index = default_index >= 0 ? default_index : 0;
            }

            variant_dropdown.model = model;
            variant_dropdown.selected = (uint) selected_index;
            variant_dropdown.set_visible (true);
            variant_box.set_visible (true);
        }

        private void on_variant_selected () {
            if (current_tool == null || current_tool.variants.size <= 1)
                return;

            int selected_index = (int) variant_dropdown.selected;
            if (selected_index < 0 || selected_index >= current_tool.variants.size)
                return;

            var variant = current_tool.variants.get (selected_index);
            if (selected_variant != null && selected_variant.name == variant.name)
                return;

            selected_variant = variant;
            save_selected_variant_name (current_tool, variant.name);
            apply_selected_variant_to_rows ();
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
                    string? selected_variant_url = null;

                    if (selected_variant != null) {
                        selected_variant_url = get_variant_download_url (release, selected_variant.name);
                    }

                    if (selected_variant_url != null) {
                        release.set_selected_variant (
                            selected_variant.name,
                            Models.Internal.Assets.Asset.from_download_url (selected_variant_url)
                        );
                    } else {
                        var default_url = get_default_variant_download_url (release);
                        var default_variant_name = "";
                        foreach (var variant in release.variants) {
                            if (variant.is_default) {
                                default_variant_name = variant.name;
                                break;
                            }
                        }

                        release.set_selected_variant (
                            default_variant_name != "" ? default_variant_name : null,
                            default_url != null ? Models.Internal.Assets.Asset.from_download_url (default_url) : null
                        );
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

        /// Selects the release's tool and makes its active row easy to find.
        public async void focus_release (Models.Release target) {
            yield set_selected_tool (target.runner);

            var row = find_release_row (target);
            if (row == null)
                return;

            row.grab_focus ();
            row.add_css_class ("download-highlight");

            Idle.add (() => {
                Graphene.Rect bounds;
                if (row.compute_bounds (list_box, out bounds)) {
                    var adjustment = scrolled.get_vadjustment ();
                    var maximum = adjustment.upper - adjustment.page_size;
                    if (maximum < adjustment.lower)
                        maximum = adjustment.lower;

                    var target_value = bounds.origin.y - ((adjustment.page_size - bounds.size.height) / 2.0);
                    if (target_value < adjustment.lower)
                        target_value = adjustment.lower;
                    if (target_value > maximum)
                        target_value = maximum;
                    adjustment.set_value (target_value);
                }
                return Source.REMOVE;
            });

            Timeout.add (1200, () => {
                row.remove_css_class ("download-highlight");
                return Source.REMOVE;
            });
        }

        private ReleaseRow? find_release_row (Models.Release target) {
            var child = list_box.get_first_child ();
            while (child != null) {
                var release = child.get_data<Models.Release> ("release");
                if (release != null && (release == target || releases_have_same_identity (release, target))) {
                    return child as ReleaseRow;
                }
                child = child.get_next_sibling ();
            }

            return null;
        }

        private bool releases_have_same_identity (Models.Release left, Models.Release right) {
            if (left.runner.id != right.runner.id)
                return false;

            if (left.upstream_release_id != "" && right.upstream_release_id != "")
                return left.upstream_release_id == right.upstream_release_id;

            return left.source_tag != "" && right.source_tag != "" &&
                   left.source_tag == right.source_tag;
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

            if (selected_variant != null) {
                var selected_variant_url = get_variant_download_url (release, selected_variant.name);
                if (selected_variant_url != null) {
                    release.set_selected_variant (
                        selected_variant.name,
                        Models.Internal.Assets.Asset.from_download_url (selected_variant_url)
                    );
                } else {
                    var default_url = get_default_variant_download_url (release);
                    var default_variant_name = "";
                    foreach (var variant in release.variants) {
                        if (variant.is_default) {
                            default_variant_name = variant.name;
                            break;
                        }
                    }

                    release.set_selected_variant (
                        default_variant_name != "" ? default_variant_name : null,
                        default_url != null ? Models.Internal.Assets.Asset.from_download_url (default_url) : null
                    );
                }
            }
        }

        private async void on_load_more_clicked () {
            if (current_tool == null)
                return;

            Models.Tool tool = current_tool;
            uint request_generation = tool_request_generation;
            load_more_button.sensitive = false;

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield tool.load_more (out code);

            if (!is_current_tool_request (tool, request_generation))
                return;

            if (code == ReturnCode.RELEASES_LOADED) {
                foreach (var release in releases) {
                    tool.releases.add (release);
                    add_release_row (release);
                }
                list_box.remove (load_more_row);
                list_box.append (load_more_row);

                Utils.CacheManager.save_releases.begin (tool);
            }

            load_more_row.visible = tool.has_more;
            load_more_button.sensitive = true;
            update_visibility ();
        }

        private bool is_current_tool_request (Models.Tool tool, uint request_generation) {
            return current_tool == tool && tool_request_generation == request_generation;
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

            var usage_count = release.runner.group.launcher.get_compatibility_tool_usage_count (release.get_usage_identifier ());

            if (filter == Filter.USED)
                return usage_count > 0;

            if (filter == Filter.UNUSED)
                return usage_count == 0;

            return true;
        }
    }
}
