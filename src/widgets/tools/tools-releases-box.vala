namespace ProtonPlus.Widgets.Tools {
    public class ReleasesBox : Gtk.Box {
        public signal void job_selected (Services.InstallJob job);

        Gtk.Box tool_box { get; set; }
        Gtk.Label title_label { get; set; }
        public Gtk.Box header_title { get; private set; }
        public Gtk.Label last_updated_label { get; private set; }
        public Gtk.Button refresh_button { get; private set; }
        Gtk.ListBox list_box { get; set; }
        Gtk.ScrolledWindow scrolled { get; set; }
        Gtk.Stack content_stack { get; set; }
        Adw.StatusPage status_page { get; set; }

        private Models.Tool? current_tool;
        // State changes are observed only for rows in the currently displayed
        // catalog.  Disconnect them before replacing the rows so completed
        // background jobs cannot refresh an unrelated tool's filters.
        private Gee.HashMap<Services.InstallJob, ulong> job_state_handlers = new Gee.HashMap<Services.InstallJob, ulong> ();
        // Incremented whenever a tool request replaces the visible tool state.
        // Async completions must match both this generation and their tool before
        // they are allowed to update the UI.
        private uint tool_request_generation = 0;
        Models.Variant? selected_variant = null;
        private Gee.LinkedList<Models.Variant> displayed_variants = new Gee.LinkedList<Models.Variant> ();
        Gtk.DropDown variant_dropdown { get; set; }
        HashTable<Gtk.StringObject, Gtk.ListItem> variant_list_items;
        Gtk.Image? selected_variant_checkmark = null;
        public Gtk.Box variant_box { get; private set; }
        bool header_controls_visible = false;
        bool has_variants = false;
        bool provider_has_compatible_variants = true;
        bool updating_variant_dropdown = false;
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

        private static string get_variant_tooltip (string variant_name) {
            switch (variant_name) {
            case "x86_64":
                return _("Standard 64-bit build for most Intel and AMD PCs.");
            case "x86_64_v3":
                return _("Optimized 64-bit build for Intel and AMD CPUs that support the x86-64-v3 instruction set.");
            case "arm64":
            case "aarch64":
                return _("64-bit ARM build. Choose this only on ARM64 hardware.");
            case "x86":
                return _("32-bit x86 build. Choose this only when a 32-bit runner is required.");
            case "wow64":
            case "x86_64_wow64":
                return _("64-bit build with WoW64 support for running 32-bit Windows applications.");
            case "default":
                return _("The provider's recommended build for most systems.");
            default:
                return _("Select the %s build variant.").printf (variant_name);
            }
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

            variant_list_items = new HashTable<Gtk.StringObject, Gtk.ListItem> (null, null);

            title_label = new Gtk.Label (null) {
                halign = Gtk.Align.CENTER,
                xalign = 0.5f,
                css_classes = { "title-4" }
            };

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                valign = Gtk.Align.CENTER
            };
            title_box.append (title_label);

            var icon = new Gtk.Image.from_icon_name ("screwdriver-wrench-symbolic") {
                valign = Gtk.Align.CENTER
            };

            header_title = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            header_title.append (icon);
            header_title.append (title_box);

            last_updated_label = new Gtk.Label (null) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                xalign = 0.5f,
                css_classes = { "caption" }
            };
            title_box.append (last_updated_label);

            refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Check for new releases")
            };
            refresh_button.add_css_class ("flat");
            refresh_button.clicked.connect (on_refresh_clicked);

            Gtk.Expression expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");

            variant_dropdown = new Gtk.DropDown (null, expression) {
                visible = false,
                tooltip_text = _("Choose which architecture or build variant to show.")
            };
            variant_dropdown.set_valign (Gtk.Align.CENTER);
            variant_dropdown.set_hexpand (false);
            variant_dropdown.notify["selected"].connect (on_variant_selected);

            var variant_list_factory = new Gtk.SignalListItemFactory ();
            variant_list_factory.setup.connect (on_variant_list_item_setup);
            variant_list_factory.bind.connect (on_variant_list_item_bind);
            variant_list_factory.unbind.connect (on_variant_list_item_unbind);
            variant_dropdown.set_list_factory (variant_list_factory);

            variant_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                visible = false,
                hexpand = false,
                valign = Gtk.Align.CENTER,
                margin_top = 0,
                margin_bottom = 0
            };

            variant_box.append (variant_dropdown);

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

            disconnect_job_state_handlers ();
            list_box.remove_all ();

            title_label.set_label (tool.title);
            title_label.set_tooltip_text (tool.description);
            update_last_updated_label ();
            update_variant_row (tool);

            var catalog = tool.release_catalog;
            if (catalog == null) {
                content_stack.set_visible_child_name ("empty");
                return;
            }

            var result = yield catalog.load (false);

            if (!is_current_tool_request (tool, request_generation))
                return;

            if (!result.succeeded) {
                Adw.AlertDialog dialog = new Main.ErrorDialog (
                    _("Failed to Fetch Releases"),
                    get_return_code_message (result.code),
                    ""
                );

                content_stack.set_visible_child_name ("list");

                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());

                return;
            }

            // Directory and legacy-tag fallback resolution depends on the
            // available release names.  Refresh explicitly after that catalog
            // changes; list filters themselves remain pure state readers.
            tool.group.refresh_installed_state ();
            add_release_rows (tool, result.releases);

            list_box.append (load_more_row);
            load_more_row.visible = catalog.has_more && can_show_provider_release_rows ();

            content_stack.set_visible_child_name ("list");
            apply_selected_variant_to_rows ();
            update_last_updated_label ();
            update_visibility ();
        }

        private void on_variant_list_item_setup (Object object) {
            var list_item = object as Gtk.ListItem;
            var label = new Gtk.Label (null) {
                xalign = 0.0f,
                hexpand = true
            };
            var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic") {
                visible = false
            };
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                hexpand = true
            };
            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true,
                margin_top = 6,
                margin_bottom = 6,
                margin_start = 12,
                margin_end = 12
            };
            content.append (label);
            content.append (checkmark);
            row.append (content);

            object.set_data ("variant-label", label);
            object.set_data ("variant-checkmark", checkmark);
            object.set_data ("variant-row", row);
            list_item.set_child (row);
        }

        private void on_variant_list_item_bind (Object object) {
            var list_item = object as Gtk.ListItem;
            var variant = list_item.item as Gtk.StringObject;
            if (variant == null)
                return;

            variant_list_items.set (variant, list_item);

            var variant_name = variant.string;
            var tooltip = get_variant_tooltip (variant_name);
            var label = object.get_data<Gtk.Label> ("variant-label");
            var checkmark = object.get_data<Gtk.Image> ("variant-checkmark");
            var row = object.get_data<Gtk.Box> ("variant-row");
            var list_row = row.get_parent ();

            label.set_label (variant_name);
            if (list_row != null)
                list_row.set_tooltip_text (tooltip);
            checkmark.set_visible (variant == variant_dropdown.selected_item);
            if (checkmark.visible)
                selected_variant_checkmark = checkmark;
        }

        private void on_variant_list_item_unbind (Object object) {
            var list_item = object as Gtk.ListItem;
            var variant = list_item.item as Gtk.StringObject;
            if (variant != null && variant_list_items.get (variant) == list_item)
                variant_list_items.remove (variant);

            var checkmark = object.get_data<Gtk.Image> ("variant-checkmark");
            if (checkmark == selected_variant_checkmark)
                selected_variant_checkmark = null;
        }

        private void update_variant_list_item_checkmark () {
            if (selected_variant_checkmark != null)
                selected_variant_checkmark.set_visible (false);

            var selected_item = variant_dropdown.selected_item as Gtk.StringObject;
            var list_item = selected_item != null ? variant_list_items.get (selected_item) : null;
            if (list_item == null) {
                selected_variant_checkmark = null;
                return;
            }

            selected_variant_checkmark = list_item.get_data<Gtk.Image> ("variant-checkmark");
            selected_variant_checkmark.set_visible (true);
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

            disconnect_job_state_handlers ();
            list_box.remove_all ();

            title_label.set_label (tool.title);
            title_label.set_tooltip_text (tool.description);

            var catalog = tool.release_catalog;
            if (catalog == null) {
                content_stack.set_visible_child_name ("empty");
                return;
            }

            var result = yield catalog.refresh ();

            if (!is_current_tool_request (tool, request_generation))
                return;

            if (!result.succeeded) {
                Adw.AlertDialog dialog = new Main.ErrorDialog (
                    _("Failed to Fetch Releases"),
                    get_return_code_message (result.code),
                    ""
                );

                content_stack.set_visible_child_name ("list");

                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());

                return;
            }

            tool.group.refresh_installed_state ();
            add_release_rows (tool, result.releases);

            list_box.append (load_more_row);
            load_more_row.visible = catalog.has_more && can_show_provider_release_rows ();

            content_stack.set_visible_child_name ("list");
            apply_selected_variant_to_rows ();
            update_last_updated_label ();
            update_visibility ();
        }

        private void update_variant_row (Models.Tool tool) {
            selected_variant = null;
            displayed_variants.clear ();
            has_variants = false;
            provider_has_compatible_variants = true;
            variant_dropdown.set_visible (false);
            variant_box.set_visible (false);

            var provider_tool = tool as Models.Tools.ProviderTool;
            if (provider_tool == null) {
                status_page.set_description (_("No releases match the current filter."));
                return;
            }

            displayed_variants = Models.VariantSelector.compatible_variants (
                provider_tool.variants, Globals.CPU_CAPABILITIES
            );
            provider_has_compatible_variants = displayed_variants.size > 0;
            if (!provider_has_compatible_variants) {
                status_page.set_description (_("No compatible variants are available for this system."));
                return;
            }

            status_page.set_description (_("No releases match the current filter."));
            selected_variant = Models.VariantSelector.select_variant (
                displayed_variants, Globals.CPU_CAPABILITIES, get_saved_variant_name (tool)
            );
            if (!Models.VariantSelector.should_show_dropdown (displayed_variants))
                return;

            var model = new Gtk.StringList (null);
            int selected_index = 0;
            int index = 0;
            foreach (var variant in displayed_variants) {
                model.append (variant.name);
                if (variant == selected_variant)
                    selected_index = index;
                index++;
            }

            updating_variant_dropdown = true;
            variant_dropdown.model = model;
            variant_dropdown.selected = (uint) selected_index;
            updating_variant_dropdown = false;
            update_variant_list_item_checkmark ();
            variant_dropdown.set_visible (true);
            has_variants = true;
            variant_box.set_visible (header_controls_visible);
        }

        public void set_header_controls_visible (bool visible) {
            header_controls_visible = visible;
            variant_box.set_visible (visible && has_variants);
            last_updated_label.set_visible (visible && last_updated_label.get_label () != "");
            refresh_button.set_visible (visible);
        }

        private void on_variant_selected () {
            if (updating_variant_dropdown || current_tool == null || displayed_variants.size <= 1)
                return;

            int selected_index = (int) variant_dropdown.selected;
            var variant = Models.VariantSelector.variant_at_display_index (displayed_variants, selected_index);
            if (variant == null)
                return;

            update_variant_list_item_checkmark ();

            if (selected_variant == variant)
                return;

            selected_variant = variant;
            save_selected_variant_name (current_tool, variant.name);
            apply_selected_variant_to_rows ();
        }

        private Models.Variant? resolve_release_variant (Models.Release release, Services.InstallJob.Mode mode) {
            return Models.VariantSelector.resolve_release_variant (
                release, selected_variant, Globals.CPU_CAPABILITIES,
                mode == Services.InstallJob.Mode.LATEST
            );
        }

        private bool apply_selected_variant_to_job (Services.InstallJob job) {
            if (!(job.tool is Models.Tools.ProviderTool))
                return true;

            var variant = resolve_release_variant (job.release, job.mode);
            if (variant == null || variant.download_url == null || variant.download_url == "")
                return false;

            job.set_selected_variant (
                variant.name, ProtonPlus.Models.Assets.Asset.from_download_url (variant.download_url), variant.id
            );
            return true;
        }

        private void apply_selected_variant_to_rows () {
            var child = list_box.get_first_child ();
            while (child != null) {
                var job = child.get_data<Services.InstallJob> ("job");
                if (job != null)
                    apply_selected_variant_to_job (job);

                child = child.get_next_sibling ();
            }

            list_box.invalidate_filter ();
            update_visibility ();
        }

        private void update_last_updated_label () {
            if (current_tool == null || current_tool.release_catalog == null ||
                current_tool.release_catalog.last_updated == "") {
                last_updated_label.set_label ("");
                last_updated_label.set_visible (false);
                return;
            }

            var date = new DateTime.from_iso8601 (current_tool.release_catalog.last_updated, null);
            if (date != null) {
                last_updated_label.set_label (_("Last updated: %s").printf (date.format ("%Y-%m-%d %H:%M")));
            } else {
                last_updated_label.set_label ("");
            }

            last_updated_label.set_visible (header_controls_visible && last_updated_label.get_label () != "");
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
        public async void focus_job (Services.InstallJob target) {
            yield set_selected_tool (target.tool);

            var row = find_job_row (target);
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

        private ReleaseRow? find_job_row (Services.InstallJob target) {
            var child = list_box.get_first_child ();
            while (child != null) {
                var job = child.get_data<Services.InstallJob> ("job");
                if (job != null && (job == target || jobs_have_same_identity (job, target))) {
                    return child as ReleaseRow;
                }
                child = child.get_next_sibling ();
            }

            return null;
        }

        private bool jobs_have_same_identity (Services.InstallJob left, Services.InstallJob right) {
            if (left.tool.id != right.tool.id || left.mode != right.mode)
                return false;

            if (left.release.upstream_release_id != "" && right.release.upstream_release_id != "")
                return left.release.upstream_release_id == right.release.upstream_release_id;

            return left.release.source_tag != "" && right.release.source_tag != "" &&
                   left.release.source_tag == right.release.source_tag;
        }

        private void add_release_rows (Models.Tool tool, Gee.LinkedList<Models.Release> releases) {
            if (tool is Models.Tools.ProviderTool && releases.size > 0)
                add_release_row (releases[0], Services.InstallJob.Mode.LATEST);
            foreach (var release in releases)
                add_release_row (release);
        }

        private void add_release_row (
            Models.Release release,
            Services.InstallJob.Mode mode = Services.InstallJob.Mode.VERSIONED
        ) {
            if (current_tool == null)
                return;
            var job = new Services.InstallJob (release, current_tool, mode);
            if (!apply_selected_variant_to_job (job))
                return;

            var active_job = Utils.DownloadManager.instance.get_active_download (job);
            if (active_job != null)
                job = active_job;

            if (job_state_handlers.has_key (job))
                job.disconnect (job_state_handlers.get (job));
            job_state_handlers.set (job, job.notify["state"].connect (() => {
                if (job.state != Services.InstallJob.State.BUSY_INSTALLING &&
                    job.state != Services.InstallJob.State.BUSY_REMOVING &&
                    job.state != Services.InstallJob.State.BUSY_UPDATING) {
                    list_box.invalidate_filter ();
                    update_visibility ();
                }
            }));

            ReleaseRow row;
            if (job.tinker_game_context != null) {
                row = new TinkerGameReleaseRow (job);
                if (active_job == null)
                    Services.InstallationService.instance.refresh_tinker_game_release.begin (job);
            } else {
                row = new ReleaseRow (job);
            }
            row.set_data ("job", job);
            row.job_selected.connect ((selected_job) => job_selected (selected_job));
            list_box.append (row);
        }

        private void disconnect_job_state_handlers () {
            foreach (var entry in job_state_handlers.entries)
                entry.key.disconnect (entry.value);
            job_state_handlers.clear ();
        }

        public override void dispose () {
            disconnect_job_state_handlers ();
            base.dispose ();
        }

        private async void on_load_more_clicked () {
            if (current_tool == null)
                return;

            Models.Tool tool = current_tool;
            uint request_generation = tool_request_generation;
            load_more_button.sensitive = false;

            var catalog = tool.release_catalog;
            if (catalog == null) {
                load_more_button.sensitive = true;
                return;
            }

            var result = yield catalog.load_more ();

            if (!is_current_tool_request (tool, request_generation))
                return;

            if (result.succeeded) {
                foreach (var release in result.releases) {
                    add_release_row (release, Services.InstallJob.Mode.VERSIONED);
                }
                tool.group.refresh_installed_state ();
                list_box.remove (load_more_row);
                list_box.append (load_more_row);
            }

            load_more_row.visible = catalog.has_more && can_show_provider_release_rows ();
            load_more_button.sensitive = true;
            update_visibility ();
        }

        private bool is_current_tool_request (Models.Tool tool, uint request_generation) {
            return current_tool == tool && tool_request_generation == request_generation;
        }

        private bool can_show_provider_release_rows () {
            return !(current_tool is Models.Tools.ProviderTool) || provider_has_compatible_variants;
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
            var job = row.get_data<Services.InstallJob> ("job");
            if (job == null)
                return true;

            if (search_text != "" && !job.title.down ().contains (search_text.down ()))
                return false;

            var provider_tool = current_tool as Models.Tools.ProviderTool;
            if (provider_tool != null && (!provider_has_compatible_variants ||
                resolve_release_variant (job.release, job.mode) == null))
                return false;

            if (filter == Filter.ALL)
                return true;

            if (filter == Filter.INSTALLED)
                return job.state == Services.InstallJob.State.UP_TO_DATE || job.state == Services.InstallJob.State.UPDATE_AVAILABLE;

            var usage_count = job.tool.group.launcher.get_compatibility_tool_usage_count (job.get_usage_identifier ());

            if (filter == Filter.USED)
                return usage_count > 0;

            if (filter == Filter.UNUSED)
                return usage_count == 0;

            return true;
        }
    }
}
