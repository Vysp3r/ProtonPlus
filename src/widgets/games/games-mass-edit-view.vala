namespace ProtonPlus.Widgets.Games {
    public class MassEditView : Gtk.Box {
        public signal void back_requested ();

        Gtk.Button clear_button;
        Gtk.Button apply_button;
        Gtk.MenuButton selection_button;
        public Header.Presentation header_presentation { get; private set; }
        Adw.Clamp content_clamp { get; set; }
        Gtk.ScrolledWindow scrolled_window { get; set; }
        CompatibilityToolRow compatibility_tool_row { get; set; }
        Adw.PreferencesGroup compatibility_tool_group { get; set; }
        Adw.PreferencesGroup launch_options_group { get; set; }
        Gtk.Switch compatibility_tool_switch { get; set; }
        Gtk.Switch launch_options_switch { get; set; }
        LaunchOptionsEditor.Box launch_options_editor { get; set; }
        Gtk.Box content_box { get; set; }
        Gtk.Label batch_hint { get; set; }
        public GameListItem[] items;
        LaunchOptionsEditor.LaunchOptionCapabilityResolver capability_resolver;
        Gee.HashMap<string, Models.CompatibilityTool> compatibility_tools_by_id;
        Utils.GpuVendor gpu_vendor = Utils.GpuVendor.UNKNOWN;
        ulong header_back_handler = 0;

        public string get_selection_text () {
            return items.length == 1 ? _("1 game selected") : _("%u games selected").printf (items.length);
        }

        public MassEditView (Gtk.MenuButton selection_button) {
            set_orientation (Gtk.Orientation.VERTICAL);

            this.selection_button = selection_button;

            clear_button = new Gtk.Button.from_icon_name ("eraser-symbolic");
            clear_button.add_css_class ("destructive-action");
            clear_button.set_tooltip_text (_("Clear the current launch options"));
            clear_button.clicked.connect (clear_button_clicked);

            apply_button = new Gtk.Button.from_icon_name ("floppy-disk-symbolic");
            apply_button.add_css_class ("suggested-action");
            apply_button.set_tooltip_text (_("Apply the current modification"));
            apply_button.clicked.connect (apply_button_clicked);

            compatibility_tool_group = new Adw.PreferencesGroup ();
            compatibility_tool_group.set_margin_bottom (12);

            compatibility_tool_switch = new Gtk.Switch () {
                valign = Gtk.Align.CENTER
            };

            var compatibility_tool_header = new Adw.ActionRow () {
                title = _("Apply compatibility tool"),
                subtitle = _("Set the same tool for every selected game."),
                activatable_widget = compatibility_tool_switch
            };
            compatibility_tool_header.add_suffix (compatibility_tool_switch);
            compatibility_tool_group.add (compatibility_tool_header);

            compatibility_tool_switch.notify["active"].connect (() => {
                if (compatibility_tool_row != null)
                    compatibility_tool_row.set_sensitive (compatibility_tool_switch.active);
                refresh_capability_context ();
                refresh ();
            });

            launch_options_editor = new LaunchOptionsEditor.Box ();
            capability_resolver = new LaunchOptionsEditor.LaunchOptionCapabilityResolver ();
            compatibility_tools_by_id = new Gee.HashMap<string, Models.CompatibilityTool> ();
            launch_options_editor.content_changed.connect (refresh);

            launch_options_group = new Adw.PreferencesGroup ();

            launch_options_switch = new Gtk.Switch () {
                valign = Gtk.Align.CENTER
            };

            var launch_options_header = new Adw.ActionRow () {
                title = _("Apply launch options"),
                subtitle = _("Set the same options for every selected Steam game."),
                activatable_widget = launch_options_switch
            };
            launch_options_header.add_suffix (launch_options_switch);
            launch_options_group.add (launch_options_header);

            launch_options_switch.notify["active"].connect (() => {
                launch_options_editor.set_sensitive (launch_options_switch.active);
                refresh ();
            });

            batch_hint = new Gtk.Label (_("Enable the sections you want to change. Disabled sections leave the selected games unchanged.")) {
                halign = Gtk.Align.START,
                wrap = true,
                xalign = 0,
                css_classes = { "dim-label" },
                margin_bottom = 6
            };

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            content_box.append (batch_hint);
            content_box.append (compatibility_tool_group);
            content_box.append (launch_options_group);
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
            header_presentation = new Header.Presentation (selection_button);
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
            return selection_button;
        }

        public void load (GameListItem[] items, ListStore model, Gtk.PropertyExpression expression) {
            this.items = items;

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
                if (Models.Launchers.Steam.is_steam_linux_runtime (runner.display_title, runner.internal_title)
                    && !all_steam_linux_runtime_compatible)
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

            launch_options_group.set_visible (has_steam_launch_options);
            launch_options_editor.set_visible (has_steam_launch_options);

            compatibility_tool_switch.set_active (false);
            launch_options_switch.set_active (false);

            compatibility_tool_row.set_sensitive (compatibility_tool_switch.active);
            launch_options_editor.set_sensitive (launch_options_switch.active);

            compatibility_tool_row.notify["selected-item"].connect (() => {
                refresh_capability_context ();
                refresh ();
            });
            Utils.System.detect_gpu_vendor.begin ((obj, result) => {
                gpu_vendor = Utils.System.detect_gpu_vendor.end (result);
                refresh_capability_context ();
            });
            refresh_capability_context ();

            refresh ();
        }

        void refresh () {
            var tool_changed = compatibility_tool_switch.active
                               && compatibility_tool_row != null
                               && compatibility_tool_row.get_selected_item () != null;
            var launch_options_changed = launch_options_switch.active && launch_options_editor.is_dirty;

            clear_button.set_sensitive (launch_options_editor.is_dirty);
            apply_button.set_sensitive (launch_options_changed || tool_changed);
        }

        void clear_button_clicked () {
            launch_options_editor.clear ();
            launch_options_switch.set_active (true);
            refresh ();
        }

        void apply_button_clicked () {
            var selected_tool = compatibility_tool_row.get_selected_item () as Models.CompatibilityTool;
            if (compatibility_tool_switch.active && selected_tool == null) {
                var dialog = new Main.ErrorDialog (
                    _("Compatibility tool cannot be applied"),
                    _("No games were changed because no compatibility tool is selected."), ""
                );
                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());
                return;
            }
            if (compatibility_tool_switch.active) {
                foreach (var item in items) {
                    var steam = item.game.launcher as Models.Launchers.Steam;
                    if (steam != null && !((!) steam).can_assign_compatibility_tool (((!) selected_tool).internal_title)) {
                        var dialog = new Main.ErrorDialog (
                            _("Compatibility tool cannot be applied"),
                            _("No games were changed because the selected compatibility tool is no longer available."), ""
                        );
                        ProtonPlus.Widgets.Window.present_dialog_for_controller (
                            dialog, (Gtk.Window) this.get_root ()
                        );
                        return;
                    }
                }
            }
            var invalids = new List<string> ();
            var launch_writes = new Gee.HashMap<Models.Games.Steam, LaunchOptionsEditor.LaunchCommandWriteResult> ();

            if (launch_options_switch.active && launch_options_editor.is_dirty) {
                refresh_capability_context ();
                /* A batch selection is an intent.  Each Steam game keeps its
                 * own source command and is prepared before any persistent
                 * compatibility-tool or VDF write can occur. */
                foreach (var item in items) {
                    var steam_game = item.game as Models.Games.Steam;
                    if (steam_game == null)
                        continue;
                    var launch_write = launch_options_editor.prepare_write_for_source (
                        steam_game.launch_options ?? "");
                    if (!launch_write.writing_allowed) {
                        var detail = launch_write.writer_diagnostics.size > 0
                            ? launch_write.writer_diagnostics[0]
                            : _("The selected launch options are incomplete or unsupported for these games.");
                        var dialog = new Main.ErrorDialog (_("Launch options cannot be applied"),
                            _("No games were changed because the launch command could not be prepared safely."), detail);
                        ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());
                        return;
                    }
                    launch_writes.set (steam_game, launch_write);
                }
            }

            foreach (var item in items) {
                var compatibility_applied = true;
                if (compatibility_tool_switch.active) {
                    var success = item.game.change_compatibility_tool (((!) selected_tool).internal_title);
                    if (!success) {
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
                    _("Some games could not be updated with the new compatibility tool or launch options. This may be due to missing permissions or file access issues."), // vala-lint=line-length
                    names
                );
                ProtonPlus.Widgets.Window.present_dialog_for_controller (dialog, (Gtk.Window) this.get_root ());
            }

            back_requested ();
        }

        void refresh_capability_context () {
            if (items != null)
                launch_options_editor.set_capability_context (resolve_launch_option_capabilities ());
        }

        LaunchOptionsEditor.LaunchCommandCapabilityContext resolve_launch_option_capabilities () {
            var runtimes = new Models.CompatibilityToolRuntimeKind[items.length];
            var selected_tools = new Gee.ArrayList<Models.CompatibilityTool> ();
            var all_tools_known = true;
            var runtime_index = 0;
            var all_steam = items.length > 0;
            foreach (var item in items) {
                if (!(item.game is Models.Games.Steam))
                    all_steam = false;
            }

            Models.CompatibilityTool? proposed = null;
            if (compatibility_tool_switch.active && compatibility_tool_row != null)
                proposed = compatibility_tool_row.get_selected_item () as Models.CompatibilityTool;

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

            var components = new LaunchOptionsEditor.LaunchOptionInstalledComponents (
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
