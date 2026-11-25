namespace ProtonPlus.Widgets.Games {
    public class MassEditView : Gtk.Box {
        public signal void back_requested ();

        Gtk.Button clear_button;
        Gtk.Button apply_button;
        Gtk.MenuButton selection_button;
        Gtk.Label game_title;
        public Header.Presentation header_presentation { get; private set; }
        Adw.Clamp content_clamp { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        CompatibilityToolRow compatibility_tool_row { get; set; }
        Adw.PreferencesGroup compatibility_tool_group { get; set; }
        Adw.SwitchRow compatibility_tool_apply_row { get; set; }
        LaunchOptionsEditor.Box launch_options_editor { get; set; }
        Gtk.Box content_box { get; set; }
        GameListItem[] items;
        string? compatibility_tool_diagnostic;
        bool runner_only;
        bool single_steam_game;
        uint load_generation;
        Cancellable? apply_request;
        LaunchOptions.LaunchOptionCapabilityResolver capability_resolver;
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

            var action_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            action_buttons.append (clear_button);
            action_buttons.append (apply_button);
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
            header_presentation.add_end_action (action_buttons);

            append (scrolled_window);
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

            if (compatibility_tool_row != null)
                compatibility_tool_group.remove (compatibility_tool_row);

            var compatibility_tools = new Gee.ArrayList<Models.CompatibilityTool> ();
            compatibility_tools_by_id.clear ();
            var n_items = model.get_n_items ();
            for (uint i = 0; i < n_items; i++) {
                var runner = model.get_item (i) as Models.CompatibilityTool;
                if (runner == null)
                    continue;
                var is_current = items.length == 1 && runner.internal_title == items[0].game.compatibility_tool;
                if (!runner.is_available && !is_current)
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
            compatibility_tool_group.add (compatibility_tool_row);

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

            launch_options_editor.visible = has_steam_launch_options;
            clear_button.visible = has_steam_launch_options;

            compatibility_tool_apply_row.set_visible (!runner_only && !single_steam_game);
            compatibility_tool_apply_row.active = false;
            compatibility_tool_row.visible = runner_only || single_steam_game;
            if (runner_only)
                compatibility_tool_row.title = _("Wine or Proton version");
            else if (single_steam_game)
                compatibility_tool_row.title = _("Compatibility version");

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

        bool should_change_tool (Models.CompatibilityTool? selected_tool) {
            if (runner_only || single_steam_game)
                return selected_tool != null && selected_tool.internal_title != items[0].game.compatibility_tool;
            return compatibility_tool_apply_row.active;
        }

        void refresh () {
            var selected_tool = compatibility_tool_row?.get_selected_item () as Models.CompatibilityTool;
            var tool_enabled = should_change_tool (selected_tool);
            string? tool_error = null;
            if (tool_enabled) {
                if (selected_tool == null)
                    tool_error = _("Choose a compatibility tool.");
                else if (!selected_tool.is_assignable || !selected_tool.is_available)
                    tool_error = _("Choose an available compatibility tool.");
                else
                    tool_error = compatibility_tool_diagnostic;
            }
            if (compatibility_tool_row != null)
                compatibility_tool_row.subtitle = tool_error ?? "";

            clear_button.sensitive = apply_request == null && launch_options_editor.can_clear;
            apply_button.sensitive = apply_request == null && tool_error == null && (runner_only || launch_options_editor.writing_allowed)
                && (tool_enabled || launch_options_editor.has_changes_to_write);
        }

        void clear_button_clicked () {
            launch_options_editor.clear ();
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
                refresh_capability_context ();
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
                    var success = yield item.game.change_compatibility_tool_async (((!) selected_tool).internal_title, request);
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

        void refresh_capability_context () {
            if (items != null && launch_options_editor.visible)
                launch_options_editor.set_capability_context (resolve_launch_option_capabilities ());
            refresh ();
        }

        LaunchOptions.LaunchCommandCapabilityContext resolve_launch_option_capabilities () {
            var runtimes = new Models.CompatibilityToolRuntimeKind[items.length];
            var selected_tools = new Gee.ArrayList<Models.CompatibilityTool> ();
            var all_tools_known = true;
            var runtime_index = 0;
            var all_steam = items.length > 0;
            foreach (var item in items) {
                if (!(item.game is Models.Games.Steam))
                    all_steam = false;
            }

            var selected_tool = compatibility_tool_row?.get_selected_item () as Models.CompatibilityTool;
            var proposed = should_change_tool (selected_tool) ? selected_tool : null;

            if (proposed != null) {
                foreach (var item in items) {
                    var effective = resolve_effective_tool (item, proposed);
                    runtimes[runtime_index++] = capability_resolver.runtime_for_tool (effective ?? proposed);
                    if (effective == null || effective.path.strip () == "")
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
                    if (effective == null || effective.path.strip () == "")
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
                Globals.OBS_VKCAPTURE_INSTALLED
                    || (Globals.OBS_VKCAPTURE_FLATPAK_INSTALLED
                        && Globals.OBS_VKCAPTURE_FLATPAK_PLUGIN_INSTALLED)
            );
            Models.CompatibilityTool[] tools = all_tools_known
                ? selected_tools.to_array () : new Models.CompatibilityTool[0];
            return capability_resolver.resolve (runtimes, all_steam, components, gpu_vendor, tools);
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
}
