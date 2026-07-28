namespace ProtonPlus.Widgets.Games {
    public class MassEditView : Gtk.Box {
        public signal void back_requested ();

        Gtk.Button back_button;
        Gtk.Button clear_button;
        Gtk.Button apply_button;
        Gtk.MenuButton selection_button;
        Adw.HeaderBar header_bar { get; set; }
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
        public GameRow[] rows;
        uint initial_compatibility_tool_index;
        LaunchOptionsEditor.LaunchOptionCapabilityResolver capability_resolver;
        Utils.GpuVendor gpu_vendor = Utils.GpuVendor.UNKNOWN;

        public string get_selection_text () {
            return rows.length == 1 ? _("1 game selected") : _("%u games selected").printf (rows.length);
        }

        public MassEditView (Gtk.Button back_button, Gtk.Button clear_button, Gtk.Button apply_button, Gtk.MenuButton selection_button) {
            set_orientation (Gtk.Orientation.VERTICAL);

            this.back_button = back_button;
            this.clear_button = clear_button;
            this.apply_button = apply_button;
            this.selection_button = selection_button;

            this.back_button.clicked.connect (() => back_requested ());
            this.clear_button.clicked.connect (clear_button_clicked);
            this.apply_button.clicked.connect (apply_button_clicked);

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

            header_bar = new Adw.HeaderBar () {
                show_start_title_buttons = false,
                show_end_title_buttons = false,
                show_title = true,
                title_widget = selection_button
            };
            header_bar.pack_start (back_button);

            var action_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            action_buttons.append (clear_button);
            action_buttons.append (apply_button);
            header_bar.pack_end (action_buttons);

            append (header_bar);
            append (scrolled_window);
        }

        public void load (GameRow[] rows, ListStore model, Gtk.PropertyExpression expression) {
            this.rows = rows;

            var has_steam_launch_options = false;
            var all_native = rows.length > 0;
            var all_steam_linux_runtime_compatible = rows.length > 0;
            foreach (var row in rows) {
                if (row.game.launcher is Models.Launchers.Steam)
                    has_steam_launch_options = true;

                if (!row.game.is_native)
                    all_native = false;

                var steam_game = row.game as Models.Games.Steam;
                if (!row.game.is_native && (steam_game == null || !steam_game.is_non_steam))
                    all_steam_linux_runtime_compatible = false;
            }

            if (compatibility_tool_row != null)
                compatibility_tool_group.remove (compatibility_tool_row);

            var compatibility_tools = new Gee.ArrayList<Models.CompatibilityTool> ();
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
            }

            compatibility_tool_row = new CompatibilityToolRow (filtered_model, expression);
            compatibility_tool_group.add (compatibility_tool_row);

            if (rows.length == 1) {
                var game = rows[0].game;

                var filtered_n_items = filtered_model.get_n_items ();
                for (uint i = 0; i < filtered_n_items; i++) {
                    var runner = filtered_model.get_item (i) as Models.CompatibilityTool;
                    if (runner != null && runner.internal_title == game.compatibility_tool) {
                        compatibility_tool_row.selected = i;
                        break;
                    }
                }

                if (game is Models.Games.Steam) {
                    var steam_game = (Models.Games.Steam) game;
                    launch_options_editor.set_text (steam_game.launch_options ?? "");
                } else {
                    launch_options_editor.set_text ("");
                }
            } else {
                launch_options_editor.set_text ("");
            }

            launch_options_group.set_visible (has_steam_launch_options);
            launch_options_editor.set_visible (has_steam_launch_options);

            compatibility_tool_switch.set_active (rows.length == 1);
            launch_options_switch.set_active (rows.length == 1);

            compatibility_tool_row.set_sensitive (compatibility_tool_switch.active);
            launch_options_editor.set_sensitive (launch_options_switch.active);

            initial_compatibility_tool_index = compatibility_tool_row.selected;
            compatibility_tool_row.notify["selected"].connect (() => {
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
                               && compatibility_tool_row.selected != initial_compatibility_tool_index;
            var launch_options_changed = launch_options_switch.active && launch_options_editor.is_dirty;

            clear_button.set_sensitive (launch_options_changed || tool_changed);
            apply_button.set_sensitive (launch_options_changed || tool_changed);
        }

        void clear_button_clicked () {
            launch_options_editor.clear ();
            compatibility_tool_row.selected = initial_compatibility_tool_index;
            compatibility_tool_switch.set_active (rows.length == 1);
            launch_options_switch.set_active (rows.length == 1);
            refresh ();
        }

        void apply_button_clicked () {
            var item = (Models.CompatibilityTool) compatibility_tool_row.get_selected_item ();
            var invalids = new List<string> ();
            var launch_writes = new Gee.HashMap<Models.Games.Steam, LaunchOptionsEditor.LaunchCommandWriteResult> ();

            if (launch_options_switch.active && launch_options_editor.is_dirty) {
                refresh_capability_context ();
                /* A batch selection is an intent.  Each Steam game keeps its
                 * own source command and is prepared before any persistent
                 * compatibility-tool or VDF write can occur. */
                foreach (var row in rows) {
                    var steam_game = row.game as Models.Games.Steam;
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

            foreach (var row in rows) {
                if (compatibility_tool_switch.active) {
                    var success = row.game.change_compatibility_tool (item.internal_title);
                    if (!success && invalids.find (row.game.name) == null) {
                        invalids.append (row.game.name);
                    } else if (success) {
                        row.refresh_tool_label ();
                    }
                }

                var steam_game = row.game as Models.Games.Steam;
                if (steam_game != null && launch_writes.has_key (steam_game)) {
                    var launch_write = launch_writes.get (steam_game);
                    if (launch_write == null || !launch_write.requires_persistence)
                        continue;
                    var steam_launcher = (Models.Launchers.Steam) steam_game.launcher;

                    var success = steam_game.change_launch_options (launch_write.launch_line, steam_launcher.profile.localconfig_path);
                    if (!success && invalids.find (row.game.name) == null)
                        invalids.append (row.game.name);
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
            if (rows != null)
                launch_options_editor.set_capability_context (resolve_launch_option_capabilities ());
        }

        LaunchOptionsEditor.LaunchCommandCapabilityContext resolve_launch_option_capabilities () {
            var runtimes = new Gee.ArrayList<Models.CompatibilityToolRuntimeKind> ();
            var all_steam = rows.length > 0;
            foreach (var row in rows) {
                if (!(row.game is Models.Games.Steam))
                    all_steam = false;
            }

            Models.CompatibilityTool? proposed = null;
            if (compatibility_tool_switch.active && compatibility_tool_row != null
                && compatibility_tool_row.selected != initial_compatibility_tool_index)
                proposed = compatibility_tool_row.get_selected_item () as Models.CompatibilityTool;
            else if (rows.length == 1 && compatibility_tool_row != null)
                proposed = compatibility_tool_row.get_selected_item () as Models.CompatibilityTool;

            if (proposed != null) {
                var runtime = capability_resolver.runtime_for_tool (proposed);
                foreach (var ignored in rows)
                    runtimes.add (runtime);
            } else {
                foreach (var row in rows) {
                    /* Non-native games without explicit runtime metadata stay
                     * unknown; never infer Proton from their UI title. */
                    runtimes.add (row.game.is_native
                        ? Models.CompatibilityToolRuntimeKind.NATIVE
                        : Models.CompatibilityToolRuntimeKind.UNKNOWN);
                }
            }

            var components = new LaunchOptionsEditor.LaunchOptionInstalledComponents (
                Globals.MANGOHUD_INSTALLED || Globals.MANGOHUD_FLATPAK_INSTALLED,
                Globals.GAMEMODE_INSTALLED, Globals.GAMESCOPE_INSTALLED,
                Globals.SCOPEBUDDY_INSTALLED, Globals.VKBASALT_INSTALLED
            );
            return capability_resolver.resolve (runtimes.to_array (), all_steam, components, gpu_vendor);
        }
    }
}
