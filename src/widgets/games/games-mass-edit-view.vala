namespace ProtonPlus.Widgets.Games {
    public class MassEditView : Gtk.Box {
        public signal void back_requested ();

        Gtk.Button clear_button;
        Gtk.Button reset_button;
        Gtk.Button apply_button;
        LaunchOptionsBlocker apply_blocker;
        Gtk.Label batch_scope;
        Gtk.Box launch_action_buttons;
        Gtk.Box header_actions;
        Gtk.Box launch_action_area;
        Gtk.MenuButton selection_button;
        Gtk.Label game_title;
        public Header.Presentation header_presentation { get; private set; }
        Adw.Clamp content_clamp { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        CompatibilityToolRow compatibility_tool_row { get; set; }
        Adw.PreferencesGroup compatibility_tool_group { get; set; }
        LutrisOptionsView lutris_options;
        Adw.ActionRow lutris_repair_row;
        Gtk.Button lutris_repair_button;
        Models.Games.Lutris? lutris_game;
        Adw.SwitchRow compatibility_tool_apply_row { get; set; }
        LaunchOptionsEditor.Box launch_options_editor { get; set; }
        Gtk.Box content_box { get; set; }
        GameListItem[] items;
        string? compatibility_tool_diagnostic;
        bool runner_only;
        bool single_steam_game;
        uint initial_tool_selection;
        uint load_generation;
        Cancellable? apply_request;
        LaunchOptions.LaunchOptionCapabilityResolver capability_resolver;
        uint capability_generation;
        Gee.HashMap<string, Models.CompatibilityTool> compatibility_tools_by_id;
        Utils.GpuVendor gpu_vendor = Utils.GpuVendor.UNKNOWN;
        ulong header_back_handler = 0;

        public string get_selection_text () {
            return ngettext ("%u game selected", "%u games selected", items.length).printf (items.length);
        }

        public MassEditView (Gtk.MenuButton selection_button) {
            set_orientation (Gtk.Orientation.VERTICAL);

            this.selection_button = selection_button;

            clear_button = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic");
            clear_button.add_css_class ("destructive-action");
            clear_button.set_tooltip_text (_("Clear Launch Options"));
            clear_button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Clear Launch Options"),
                -1
            );
            clear_button.clicked.connect (clear_button_clicked);

            reset_button = new Gtk.Button.from_icon_name ("edit-undo-symbolic") { sensitive = false };
            reset_button.tooltip_text = _("Reset Changes");
            reset_button.update_property (Gtk.AccessibleProperty.LABEL, reset_button.tooltip_text, -1);
            reset_button.clicked.connect (reset_changes);

            apply_button = new Gtk.Button.with_label (_("Apply Changes"));
            apply_button.add_css_class ("suggested-action");
            apply_button.clicked.connect (() => apply_button_clicked.begin ());
            unmap.connect (() => apply_request?.cancel ());

            compatibility_tool_group = new Adw.PreferencesGroup ();

            compatibility_tool_apply_row = new Adw.SwitchRow () {
                title = _("Change compatibility tool")
            };
            compatibility_tool_group.add (compatibility_tool_apply_row);

            compatibility_tool_apply_row.notify["active"].connect (() => {
                if (compatibility_tool_row != null)
                    compatibility_tool_row.set_visible (compatibility_tool_apply_row.active);
                refresh_capability_context ();
            });

            launch_options_editor = new LaunchOptionsEditor.Box ();
            capability_resolver = new LaunchOptions.LaunchOptionCapabilityResolver ();
            compatibility_tools_by_id = new Gee.HashMap<string, Models.CompatibilityTool> ();
            launch_options_editor.content_changed.connect (refresh);

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            content_box.append (compatibility_tool_group);
            lutris_repair_button = new Gtk.Button.with_label (_("Install Exact Version")) { valign = Gtk.Align.CENTER };
            lutris_repair_button.clicked.connect (() => repair_lutris_runner.begin ());
            lutris_repair_row = new Adw.ActionRow () { visible = false, use_markup = false };
            lutris_repair_row.add_suffix (lutris_repair_button);
            lutris_repair_row.activatable_widget = lutris_repair_button;
            lutris_options = new LutrisOptionsView (lutris_repair_row) { visible = false };
            content_box.append (lutris_options);
            lutris_options.changed.connect (refresh);
            batch_scope = new Gtk.Label (null) {
                xalign = 0, wrap = true, css_classes = { "dim-label" }
            };
            content_box.append (batch_scope);
            content_box.append (launch_options_editor);

            content_clamp = new Adw.Clamp ();
            content_clamp.set_maximum_size (975);
            content_clamp.set_margin_top (12);
            content_clamp.set_margin_bottom (12);
            content_clamp.set_margin_start (12);
            content_clamp.set_margin_end (12);
            content_clamp.set_child (content_box);

            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_hexpand (true);
            scrolled_window.set_vexpand (true);
            scrolled_window.set_child (content_clamp);

            var preview = launch_options_editor.preview_field;
            apply_blocker = new LaunchOptionsBlocker ();
            apply_blocker.action.clicked.connect (launch_options_editor.resolve_missing_dependency);
            launch_action_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                hexpand = true, halign = Gtk.Align.END
            };
            launch_action_buttons.append (clear_button);
            launch_action_buttons.append (reset_button);
            launch_action_buttons.append (apply_button);
            var footer_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            footer_buttons.append (preview.button);
            footer_buttons.append (launch_action_buttons);
            var actions = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                margin_top = 8, margin_bottom = 8
            };
            actions.append (apply_blocker);
            actions.append (preview);
            actions.append (footer_buttons);
            game_title = new Gtk.Label (null) {
                css_classes = { "title" },
                ellipsize = Pango.EllipsizeMode.END,
                visible = false
            };
            var header_title = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            header_title.append (game_title);
            header_title.append (selection_button);
            header_presentation = new Header.Presentation (header_title);
            header_back_handler = header_presentation.back_requested.connect (() => {
                back_requested ();
            });
            header_actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { visible = false };
            header_presentation.add_end_action (header_actions);

            append (scrolled_window);
            launch_action_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            launch_action_area.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            launch_action_area.append (new Adw.Clamp () {
                maximum_size = 975, margin_start = 12, margin_end = 12, child = actions
            });
            append (launch_action_area);
        }

        public override void dispose () {
            if (header_back_handler != 0) {
                header_presentation.disconnect (header_back_handler);
                header_back_handler = 0;
            }
            base.dispose ();
        }

        public Gtk.Widget get_controller_initial_focus () {
            if (selection_button.visible)
                return selection_button;
            if (launch_options_editor.visible)
                return launch_options_editor.get_initial_focus ();
            if (compatibility_tool_row.visible)
                return compatibility_tool_row;
            return compatibility_tool_apply_row;
        }

        public void load (GameListItem[] items, ListStore model, Gtk.PropertyExpression expression,
            bool runner_only, bool mass_edit) {
            this.items = items;
            this.runner_only = runner_only;
            var single_game = !mass_edit && items.length == 1 ? items[0].game : null;
            single_steam_game = single_game is Models.Games.Steam;
            game_title.label = single_game?.name ?? "";
            game_title.tooltip_text = single_game?.name;
            game_title.visible = single_game != null;
            selection_button.visible = mass_edit;
            var generation = ++load_generation;
            compatibility_tool_diagnostic = null;

            var has_steam_launch_options = false;
            var all_native = items.length > 0;
            var all_steam_linux_runtime_compatible = items.length > 0;
            foreach (var item in items) {
                if (item.game.launcher is Models.Launchers.Steam)
                    has_steam_launch_options = true;

                if (!item.game.is_native)
                    all_native = false;

                if (!Models.Launchers.Steam.is_game_steam_linux_runtime_compatible (item.game))
                    all_steam_linux_runtime_compatible = false;
            }

            if (compatibility_tool_row != null && lutris_game == null)
                compatibility_tool_group.remove (compatibility_tool_row);
            lutris_game = single_game as Models.Games.Lutris;

            var compatibility_tools = new Gee.ArrayList<Models.CompatibilityTool> ();
            compatibility_tools_by_id.clear ();
            var n_items = model.get_n_items ();
            for (uint i = 0; i < n_items; i++) {
                var runner = model.get_item (i) as Models.CompatibilityTool;
                if (runner == null)
                    continue;
                var is_current = items.length == 1 && runner.internal_title == items[0].game.compatibility_tool;
                if (!runner.is_available && !is_current && !(runner_only && runner.availability_diagnostic != null))
                    continue;
                if (!runner_only && Models.Launchers.Steam.is_steam_linux_runtime (runner.display_title, runner.internal_title)
                    && !all_steam_linux_runtime_compatible && !(single_steam_game && is_current))
                    continue;
                if (all_native && runner.internal_title == "Default") {
                    compatibility_tools.add (new Models.CompatibilityTool (_("Native"), runner.internal_title, "",
                        Models.CompatibilityToolRuntimeKind.NATIVE));
                } else {
                    compatibility_tools.add (runner);
                }
            }
            compatibility_tools.sort ((a, b) => {
                var a_is_default = a.internal_title == "Default";
                var b_is_default = b.internal_title == "Default";
                if (a_is_default != b_is_default)
                    return a_is_default ? -1 : 1;

                return strcmp (
                    b.display_title.collate_key_for_filename (),
                    a.display_title.collate_key_for_filename ()
                );
            });

            var filtered_model = new ListStore (typeof (Models.CompatibilityTool));
            foreach (var compatibility_tool in compatibility_tools) {
                filtered_model.append (compatibility_tool);
                compatibility_tools_by_id.set (compatibility_tool.internal_title, compatibility_tool);
            }
            if (single_steam_game && !compatibility_tools_by_id.has_key (items[0].game.compatibility_tool)) {
                var current_id = items[0].game.compatibility_tool;
                var steam = (Models.Launchers.Steam) items[0].game.launcher;
                var current = steam.find_compatibility_tool (current_id) ??
                    new Models.CompatibilityTool (_("%s (Unavailable)").printf (current_id)) {
                        internal_title = current_id, is_available = false, is_assignable = false
                    };
                filtered_model.append (current);
                compatibility_tools_by_id.set (current_id, current);
            }

            compatibility_tool_row = new CompatibilityToolRow (filtered_model, expression);
            if (lutris_game != null)
                compatibility_tool_row.use_markup = false;
            else
                compatibility_tool_group.add (compatibility_tool_row);
            lutris_options.set_version_row (lutris_game != null ? compatibility_tool_row : null);

            if (items.length == 1) {
                var game = items[0].game;

                var filtered_n_items = filtered_model.get_n_items ();
                for (uint i = 0; i < filtered_n_items; i++) {
                    var runner = filtered_model.get_item (i) as Models.CompatibilityTool;
                    if (runner != null && runner.internal_title == game.compatibility_tool) {
                        compatibility_tool_row.selected = i;
                        break;
                    }
                }
            }
            initial_tool_selection = compatibility_tool_row.selected;
            lutris_options.load (lutris_game);

            string[] preview_labels = {};
            string[] preview_sources = {};
            var common_source = "";
            var sources_match = true;
            foreach (var item in items) {
                var steam_game = item.game as Models.Games.Steam;
                if (steam_game == null)
                    continue;
                var source = steam_game.launch_options ?? "";
                preview_labels += steam_game.name;
                preview_sources += source;
                if (preview_sources.length == 1)
                    common_source = source;
                else if (source != common_source)
                    sources_match = false;
            }
            launch_options_editor.set_text (sources_match ? common_source : "");
            launch_options_editor.set_preview_sources (preview_labels, preview_sources);

            compatibility_tool_group.title = has_steam_launch_options ? Markup.escape_text (_("Compatibility tool")) : "";
            compatibility_tool_group.visible = lutris_game == null;
            launch_options_editor.visible = has_steam_launch_options;
            launch_options_editor.preview_field.visible = has_steam_launch_options;
            launch_options_editor.preview_field.button.visible = has_steam_launch_options;
            var show_footer = has_steam_launch_options || lutris_game != null;
            launch_action_area.visible = show_footer;
            header_actions.visible = !show_footer;
            var clear_label = lutris_game != null ? _("Clear Environment Variables") : _("Clear Launch Options");
            clear_button.tooltip_text = clear_label;
            clear_button.update_property (Gtk.AccessibleProperty.LABEL, clear_label, -1);
            var button_parent = (Gtk.Box) apply_button.get_parent ();
            var button_destination = show_footer ? launch_action_buttons : header_actions;
            if (button_parent != button_destination) {
                button_parent.remove (apply_button);
                button_destination.append (apply_button);
            }
            batch_scope.visible = preview_sources.length > 1;
            batch_scope.label = ngettext ("Launch option changes apply to %d game.",
                "Launch option changes apply to %d games.", preview_sources.length).printf (preview_sources.length);

            compatibility_tool_apply_row.set_visible (!runner_only && !single_steam_game);
            compatibility_tool_apply_row.active = false;
            compatibility_tool_row.visible = runner_only || single_steam_game;
            if (single_steam_game || lutris_game != null)
                compatibility_tool_row.title = _("Version");
            else if (runner_only)
                compatibility_tool_row.title = _("Wine or Proton version");

            compatibility_tool_row.notify["selected-item"].connect (() => {
                compatibility_tool_diagnostic = null;
                refresh_capability_context ();
            });
            if (has_steam_launch_options) {
                Utils.System.detect_gpu_vendor.begin ((obj, result) => {
                    var detected_vendor = Utils.System.detect_gpu_vendor.end (result);
                    if (generation != load_generation)
                        return;
                    gpu_vendor = detected_vendor;
                    refresh_capability_context ();
                });
            }
            refresh_capability_context ();
        }

        private async void repair_lutris_runner () {
            var game = lutris_game;
            var version = game?.repairable_runner;
            if (game == null || version == null || apply_request != null)
                return;
            var launcher = (Models.Launchers.Lutris) game.launcher;
            var item = items[0];
            var generation = load_generation;
            var request = new Cancellable ();
            apply_request = request;
            content_box.sensitive = false;
            lutris_repair_button.label = _("Installing…");
            refresh ();
            try {
                var job = yield launcher.prepare_runner_repair (version, request);
                request.set_error_if_cancelled ();
                yield game.validate_runner_repair (version);
                request.set_error_if_cancelled ();
                var cancellation_handler = request.cancelled.connect (() => job.canceled = true);
                var result = yield job.install ();
                request.disconnect (cancellation_handler);
                request.set_error_if_cancelled ();
                if (result != ReturnCode.RUNNER_INSTALLED && result != ReturnCode.RUNNER_ALREADY_INSTALLED)
                    throw new IOError.FAILED (job.error_message ?? get_return_code_message (result));
                var choices = yield game.load_game_tool_choices ();
                request.set_error_if_cancelled ();
                if (generation != load_generation || get_root () == null)
                    return;
                item.refresh_tool_title ();
                if (choices == null)
                    throw new IOError.FAILED (game.compatibility_edit_error ?? _("Could not verify the installed Lutris runner."));
                if (!game.runner_is_available (version)) {
                    var message = launcher.installation_type == Models.Launcher.InstallationTypes.FLATPAK
                        ? _("Lutris Flatpak could not use the installed runner. Check that its sandbox can access %s.")
                        : _("Lutris could not use the runner installed at %s. Check the configured runner directory and umu.");
                    throw new IOError.NOT_FOUND (message.printf (job.install_location));
                }
                if (!game.uses_runner (version))
                    throw new IOError.WRONG_ETAG (_("The runner was installed. The game's assignment changed while the installation was in progress."));
                back_requested ();
            } catch (Error error) {
                if (!request.is_cancelled () && generation == load_generation && get_root () != null)
                    Window.present_dialog_for_controller (new Main.ErrorDialog (
                        _("Could Not Repair the Lutris Runner"), version, error.message), (Gtk.Window) get_root ());
            } finally {
                apply_request = null;
                content_box.sensitive = true;
                lutris_repair_button.label = _("Install Exact Version");
                refresh ();
            }
        }

        private async bool confirm_lutris_conversion () {
            var dialog = new Adw.AlertDialog (_("Convert the Wine prefix?"),
                _("The next Lutris launch with Proton will convert this existing Wine prefix. The conversion cannot be undone."));
            dialog.add_response ("cancel", _("Cancel"));
            dialog.add_response ("convert", _("Apply Runner Change"));
            dialog.set_close_response ("cancel");
            dialog.set_default_response ("cancel");
            dialog.set_response_appearance ("convert", Adw.ResponseAppearance.DESTRUCTIVE);
            bool confirmed = false;
            SourceFunc resume = confirm_lutris_conversion.callback;
            dialog.response.connect ((response) => {
                confirmed = response == "convert";
                Idle.add ((owned) resume);
            });
            Window.present_dialog_for_controller (dialog, this);
            yield;
            return confirmed;
        }

        bool should_change_tool (Models.CompatibilityTool? selected_tool) {
            if (runner_only || single_steam_game)
                return selected_tool != null && selected_tool.internal_title != items[0].game.compatibility_tool;
            return compatibility_tool_apply_row.active;
        }

        void refresh () {
            var selected_tool = compatibility_tool_row?.get_selected_item () as Models.CompatibilityTool;
            var tool_enabled = should_change_tool (selected_tool);
            var selected_runner = selected_tool?.internal_title;
            var repair = lutris_game?.repairable_runner;
            lutris_repair_row.visible = repair != null && selected_runner == lutris_game.compatibility_tool;
            if (repair != null)
                lutris_repair_row.title = _("Restore %s").printf (repair);
            var kind = lutris_game?.get_runner_kind (selected_runner == "Default" ? null : selected_runner) ??
                Models.CompatibilityToolRuntimeKind.UNKNOWN;
            lutris_options.set_runner_kind (kind);
            var environment_error = lutris_game == null ? null : lutris_options.environment_error;
            var lutris_options_changed = lutris_game != null &&
                (!lutris_options.runner_changes ().is_empty || !lutris_options.system_changes ().is_empty);
            string? tool_error = null;
            if (tool_enabled) {
                if (selected_tool == null)
                    tool_error = _("Choose a compatibility tool.");
                else if (selected_tool.availability_diagnostic != null)
                    tool_error = selected_tool.availability_diagnostic;
                else if (!selected_tool.is_assignable || !selected_tool.is_available)
                    tool_error = _("Choose an available compatibility tool.");
                else
                    tool_error = compatibility_tool_diagnostic;
            }
            if (compatibility_tool_row != null) {
                compatibility_tool_row.subtitle = lutris_game != null && selected_runner == "Default"
                    ? lutris_game.get_inherited_runner_title ()
                    : tool_error ?? (lutris_game != null ? selected_tool?.availability_diagnostic : null) ?? "";
            }

            var compatibility_warning = launch_options_editor.visible ? launch_options_editor.compatibility_warning : "";
            var blocker = tool_error ?? environment_error ?? compatibility_warning;
            if (blocker == "" && launch_options_editor.visible)
                blocker = launch_options_editor.preview_field.blocking_reason;
            var incompatibility = tool_error != null || environment_error != null || compatibility_warning != "";
            var dependency_action = !incompatibility && launch_options_editor.visible
                ? launch_options_editor.dependency_action_label : "";
            apply_blocker.update (blocker, dependency_action, apply_request == null, incompatibility);

            clear_button.sensitive = apply_request == null && (lutris_game != null
                ? lutris_options.can_clear_environment : launch_options_editor.can_clear);
            var launch_options_changed = launch_options_editor.has_changes_to_write
                || (!launch_options_editor.writing_allowed && launch_options_editor.is_dirty);
            reset_button.sensitive = apply_request == null && (launch_options_changed || tool_enabled || lutris_options_changed);
            apply_button.sensitive = apply_request == null && tool_error == null && environment_error == null &&
                (runner_only || launch_options_editor.writing_allowed)
                && (tool_enabled || lutris_options_changed || launch_options_editor.has_changes_to_write);
        }

        void clear_button_clicked () {
            if (lutris_game != null)
                lutris_options.clear_environment ();
            else
                launch_options_editor.clear ();
        }

        void reset_changes () {
            compatibility_tool_diagnostic = null;
            compatibility_tool_apply_row.active = false;
            compatibility_tool_row.selected = initial_tool_selection;
            lutris_options.load (lutris_game, true);
            launch_options_editor.reset ();
            refresh_capability_context ();
        }

        async void apply_button_clicked () {
            if (!apply_button.sensitive)
                return;
            var request = new Cancellable ();
            apply_request = request;
            content_box.sensitive = false;
            refresh ();
            try {
                yield apply_changes (request);
            } finally {
                apply_request = null;
                content_box.sensitive = true;
                refresh ();
            }
        }

        async void apply_changes (Cancellable request) {
            var generation = load_generation;
            var selected_items = items;
            var selected_tool = compatibility_tool_row.get_selected_item () as Models.CompatibilityTool;
            var change_tool = should_change_tool (selected_tool);
            if (lutris_game != null && selected_tool != null) {
                yield apply_lutris_changes (lutris_game, selected_items[0], change_tool,
                    selected_tool.internal_title, lutris_options.runner_changes (), lutris_options.system_changes (),
                    request, generation);
                return;
            }
            if (change_tool) {
                foreach (var item in selected_items) {
                    var steam = item.game.launcher as Models.Launchers.Steam;
                    if (steam != null && !steam.can_assign_compatibility_tool (((!) selected_tool).internal_title)) {
                        compatibility_tool_diagnostic = _("This tool is no longer available. Choose a different tool.");
                        refresh ();
                        return;
                    }
                }
            }
            var invalids = new List<string> ();
            var launch_writes = new Gee.HashMap<Models.Games.Steam, LaunchOptions.LaunchCommandWriteResult> ();

            if (launch_options_editor.is_dirty && launch_options_editor.visible) {
                var context = yield resolve_launch_option_capabilities ();
                if (generation != load_generation || request.is_cancelled ())
                    return;
                launch_options_editor.set_capability_context (context);
                /* A batch selection is an intent.  Each Steam game keeps its
                 * own source command and is prepared before any persistent
                 * compatibility-tool or VDF write can occur. */
                foreach (var item in selected_items) {
                    var steam_game = item.game as Models.Games.Steam;
                    if (steam_game == null)
                        continue;
                    var launch_write = launch_options_editor.prepare_write_for_source (
                        steam_game.launch_options ?? "");
                    if (!launch_write.writing_allowed) {
                        string detail;
                        if (launch_write.writer_diagnostics.size > 0)
                            detail = launch_write.writer_diagnostics[0];
                        else if (launch_write.composition_diagnostics.size > 0)
                            detail = launch_write.composition_diagnostics[0].message;
                        else
                            detail = _("The selected launch options are incomplete or unsupported for these games.");
                        if (launch_write.status == LaunchOptions.LaunchCommandWriteStatus.BLOCKED_CUSTOM_WRAPPER_CONFLICT)
                            detail = _("%s — %s").printf (steam_game.name, detail);
                        var dialog = new Main.ErrorDialog (_("Launch options cannot be applied"),
                            _("No games were changed because the launch command could not be prepared safely."), detail);
                        ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());
                        return;
                    }
                    launch_writes.set (steam_game, launch_write);
                }
            }

            foreach (var item in selected_items) {
                var compatibility_applied = true;
                if (change_tool) {
                    var runner_id = ((!) selected_tool).internal_title;
                    var success = yield item.game.change_compatibility_tool_async (runner_id, request);
                    if (request.is_cancelled () || generation != load_generation || get_root () == null)
                        return;
                    if (!success) {
                        if (runner_only) {
                            var detail = item.game.compatibility_edit_error ?? _("The change could not be saved.");
                            var dialog = new Main.ErrorDialog (_("Could Not Change the Runner"), item.game.name, detail);
                            Window.present_dialog_for_controller (dialog, (Gtk.Window) get_root ());
                            return;
                        }
                        compatibility_applied = false;
                        if (invalids.find (item.game.name) == null)
                            invalids.append (item.game.name);
                    } else {
                        item.refresh_tool_title ();
                    }
                }

                /* Launch-option eligibility was resolved against the proposed
                 * tool. Never persist that command if this game's tool update
                 * failed and left a different runtime in place. */
                if (!compatibility_applied)
                    continue;

                var steam_game = item.game as Models.Games.Steam;
                if (steam_game != null && launch_writes.has_key (steam_game)) {
                    var launch_write = launch_writes.get (steam_game);
                    if (launch_write == null || !launch_write.requires_persistence)
                        continue;
                    var steam_launcher = (Models.Launchers.Steam) steam_game.launcher;

                    var success = steam_game.change_launch_options (launch_write.launch_line, steam_launcher.profile.localconfig_path);
                    if (!success && invalids.find (item.game.name) == null)
                        invalids.append (item.game.name);
                }
            }

            if (invalids.length () > 0) {
                var names = "";

                for (var i = 0; i < invalids.length (); i++) {
                    names += "- %s".printf (invalids.nth_data (i));

                    if (i != invalids.length () - 1)
                        names += "\n";
                }

                var dialog = new Main.ErrorDialog (
                    _("Batch Update Failed"),
                    _("Some games could not be updated. Their tool or configuration may have changed or become unavailable."),
                    names
                );
                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());
            }

            back_requested ();
        }

        private async void apply_lutris_changes (Models.Games.Lutris game, GameListItem item, bool change_runner,
            string runner_id, Gee.Map<string, string?> runner_settings, Gee.Map<string, string?> system_settings,
            Cancellable request, uint generation) {
            string? confirmation = null;
            while (generation == load_generation && !request.is_cancelled () && get_root () != null) {
                var saved = yield game.save_settings (change_runner, runner_id, runner_settings, request, confirmation, system_settings);
                if (generation != load_generation || request.is_cancelled () || get_root () == null)
                    return;
                if (saved) {
                    item.refresh_tool_title ();
                    back_requested ();
                    return;
                }
                confirmation = game.pending_conversion;
                if (confirmation == null) {
                    var detail = game.compatibility_edit_error ?? _("The change could not be saved.");
                    Window.present_dialog_for_controller (new Main.ErrorDialog (
                        _("Could Not Save Lutris Settings"), game.name, detail), (Gtk.Window) get_root ());
                    return;
                }
                if (!yield confirm_lutris_conversion ())
                    return;
            }
        }

        void refresh_capability_context () {
            var generation = ++capability_generation;
            if (items != null && launch_options_editor.visible) {
                resolve_launch_option_capabilities.begin (true, (obj, result) => {
                    var context = resolve_launch_option_capabilities.end (result);
                    if (generation == capability_generation && launch_options_editor.visible) {
                        launch_options_editor.set_capability_context (context);
                        refresh ();
                    }
                });
            }
            refresh ();
        }

        async LaunchOptions.LaunchCommandCapabilityContext resolve_launch_option_capabilities (bool publish_initial = false) {
            var runtimes = new Models.CompatibilityToolRuntimeKind[items.length];
            var selected_tools = new Gee.ArrayList<Models.CompatibilityTool> ();
            var all_tools_known = true;
            var runtime_index = 0;
            var all_steam = items.length > 0;
            var obs_vkcapture = items.length > 0;
            var obs_gamecapture = items.length > 0;
            var native_steam = items.length > 0;
            var steam_tool_roots = new Gee.HashSet<string> ();
            foreach (var item in items) {
                var steam = item.game.launcher as Models.Launchers.Steam;
                all_steam &= item.game is Models.Games.Steam;
                native_steam &= steam?.installation_type == Models.Launcher.InstallationTypes.SYSTEM;
                if (steam != null && steam.installation_type == Models.Launcher.InstallationTypes.SYSTEM)
                    steam_tool_roots.add (steam.get_managed_compatibility_tools_root ());
                var flatpak_capture = steam?.installation_type == Models.Launcher.InstallationTypes.FLATPAK
                    && Globals.OBS_VKCAPTURE_FLATPAK_INSTALLED;
                var host_capture = steam?.installation_type == Models.Launcher.InstallationTypes.SYSTEM;
                obs_vkcapture &= flatpak_capture || (host_capture && Globals.OBS_VKCAPTURE_INSTALLED);
                obs_gamecapture &= flatpak_capture || (host_capture && Globals.OBS_GAMECAPTURE_INSTALLED);
            }

            var selected_tool = compatibility_tool_row?.get_selected_item () as Models.CompatibilityTool;
            var proposed = should_change_tool (selected_tool) ? selected_tool : null;

            if (proposed != null) {
                foreach (var item in items) {
                    var effective = resolve_effective_tool (item, proposed);
                    runtimes[runtime_index++] = capability_resolver.runtime_for_tool (effective ?? proposed);
                    if (effective == null || effective.inspection_path.strip () == "")
                        all_tools_known = false;
                    else
                        selected_tools.add (effective);
                }
            } else {
                foreach (var item in items) {
                    if (item.game.is_native) {
                        runtimes[runtime_index++] = Models.CompatibilityToolRuntimeKind.NATIVE;
                        all_tools_known = false;
                        continue;
                    }
                    var current = compatibility_tools_by_id.get (item.game.compatibility_tool);
                    var effective = resolve_effective_tool (item, current);
                    runtimes[runtime_index++] = capability_resolver.runtime_for_tool (effective ?? current);
                    if (effective == null || effective.inspection_path.strip () == "")
                        all_tools_known = false;
                    else
                        selected_tools.add (effective);
                }
            }

            var components = new LaunchOptions.LaunchOptionInstalledComponents (
                Globals.MANGOHUD_INSTALLED || Globals.MANGOHUD_FLATPAK_INSTALLED,
                Globals.GAMEMODE_INSTALLED, Globals.GAMESCOPE_INSTALLED,
                Globals.SCOPEBUDDY_INSTALLED, Globals.VKBASALT_INSTALLED,
                Globals.GAME_PERFORMANCE_INSTALLED,
                obs_vkcapture, obs_gamecapture,
                native_steam && Globals.AMD_VULKAN_SWITCHER_INSTALLED,
                native_steam && Globals.MANGOAPP_INSTALLED, Globals.SCOPEBUDDY_COMMAND ?? ""
            );
            Models.CompatibilityTool[] tools = all_tools_known
                ? selected_tools.to_array () : new Models.CompatibilityTool[0];
            var vendor = gpu_vendor;
            var native_wrapper_candidates = native_steam && all_steam;
            foreach (var runtime in runtimes)
                native_wrapper_candidates &= runtime == Models.CompatibilityToolRuntimeKind.NATIVE;
            var wrapper_roots = native_wrapper_candidates ? steam_tool_roots.to_array () : new string[0];
            if (publish_initial || (tools.length == 0 && wrapper_roots.length == 0)) {
                var initial = capability_resolver.resolve (runtimes, all_steam, components, vendor);
                if (publish_initial)
                    launch_options_editor.set_capability_context (initial, tools.length > 0 || wrapper_roots.length > 0);
                if (tools.length == 0 && wrapper_roots.length == 0)
                    return initial;
            }
            SourceFunc callback = resolve_launch_option_capabilities.callback;
            LaunchOptions.LaunchCommandCapabilityContext context = null;
            new Thread<void> ("launch-option-capabilities", () => {
                var resolver = new LaunchOptions.LaunchOptionCapabilityResolver ();
                context = resolver.resolve (runtimes, all_steam, components, vendor, tools, wrapper_roots);
                Idle.add ((owned) callback, Priority.DEFAULT);
            });
            yield;
            return context;
        }

        Models.CompatibilityTool? resolve_effective_tool (
            GameListItem item, Models.CompatibilityTool? selected
        ) {
            if (selected == null || selected.internal_title != "Default"
                || selected.runtime_kind == Models.CompatibilityToolRuntimeKind.NATIVE)
                return selected;

            var steam = item.game.launcher as Models.Launchers.Steam;
            return steam?.resolve_effective_compatibility_tool (selected.internal_title);
        }
    }

    class LaunchOptionsBlocker : Gtk.Widget {
        const int SPACING = 8;
        const int INLINE_MESSAGE_WIDTH = 240;

        Gtk.Label message;
        public Gtk.Button action { get; private set; }

        public LaunchOptionsBlocker () {
            Object (visible: false, accessible_role: Gtk.AccessibleRole.GROUP);
            add_css_class ("launch-options-blocker");
            message = new Gtk.Label (null) {
                xalign = 0, wrap = true, wrap_mode = Pango.WrapMode.WORD_CHAR
            };
            action = new Gtk.Button () { can_shrink = true, visible = false };
            message.set_parent (this);
            action.set_parent (this);
        }

        public void update (string text, string action_label, bool action_enabled, bool error) {
            message.label = text;
            action.label = action_label;
            action.sensitive = action_enabled;
            action.visible = action_label != "";
            if (error)
                add_css_class ("launch-options-blocker-error");
            else
                remove_css_class ("launch-options-blocker-error");
            visible = text != "";
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        bool stack_action (int width, int action_width) {
            return action.visible && width >= 0 && width < INLINE_MESSAGE_WIDTH + SPACING + action_width;
        }

        public override void measure (Gtk.Orientation orientation, int for_size, out int minimum,
            out int natural, out int minimum_baseline, out int natural_baseline) {
            minimum_baseline = natural_baseline = -1;
            if (!action.visible) {
                message.measure (orientation, for_size, out minimum, out natural, null, null);
                return;
            }

            int action_min, action_width;
            action.measure (Gtk.Orientation.HORIZONTAL, -1, out action_min, out action_width, null, null);
            if (orientation == Gtk.Orientation.HORIZONTAL) {
                message.measure (orientation, -1, out minimum, out natural, null, null);
                minimum = int.max (minimum, action_min);
                natural += SPACING + action_width;
                return;
            }

            var stacked = stack_action (for_size, action_width);
            var message_width = stacked || for_size < 0 ? for_size : for_size - SPACING - action_width;
            int action_min_height, action_height;
            action.measure (orientation, stacked ? int.min (for_size, action_width) : action_width,
                out action_min_height, out action_height, null, null);
            message.measure (orientation, message_width, out minimum, out natural, null, null);
            minimum = stacked ? minimum + SPACING + action_min_height : int.max (minimum, action_min_height);
            natural = stacked ? natural + SPACING + action_height : int.max (natural, action_height);
        }

        public override void size_allocate (int width, int height, int baseline) {
            if (!action.visible) {
                message.allocate (width, height, -1, null);
                return;
            }

            int action_width, action_height;
            action.measure (Gtk.Orientation.HORIZONTAL, -1, null, out action_width, null, null);
            var stacked = stack_action (width, action_width);
            action_width = int.min (width, action_width);
            action.measure (Gtk.Orientation.VERTICAL, action_width, null, out action_height, null, null);

            var rtl = get_direction () == Gtk.TextDirection.RTL;
            var message_x = rtl && !stacked ? action_width + SPACING : 0;
            var action_at_right = stacked ? rtl : !rtl;
            var action_x = action_at_right ? width - action_width : 0;
            var action_y = stacked ? height - action_height : (height - action_height) / 2;
            allocate_child (message, stacked ? width : width - SPACING - action_width,
                stacked ? int.max (0, action_y - SPACING) : height, message_x, 0);
            allocate_child (action, action_width, action_height, action_x, action_y);
        }

        void allocate_child (Gtk.Widget child, int width, int height, int x, int y) {
            Graphene.Point offset = { x, y };
            child.allocate (width, height, -1, new Gsk.Transform ().translate (offset));
        }

        public override void snapshot (Gtk.Snapshot snapshot) {
            snapshot_child (message, snapshot);
            if (action.visible)
                snapshot_child (action, snapshot);
        }

        public override void dispose () {
            if (message.get_parent () == this)
                message.unparent ();
            if (action.get_parent () == this)
                action.unparent ();
            base.dispose ();
        }
    }
}
