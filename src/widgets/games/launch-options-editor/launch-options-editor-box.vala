using ProtonPlus.LaunchOptions;

namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    public class Box : Gtk.Box {
        public signal void content_changed ();

        Groups.CommonOptionsGroup common_group;
        Groups.DxvkOptionsGroup dxvk_options_group;
        Groups.Vkd3dOptionsGroup vkd3d_options_group;
        Groups.MoreOptionsGroup more_options_group;
        Groups.ProtonOptionsGroup proton_options_group;
        Groups.AudioOptionsGroup audio_group;
        Groups.GameArgumentsGroup game_arguments_group;
        Groups.AdvancedOptionsGroup advanced_options_group;
        Groups.GpuVendorOptionsGroup gpu_vendor_group;
        Groups.WrapperGroup wrapper_group;
        internal LaunchOptionPreviewField preview_field { get; private set; }
        LaunchOptionsList launch_option_handlers;
        LaunchOptionCatalog catalog;
        LaunchOptionPresentationRegistry presentations;
        LaunchCommandEditorProjection projection;
        LaunchCommandWriter writer;
        LaunchOptionCapabilityResolver capability_resolver;
        LaunchCommandCapabilityContext? capability_context;
        LaunchCommandEditState edit_state;
        string loaded_source;
        Gee.ArrayList<string> preview_source_labels;
        Gee.ArrayList<string> preview_sources;
        Gee.HashMap<string, string> field_diagnostics;
        Gee.List<string> adapter_diagnostics;
        Gee.ArrayList<LaunchOptionPresentation> automatic_dependencies;
        LaunchOptionPresentation? dependency_to_configure;
        internal string dependency_action_label { get; private set; default = ""; }

        Gtk.Button add_button;
        Gtk.Label empty_label;
        Adw.PreferencesGroup current_group;
        Gee.HashMap<string, Adw.PreferencesRow> current_rows;
        Gee.HashMap<string, Gtk.Button> remove_buttons;
        Gee.HashMap<string, string> configured_values;
        Gee.HashSet<string> removed_options;
        Gee.HashSet<string> draft_options;
        weak Adw.Dialog? picker;
        weak Gtk.Widget? picker_selection;
        bool refreshing_controls;
        ulong preview_theme_handler;

        LaunchOptionCategory[] canonical_categories = {
            LaunchOptionCategory.PERFORMANCE,
            LaunchOptionCategory.DISPLAY,
            LaunchOptionCategory.PROTON,
            LaunchOptionCategory.GRAPHICS,
            LaunchOptionCategory.HARDWARE,
            LaunchOptionCategory.INPUT_AUDIO,
            LaunchOptionCategory.GAME_ARGUMENTS,
            LaunchOptionCategory.DIAGNOSTICS
        };

        construct {
            launch_option_handlers = new LaunchOptionsList ();
            catalog = new LaunchOptionCatalog ();
            presentations = new LaunchOptionPresentationRegistry (catalog);
            projection = new LaunchCommandEditorProjection (catalog);
            writer = new LaunchCommandWriter (catalog);
            capability_resolver = new LaunchOptionCapabilityResolver (catalog);
            edit_state = new LaunchCommandEditState ();
            loaded_source = "";
            preview_source_labels = new Gee.ArrayList<string> ();
            preview_sources = new Gee.ArrayList<string> ();
            field_diagnostics = new Gee.HashMap<string, string> ();
            automatic_dependencies = new Gee.ArrayList<LaunchOptionPresentation> ();
            preview_source_labels.add ("");
            preview_sources.add (loaded_source);
            current_rows = new Gee.HashMap<string, Adw.PreferencesRow> ();
            remove_buttons = new Gee.HashMap<string, Gtk.Button> ();
            configured_values = new Gee.HashMap<string, string> ();
            removed_options = new Gee.HashSet<string> ();
            draft_options = new Gee.HashSet<string> ();
            refreshing_controls = true;

            set_orientation (Gtk.Orientation.VERTICAL);

            preview_field = new LaunchOptionPreviewField ();
            current_group = new Adw.PreferencesGroup () { title = Markup.escape_text (_("Launch options")) };
            append (current_group);
            empty_label = new Gtk.Label (_("No launch options configured yet.")) {
                xalign = 0, wrap = true, css_classes = { "dim-label" }
            };
            current_group.add (empty_label);
            add_button = new Gtk.Button.with_label (_("Add launch option")) {
                valign = Gtk.Align.CENTER, css_classes = { "flat" }
            };
            add_button.clicked.connect (open_picker);
            current_group.header_suffix = add_button;
            unmap.connect (close_picker);

            common_group = new Groups.CommonOptionsGroup (launch_option_handlers, presentations);
            common_group.changed.connect (standard_control_changed);
            wrapper_group = new Groups.WrapperGroup (launch_option_handlers, presentations);
            presentations.register_selection_source ("launch-backend", new LaunchCommandStaticSelectionSource (
                "launch-backend", null
            ));
            wrapper_group.changed.connect (standard_control_changed);
            gpu_vendor_group = new Groups.GpuVendorOptionsGroup (launch_option_handlers, presentations);
            gpu_vendor_group.changed.connect (standard_control_changed);
            dxvk_options_group = new Groups.DxvkOptionsGroup (launch_option_handlers, presentations);
            dxvk_options_group.changed.connect (standard_control_changed);
            vkd3d_options_group = new Groups.Vkd3dOptionsGroup (launch_option_handlers, presentations);
            vkd3d_options_group.changed.connect (standard_control_changed);
            more_options_group = new Groups.MoreOptionsGroup (launch_option_handlers, presentations);
            more_options_group.changed.connect (standard_control_changed);
            proton_options_group = new Groups.ProtonOptionsGroup (launch_option_handlers, presentations);
            proton_options_group.changed.connect (standard_control_changed);
            audio_group = new Groups.AudioOptionsGroup (launch_option_handlers, presentations);
            audio_group.changed.connect (standard_control_changed);
            game_arguments_group = new Groups.GameArgumentsGroup (launch_option_handlers, presentations);
            game_arguments_group.changed.connect (standard_control_changed);
            advanced_options_group = new Groups.AdvancedOptionsGroup (launch_option_handlers, presentations);
            advanced_options_group.changed.connect (standard_control_changed);

            var actions = new SimpleActionGroup ();
            var remove_action = new SimpleAction ("remove", VariantType.STRING);
            remove_action.activate.connect (remove_requested);
            actions.add_action (remove_action);
            insert_action_group ("launch-options", actions);
            build_current_rows ();
            adapter_diagnostics = presentations.validate_selection_sources ();
            refreshing_controls = false;
            preview_theme_handler = Adw.StyleManager.get_default ().notify["dark"].connect (refresh_preview);
            refresh_state ();
        }

        public override void dispose () {
            if (preview_theme_handler != 0) {
                Adw.StyleManager.get_default ().disconnect (preview_theme_handler);
                preview_theme_handler = 0;
            }
            base.dispose ();
        }

        internal Gtk.Widget get_initial_focus () {
            return add_button;
        }

        void build_current_rows () {
            foreach (var metadata in catalog.get_ordered ()) {
                if (metadata.id == "steam-command")
                    continue;
                var control = presentations.lookup (metadata.id);
                var single_widget = control != null && control.widgets.size == 1 ? control.widgets[0] : null;
                var tile = single_widget as LaunchOptionTile;
                Adw.ActionRow? inline_row = tile;
                if (single_widget is LaunchOptionSpinTile || single_widget is LaunchOptionEnvCombo)
                    inline_row = (Adw.ActionRow) single_widget;
                var embedded_expander = single_widget as Adw.ExpanderRow;
                Adw.ExpanderRow? expander = null;
                if (inline_row == null) {
                    expander = embedded_expander ?? new Adw.ExpanderRow ();
                    expander.title = metadata.title;
                    expander.use_markup = false;
                    expander.subtitle_lines = 2;
                }
                var remove = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
                    valign = Gtk.Align.CENTER, css_classes = { "flat" }
                };
                remove.tooltip_text = _("Remove %s").printf (metadata.title);
                remove.update_property (Gtk.AccessibleProperty.LABEL, remove.tooltip_text, -1);
                var option_id = metadata.id;
                remove.action_name = "launch-options.remove";
                remove.action_target = new Variant.string (option_id);
                if (embedded_expander != null) {
                    weak Box editor = this;
                    embedded_expander.notify["expanded"].connect ((sender, property) => {
                        if (((Adw.ExpanderRow) sender).expanded)
                            editor?.draft_options.add (option_id);
                    });
                }
                if (tile != null) {
                    // The picker enables this option and Remove clears it.
                    tile.set_activatable_widget (null);
                    tile.activatable = false;
                    tile.remove (tile.toggle);
                }
                if (inline_row != null)
                    inline_row.add_suffix (remove);
                else
                    expander.add_suffix (remove);
                if (control != null) {
                    foreach (var widget in control.widgets) {
                        // Keep the original controls and their state adapters together.
                        var group = widget.get_parent ()?.get_ancestor (typeof (Adw.PreferencesGroup)) as Adw.PreferencesGroup;
                        var field = widget as LaunchOptionEntryField;
                        var preferences_row = widget as Adw.PreferencesRow;
                        if (preferences_row != null)
                            preferences_row.use_markup = false;
                        if (group != null) {
                            group.remove (widget);
                            if (field != null)
                                group.remove (field.validation_label);
                        }
                        if (expander != null && widget != expander) {
                            expander.add_row (widget);
                            if (field != null)
                                expander.add_row (field.validation_label);
                        }
                    }
                }
                Adw.PreferencesRow row = inline_row != null ? (Adw.PreferencesRow) inline_row : expander;
                current_rows.set (option_id, row);
                remove_buttons.set (option_id, remove);
                current_group.add (row);
            }
        }

        void open_picker () {
            if (picker != null)
                return;

            var search = new Gtk.SearchEntry () {
                placeholder_text = _("Search launch options"), search_delay = 0
            };
            Utils.TextInputMetadataPolicy.apply (search, Utils.TextInputFieldKind.SEARCH);
            var sections = new Gtk.Box (Gtk.Orientation.VERTICAL, 18) {
                margin_start = 12, margin_end = 12, margin_top = 12, margin_bottom = 12
            };
            var scroller = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER, vexpand = true, child = sections
            };
            var body = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            var search_bar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                margin_start = 12, margin_end = 12, margin_top = 6
            };
            search_bar.append (search);
            body.append (search_bar);
            body.append (scroller);
            var toolbar = new Adw.ToolbarView () { content = body };
            toolbar.add_top_bar (new Adw.HeaderBar ());
            var dialog = new Adw.Dialog () {
                title = _("Add launch option"), content_width = 520, content_height = 550,
                child = toolbar
            };
            picker = dialog;
            dialog.closed.connect (picker_closed);
            var actions = new SimpleActionGroup ();
            var choose_action = new SimpleAction ("choose", VariantType.STRING);
            choose_action.activate.connect (choose_requested);
            actions.add_action (choose_action);
            dialog.insert_action_group ("launch-options", actions);
            var common = new Adw.PreferencesGroup () { title = Markup.escape_text (_("Common options")) };
            sections.append (common);
            var groups = new Gee.HashMap<int, Adw.PreferencesGroup> ();
            foreach (var category in canonical_categories) {
                var group = new Adw.PreferencesGroup () {
                    title = Markup.escape_text (LaunchOptionCatalog.category_title (category))
                };
                groups.set ((int) category, group);
                sections.append (group);
            }

            var choices = new Gee.HashMap<LaunchOptionPresentation, Adw.ActionRow> ();
            foreach (var presentation in presentations.get_ordered ()) {
                var metadata = presentation.metadata;
                var eligibility = capability_resolver.evaluate (metadata, capability_context);
                if (!eligibility.show_when_inactive || current_rows.get (metadata.id).visible
                    || !backend_matches (metadata))
                    continue;
                var subtitle = presentations.describe (metadata, eligibility);
                var choice = new Adw.ActionRow () {
                    title = metadata.title, subtitle = subtitle, tooltip_text = subtitle,
                    use_markup = false, subtitle_lines = 2, activatable = true
                };
                choice.add_suffix (new Gtk.Image.from_icon_name ("list-add-symbolic"));
                choice.action_name = "launch-options.choose";
                choice.action_target = new Variant.string (metadata.id);
                choices.set (presentation, choice);
                var group = metadata.quick_setting ? common : groups.get ((int) metadata.category);
                group.add (choice);
            }
            var no_results = new Gtk.Label (_("No matching launch options.")) { css_classes = { "dim-label" } };
            sections.append (no_results);
            weak Gtk.SearchEntry search_entry = search;
            search.search_changed.connect (() => filter_picker (search_entry.text, choices, common, groups, no_results));
            filter_picker ("", choices, common, groups, no_results);
            Window.present_dialog_for_controller (dialog, this);
            search.grab_focus ();
        }

        void filter_picker (string query, Gee.Map<LaunchOptionPresentation, Adw.ActionRow> choices,
            Adw.PreferencesGroup common, Gee.Map<int, Adw.PreferencesGroup> groups, Gtk.Label no_results) {
            common.visible = false;
            foreach (var group in groups.values)
                group.visible = false;
            no_results.visible = true;
            foreach (var entry in choices.entries) {
                var metadata = entry.key.metadata;
                var visible = metadata.matches_search (query);
                entry.value.visible = visible;
                if (visible) {
                    var group = metadata.quick_setting ? common : groups.get ((int) metadata.category);
                    group.visible = true;
                    no_results.visible = false;
                }
            }
        }

        void choose_requested (Variant? target) {
            var id = target.get_string ();
            var dialog = picker;
            if (dialog == null)
                return;
            draft_options.add (id);
            var row = current_rows.get (id);
            var control = presentations.lookup (id);
            refresh_current_options ();
            var expander = row as Adw.ExpanderRow;
            if (expander != null && (control == null || !control.widgets.contains (expander)))
                expander.expanded = true;
            var tile = control?.option as LaunchOptionTile;
            var spin = control?.option as LaunchOptionSpinTile;
            if (tile != null)
                tile.toggle.active = true;
            if (spin != null)
                spin.use_default_value ();
            picker_selection = spin != null ? (Gtk.Widget) spin.value_entry : row;
            dialog.close ();
        }

        void close_picker () {
            picker?.close ();
        }

        void picker_closed () {
            picker = null;
            var selection = picker_selection;
            picker_selection = null;
            if (selection != null) {
                // Let the dialog restore its opener before focusing the edited row.
                Idle.add (() => {
                    if (selection.get_mapped ())
                        selection.grab_focus ();
                    return Source.REMOVE;
                });
            }
        }

        bool backend_matches (LaunchOptionMetadata metadata) {
            var required = metadata.semantics?.wrapper_id ?? "";
            return required == "" || !("launch-backend" in metadata.semantics.dependencies)
                || required == wrapper_group.get_selected_backend_id ();
        }

        public void clear () {
            refreshing_controls = true;
            launch_option_handlers.clear_all ();
            wrapper_group.reset_controls ();
            gpu_vendor_group.normalize_dependencies ();
            refreshing_controls = false;
            removed_options.clear ();
            draft_options.clear ();
            edit_state.mark_explicit_clear (collect_sources ());
            refresh_state (true);
        }

        public LaunchCommandEditorProjectionState projection_state { get { return projection.state; } }
        public string managed_candidate { get { return projection.managed_candidate; } }
        public bool has_managed_candidate { get { return projection.has_managed_candidate; } }
        public Gee.List<string> projection_diagnostics { get { return projection.adapter_diagnostics; } }
        public Gee.List<LaunchCommandCompositionDiagnostic> projection_composition_diagnostics {
            get { return projection.composition_diagnostics; }
        }
        public bool is_dirty { get { return edit_state.is_dirty || removed_options.size > 0; } }
        public bool writing_allowed { get; private set; }
        public bool has_changes_to_write { get; private set; }
        public bool can_clear { get; private set; }
        public Gee.List<string> write_diagnostics { get { return prepare_write ().writer_diagnostics; } }

        public LaunchCommandWriteResult prepare_write () {
            return prepare_write_for_source (loaded_source);
        }

        public LaunchCommandWriteResult prepare_write_for_source (string source) {
            var diagnostics = new Gee.ArrayList<string> ();
            diagnostics.add_all (adapter_diagnostics);
            bool has_draft_options;
            var selections = collect_managed_selections (diagnostics, out has_draft_options);
            return write_source (source, selections.to_array (), diagnostics.to_array ());
        }

        LaunchCommandWriteResult write_source (
            string source, LaunchCommandSelection[] selections, string[] diagnostics
        ) {
            var modified = edit_state.get_modified_option_ids ();
            if (removed_options.size > 0) {
                // An option shown for the batch may be absent from this game's source.
                var configured = get_configured_values (source);
                var changed = new Gee.ArrayList<string> ();
                foreach (var id in modified) {
                    if (!removed_options.contains (id) || configured.has_key (id))
                        changed.add (id);
                }
                foreach (var id in removed_options) {
                    if (configured.has_key (id) && !changed.contains (id))
                        changed.add (id);
                }
                modified = changed.to_array ();
            }
            return writer.prepare_source (source, selections, modified,
                diagnostics, capability_context, edit_state.explicit_clear, false,
                source != loaded_source && !removed_options.contains ("custom-game-arguments"));
        }

        public void set_capability_context (LaunchCommandCapabilityContext? context) {
            capability_context = context;
            refreshing_controls = true;
            game_arguments_group.set_capability_context (context);
            refreshing_controls = false;
            refresh_state ();
        }

        public void set_text (string launch_options) {
            refreshing_controls = true;
            loaded_source = launch_options;
            draft_options.clear ();
            removed_options.clear ();
            preview_field.collapse ();
            foreach (var row in current_rows.values)
                (row as Adw.ExpanderRow)?.set_expanded (false);
            preview_source_labels.clear ();
            preview_sources.clear ();
            preview_source_labels.add ("");
            preview_sources.add (loaded_source);
            gpu_vendor_group.reset_controls ();
            var parsed = new LaunchCommandParser (catalog).parse (loaded_source);
            launch_option_handlers.load_from_parse_result (parsed, catalog);
            advanced_options_group.load_custom_arguments (parsed);
            game_arguments_group.load_from_parse_result (parsed);
            wrapper_group.normalize_selection ();
            wrapper_group.load_raw_arguments (parsed);
            gpu_vendor_group.normalize_dependencies ();
            edit_state.record_baseline (collect_sources ());
            refresh_configured_options ();
            refreshing_controls = false;
            refresh_state ();
        }

        internal void reset () {
            var labels = preview_source_labels.to_array ();
            var sources = preview_sources.to_array ();
            var preview_open = preview_field.button.active;
            set_text (loaded_source);
            set_preview_sources (labels, sources);
            preview_field.button.active = preview_open;
        }

        /* Batch editing has one control state but one preserved source command
         * per game. Preview every source through the same writer used by Apply. */
        public void set_preview_sources (string[] labels, string[] sources) {
            assert (labels.length == sources.length);
            preview_source_labels.clear ();
            preview_sources.clear ();
            foreach (var label in labels)
                preview_source_labels.add (label);
            foreach (var source in sources)
                preview_sources.add (source);
            if (preview_sources.size == 0) {
                preview_source_labels.add ("");
                preview_sources.add (loaded_source);
            }
            refresh_configured_options ();
            refresh_state ();
        }

        void standard_control_changed () {
            if (refreshing_controls)
                return;

            var sources = collect_sources ();
            foreach (var source in sources) {
                if (removed_options.contains (source.option_id)
                    && (source.get_selection () != null || source.get_diagnostic () != null))
                    removed_options.remove (source.option_id);
            }
            edit_state.update (sources);
            refresh_state (true);
        }

        void refresh_state (bool notify_change = false) {
            refresh_projection ();
            refresh_preview ();
            refresh_current_options ();
            if (notify_change)
                content_changed ();
        }

        void refresh_projection () {
            var sources = collect_sources (true);
            projection.update (loaded_source, sources, adapter_diagnostics, capability_context);
        }

        Gee.ArrayList<ILaunchCommandSelectionSource> collect_sources (bool exclude_unavailable = false) {
            var sources = new Gee.ArrayList<ILaunchCommandSelectionSource> ();
            foreach (var source in presentations.get_selection_sources ()) {
                if (source.option_id == "launch-backend") {
                    var selected = wrapper_group.get_selected_backend_id ();
                    sources.add (new LaunchCommandStaticSelectionSource (
                        "launch-backend", selected != ""
                            ? new LaunchCommandSelection ("launch-backend", {}, selected) : null
                    ));
                    continue;
                }
                if (exclude_unavailable) {
                    var selection = source.get_selection ();
                    var metadata = catalog.lookup (source.option_id);
                    if (selection != null && metadata != null
                        && !capability_resolver.evaluate_selection (metadata, selection,
                            capability_context, true).may_activate)
                        continue;
                }
                sources.add (source);
            }
            return sources;
        }

        Gee.ArrayList<LaunchCommandSelection> collect_managed_selections (
            Gee.Collection<string> diagnostics, out bool has_draft_options, Gee.Map<string, string>? fields = null
        ) {
            has_draft_options = false;
            var selections = new Gee.ArrayList<LaunchCommandSelection> ();
            foreach (var source in collect_sources ()) {
                var selection = source.get_selection ();
                var source_diagnostic = source.get_diagnostic ();
                has_draft_options |= selection != null || source_diagnostic != null;
                if (source_diagnostic != null && edit_state.is_option_modified (source.option_id)) {
                    diagnostics.add (source_diagnostic);
                    fields?.set (source.option_id, source_diagnostic);
                }
                if (selection == null)
                    continue;
                var metadata = catalog.lookup (selection.option_id);
                if (metadata == null || metadata.semantics == null) {
                    diagnostics.add ("Selection source '%s' returned an unknown option.".printf (selection.option_id));
                    continue;
                }
                var semantics = metadata.semantics;
                var eligibility = capability_resolver.evaluate_selection (metadata, selection,
                    capability_context, true);
                if (!eligibility.may_activate) {
                    if (edit_state.is_option_modified (selection.option_id)) {
                        diagnostics.add (eligibility.reason);
                        fields?.set (selection.option_id, eligibility.reason);
                    }
                    continue;
                }
                if (semantics.managed_emission
                    && semantics.kind != LaunchOptionSemanticKind.COMMAND_BOUNDARY
                    && semantics.kind != LaunchOptionSemanticKind.OPAQUE_CONTEXT_DEPENDENT) {
                    selections.add (selection);
                } else if (edit_state.is_option_modified (selection.option_id)) {
                    var diagnostic = _("This launch option cannot be enabled here.");
                    diagnostics.add (diagnostic);
                    fields?.set (selection.option_id, diagnostic);
                }
            }
            return selections;
        }

        void remove_requested (Variant? target) {
            var id = target.get_string ();
            var presentation = presentations.lookup (id);
            refreshing_controls = true;
            if (id == "launch-backend")
                wrapper_group.reset_controls ();
            else if (presentation?.option != null)
                presentation.option.clear ();
            else if (presentation != null) {
                foreach (var widget in presentation.widgets) {
                    var field = widget as LaunchOptionEntryField;
                    if (field != null)
                        field.text = "";
                }
            }
            draft_options.remove (id);
            (current_rows.get (id) as Adw.ExpanderRow)?.set_expanded (false);
            edit_state.update (collect_sources ());
            if (configured_values.has_key (id))
                removed_options.add (id);
            refreshing_controls = false;
            refresh_state (true);
            add_button.grab_focus ();
        }

        void refresh_current_options () {
            var has_options = false;
            foreach (var metadata in catalog.get_ordered ()) {
                var id = metadata.id;
                var row = current_rows.get (id);
                if (row == null)
                    continue;
                var control = presentations.lookup (id);
                var modified = edit_state.is_option_modified (id);
                var configured = !edit_state.explicit_clear && !removed_options.contains (id)
                    && !modified && configured_values.has_key (id);
                var active = id == "launch-backend" && wrapper_group.has_active_non_default_backend ();
                if (control != null) {
                    active |= control.is_active ();
                    foreach (var source in control.selection_sources)
                        active |= source.get_selection () != null || source.get_diagnostic () != null;
                }
                var backend_available = backend_matches (metadata);
                var eligibility = capability_resolver.evaluate (metadata, capability_context, configured || active);
                var editable = control != null && eligibility.may_modify && backend_available;
                row.visible = configured || active || (draft_options.contains (id) && editable);
                remove_buttons.get (id).visible = row.visible;
                var diagnostic = field_diagnostics.get (id);
                var backend_reason = backend_available || eligibility.reason != "" ? ""
                    : _("Select %s as the launch backend to edit this option.").printf (metadata.subsection);
                var detail = diagnostic ?? presentations.describe (metadata, eligibility, backend_reason);
                if (control != null) {
                    control.eligibility = eligibility;
                    control.apply_metadata (detail);
                }
                var tile = row as LaunchOptionTile;
                var value = configured ? configured_values.get (id) : "";
                if (tile != null && editable && tile.tokens.length == 1 && value == tile.tokens[0])
                    value = "";
                var subtitle = value == "" ? detail : _("%s — %s").printf (value, detail);
                var action_row = row as Adw.ActionRow;
                if (action_row != null) {
                    action_row.subtitle = subtitle;
                    var spin = action_row as LaunchOptionSpinTile;
                    if (spin != null)
                        spin.value_entry.sensitive = editable;
                    var combo = action_row as LaunchOptionEnvCombo;
                    if (combo != null)
                        combo.set_selection_editable (editable);
                } else {
                    var expander = (Adw.ExpanderRow) row;
                    if (expander.enable_expansion != editable) {
                        // Libadwaita expands the row when enabling its chevron.
                        expander.freeze_notify ();
                        expander.enable_expansion = editable;
                        expander.expanded = false;
                        expander.thaw_notify ();
                    }
                    if (!row.visible || !editable)
                        expander.expanded = false;
                    expander.subtitle = subtitle;
                }
                row.tooltip_text = subtitle;
                has_options |= row.visible;
            }
            empty_label.visible = !has_options;
            if (has_options)
                current_group.remove_css_class ("launch-options-empty");
            else
                current_group.add_css_class ("launch-options-empty");
        }

        void refresh_configured_options () {
            configured_values.clear ();
            var counts = new Gee.HashMap<string, int> ();
            foreach (var source in preview_sources) {
                var values = get_configured_values (source);
                foreach (var entry in values.entries) {
                    var previous = configured_values.get (entry.key);
                    configured_values.set (entry.key, previous == null || previous == entry.value
                        ? entry.value : _("Varies by game"));
                    counts.set (entry.key, counts.get (entry.key) + 1);
                }
            }
            foreach (var id in counts.keys) {
                if (counts.get (id) != preview_sources.size)
                    configured_values.set (id, _("Varies by game"));
            }
        }

        Gee.HashMap<string, string> get_configured_values (string source) {
            var parsed = new LaunchCommandParser (catalog).parse (source);
            var values = new Gee.HashMap<string, string> ();
            foreach (var occurrence in parsed.occurrences) {
                var words = new Gee.ArrayList<string> ();
                foreach (var token in occurrence.raw_tokens)
                    words.add (token.raw);
                var prefix = values.get (occurrence.option_id);
                var raw = string.joinv (" ", words.to_array ());
                values.set (occurrence.option_id, prefix == null ? raw : prefix + " " + raw);
            }
            if (parsed.custom_wrapper_index >= 0)
                values.set (LaunchCustomWrapperInput.OPTION_ID, parsed.tokens[parsed.custom_wrapper_index].raw);
            var raw_args = new Gee.ArrayList<string> ();
            foreach (var token in parsed.get_custom_game_arguments ())
                raw_args.add (token.raw);
            if (raw_args.size > 0)
                values.set ("custom-game-arguments", string.joinv (" ", raw_args.to_array ()));
            foreach (var wrapper in parsed.wrappers) {
                if (wrapper.unknown_argument_indexes.size == 0)
                    continue;
                var backend = catalog.lookup ("launch-backend").semantics;
                if (!(wrapper.wrapper_id in backend.selectable_wrapper_ids))
                    continue;
                var words = new Gee.ArrayList<string> ();
                foreach (var index in wrapper.unknown_argument_indexes)
                    words.add (parsed.tokens[index].raw);
                values.set (wrapper.wrapper_id + "-arguments", string.joinv (" ", words.to_array ()));
            }
            return values;
        }

        bool collect_missing_dependency (string id, Gee.Set<string> active, Gee.Set<string> visited,
                                         Gee.List<LaunchOptionPresentation> requirements) {
            if (active.contains (id) || !visited.add (id))
                return true;
            var control = presentations.lookup (id);
            if (control == null || !current_rows.has_key (id) || !backend_matches (control.metadata)
                || !capability_resolver.evaluate (control.metadata, capability_context).may_modify)
                return false;
            foreach (var dependency in control.metadata.semantics.dependencies) {
                if (!collect_missing_dependency (dependency, active, visited, requirements))
                    return false;
            }
            requirements.add (control);
            return true;
        }

        uint plan_missing_dependencies (Gee.Collection<LaunchCommandWriteResult> results,
                                        LaunchCommandSelection[] selections) {
            var active = new Gee.HashSet<string> ();
            foreach (var selection in selections) {
                var values = selection.get_values ();
                var semantics = catalog.lookup (selection.option_id).semantics;
                if (values.length != 1 || !semantics.is_feature_disabled (values[0]))
                    active.add (selection.option_id);
            }

            var affected = new Gee.HashSet<string> ();
            var checked_requirements = new Gee.HashSet<string> ();
            var planned = new Gee.HashSet<string> ();
            var requirements = new Gee.ArrayList<LaunchOptionPresentation> ();
            foreach (var result in results) {
                if (result.writing_allowed)
                    continue;
                foreach (var diagnostic in result.composition_diagnostics) {
                    if (diagnostic.code != LaunchCommandCompositionDiagnosticCode.MISSING_DEPENDENCY)
                        continue;
                    affected.add (diagnostic.option_id);
                    if (!checked_requirements.add (diagnostic.related_option_id))
                        continue;
                    var branch = new Gee.ArrayList<LaunchOptionPresentation> ();
                    if (!collect_missing_dependency (diagnostic.related_option_id, active,
                        new Gee.HashSet<string> (), branch))
                        continue;
                    foreach (var control in branch) {
                        if (planned.add (control.metadata.id))
                            requirements.add (control);
                    }
                }
            }

            foreach (var control in requirements) {
                var ready = true;
                foreach (var dependency in control.metadata.semantics.dependencies)
                    ready &= active.contains (dependency);
                if (!ready)
                    continue;
                if (control.option is LaunchOptionTile) {
                    automatic_dependencies.add (control);
                    active.add (control.metadata.id);
                } else if (dependency_to_configure == null) {
                    dependency_to_configure = control;
                }
            }

            if (automatic_dependencies.size > 0)
                dependency_action_label = _("Add required options");
            else if (dependency_to_configure != null)
                dependency_action_label = _("Configure %s").printf (dependency_to_configure.metadata.title);
            return (uint) affected.size;
        }

        internal void resolve_missing_dependency () {
            if (automatic_dependencies.size > 0) {
                var focus = current_rows.get (automatic_dependencies[0].metadata.id);
                refreshing_controls = true;
                foreach (var control in automatic_dependencies)
                    ((LaunchOptionTile) control.option).toggle.active = true;
                refreshing_controls = false;
                standard_control_changed ();
                if (!focus.grab_focus ())
                    add_button.grab_focus ();
            } else if (dependency_to_configure != null) {
                var id = dependency_to_configure.metadata.id;
                draft_options.add (id);
                refresh_current_options ();
                var row = current_rows.get (id);
                (row as Adw.ExpanderRow)?.set_expanded (true);
                row.grab_focus ();
            }
        }

        void refresh_preview () {
            field_diagnostics.clear ();
            automatic_dependencies.clear ();
            dependency_to_configure = null;
            dependency_action_label = "";
            var diagnostics = new Gee.ArrayList<string> ();
            diagnostics.add_all (adapter_diagnostics);
            bool has_draft_options;
            var selections = collect_managed_selections (diagnostics, out has_draft_options, field_diagnostics).to_array ();
            var issues = diagnostics.to_array ();
            var results = new Gee.ArrayList<LaunchCommandWriteResult> ();
            var results_by_source = new Gee.HashMap<string, LaunchCommandWriteResult> ();
            LaunchCommandWriteResult? blocked_result = null;
            string blocked_label = "";
            can_clear = has_draft_options;
            has_changes_to_write = false;
            foreach (var source in preview_sources) {
                var candidate = results_by_source.get (source);
                if (candidate == null) {
                    candidate = write_source (source, selections, issues);
                    results_by_source.set (source, candidate);
                }
                results.add (candidate);
                can_clear |= (candidate.writing_allowed ? candidate.launch_line : source) != "";
                has_changes_to_write |= candidate.requires_persistence;
                if (!candidate.writing_allowed && blocked_result == null) {
                    blocked_result = candidate;
                    blocked_label = preview_source_labels[results.size - 1];
                }
            }
            writing_allowed = blocked_result == null;

            var result = blocked_result ?? results[0];
            var preview = result.writing_allowed ? result.launch_line : result.parsed.original_input;
            var reason = "";
            LaunchCommandCompositionDiagnostic? blocker = null;
            foreach (var diagnostic in result.composition_diagnostics) {
                if (!field_diagnostics.has_key (diagnostic.option_id))
                    field_diagnostics.set (diagnostic.option_id, diagnostic.message);
                if (reason == "") {
                    reason = diagnostic.message;
                    blocker = diagnostic;
                }
            }
            uint affected = 0;
            if (!writing_allowed && blocker?.code == LaunchCommandCompositionDiagnosticCode.MISSING_DEPENDENCY) {
                affected = plan_missing_dependencies (results, selections);
                if (affected > 1)
                    reason = ngettext ("%u launch option has unmet requirements.",
                        "%u launch options have unmet requirements.", affected).printf (affected);
            }
            if (result.status == LaunchCommandWriteStatus.BLOCKED_UNSAFE_SOURCE)
                reason = _("Use Clear Launch Options to replace a command that cannot be merged safely.");
            else if (reason == "" && result.writer_diagnostics.size > 0)
                reason = result.writer_diagnostics[0];
            if (!result.writing_allowed && affected <= 1 && preview_sources.size > 1 && blocked_label != "")
                reason = _("%s — %s").printf (blocked_label, reason);
            if (!result.writing_allowed && reason == "")
                reason = _("Review the selected launch options before applying changes.");

            var same_output = true;
            var commands = new string[results.size];
            for (var index = 0; index < results.size; index++) {
                commands[index] = results[index].writing_allowed
                    ? results[index].launch_line : results[index].parsed.original_input;
                if (index > 0 && commands[index] != commands[0])
                    same_output = false;
            }
            var dark = Adw.StyleManager.get_default ().dark;
            if (!same_output) {
                preview_field.preview_label.set_markup (
                    LaunchOptionsList.build_labeled_command_preview_markup (
                        preview_source_labels.to_array (), commands, dark));
                preview_field.set_empty (false);
            } else {
                preview_field.preview_label.set_markup (
                    LaunchOptionsList.build_command_preview_markup (preview, dark));
                preview_field.set_empty (preview == "");
            }
            preview_field.blocking_reason = writing_allowed ? "" : reason;
        }
    }
}
