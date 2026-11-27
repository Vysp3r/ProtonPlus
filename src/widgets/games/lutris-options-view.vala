namespace ProtonPlus.Widgets.Games {
    using LaunchOptions;
    using Services;

    internal class LutrisOptionsView : Gtk.Box {
        public signal void changed ();

        private Adw.PreferencesGroup runner_group = new Adw.PreferencesGroup () { title = _("Runner options") };
        private Adw.ExpanderRow dxvk_options = new Adw.ExpanderRow () { title = "DXVK", use_markup = false };
        private Adw.ExpanderRow vkd3d_options = new Adw.ExpanderRow () { title = "VKD3D", use_markup = false };
        private Adw.ComboRow? proton_dxvk;
        private Adw.ExpanderRow runner_advanced = new Adw.ExpanderRow () { title = _("Synchronization") };
        private CompatibilityToolRow? version_row;
        private Adw.ActionRow repair_row;
        private Adw.PreferencesGroup system_group = new Adw.PreferencesGroup () { title = _("System options") };
        private Adw.ExpanderRow system_advanced = new Adw.ExpanderRow () { title = _("Runtime and command prefix") };
        private Adw.SwitchRow prefix_override = new Adw.SwitchRow () {
            title = _("Override command prefix"), use_markup = false
        };
        private Adw.EntryRow prefix_entry = new Adw.EntryRow () { title = _("Command prefix") };
        private LutrisEnvironmentEditor environment = new LutrisEnvironmentEditor ();

        public bool can_clear_environment { get { return environment.can_clear; } }
        public string? environment_error { get { return environment.visible ? environment.validation_error : null; } }

        public void clear_environment () {
            environment.clear_variables ();
        }

        private Gee.HashMap<string, Adw.ComboRow> toggles = new Gee.HashMap<string, Adw.ComboRow> ();
        private Gee.HashMap<string, Adw.ComboRow> system_toggles = new Gee.HashMap<string, Adw.ComboRow> ();
        private Gee.HashMap<LutrisGraphicsVersions, Adw.ComboRow> versions =
            new Gee.HashMap<LutrisGraphicsVersions, Adw.ComboRow> ();
        private LutrisGameOptions? baseline;

        public LutrisOptionsView (Adw.ActionRow repair_row) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            this.repair_row = repair_row;
            append (runner_group);
            append (system_group);
            prefix_override.notify["active"].connect (() => {
                prefix_entry.visible = prefix_override.visible && prefix_override.active;
                changed ();
            });
            prefix_entry.changed.connect (() => changed ());
            environment.variables_changed.connect (() => changed ());
        }

        public void set_version_row (CompatibilityToolRow? row) {
            if (version_row != null) {
                runner_group.remove (version_row);
                runner_group.remove (repair_row);
            }
            version_row = row;
            if (row != null) {
                runner_group.add (row);
                runner_group.add (repair_row);
            }
        }

        public void load (Models.Games.Lutris? game, bool preserve_expansion = false) {
            foreach (var entry in toggles.entries) {
                if (is_sync_toggle (entry.key))
                    runner_advanced.remove (entry.value);
                else
                    graphics_options (entry.key).remove (entry.value);
            }
            foreach (var entry in versions.entries)
                graphics_options (entry.key.component).remove (entry.value);
            if (proton_dxvk != null) {
                runner_group.remove (proton_dxvk);
                proton_dxvk = null;
            }
            foreach (var entry in system_toggles.entries) {
                if (is_runtime_toggle (entry.key))
                    system_advanced.remove (entry.value);
                else
                    system_group.remove (entry.value);
            }
            if (runner_advanced.get_parent () != null) {
                runner_group.remove (dxvk_options);
                runner_group.remove (vkd3d_options);
                runner_group.remove (runner_advanced);
            }
            if (system_advanced.get_parent () != null) {
                system_group.remove (environment);
                system_group.remove (system_advanced);
                system_advanced.remove (prefix_override);
                system_advanced.remove (prefix_entry);
            }
            toggles.clear ();
            versions.clear ();
            system_toggles.clear ();

            baseline = game?.game_options;
            visible = game != null;
            if (baseline == null) {
                system_group.visible = false;
                return;
            }
            if (!preserve_expansion) {
                dxvk_options.expanded = false;
                vkd3d_options.expanded = false;
                runner_advanced.expanded = false;
                system_advanced.expanded = false;
            }
            foreach (var key in LutrisGameOptions.toggle_keys ()) {
                if (baseline.has_toggle (key)) {
                    var row = create_toggle (key);
                    toggles.set (key, row);
                    if (is_sync_toggle (key))
                        runner_advanced.add_row (row);
                    else
                        graphics_options (key).add_row (row);
                }
                if (game.graphics_versions != null)
                    foreach (var choices in game.graphics_versions)
                        if (choices.component == key && choices.editable)
                            add_version (choices);
            }
            runner_group.add (dxvk_options);
            var dxvk_toggle = toggles.get ("dxvk");
            if (dxvk_toggle != null) {
                proton_dxvk = new Adw.ComboRow () {
                    title = "DXVK",
                    subtitle = _("When enabled, uses the build bundled with Proton."),
                    model = dxvk_toggle.model, visible = false
                };
                dxvk_toggle.bind_property ("selected", proton_dxvk, "selected",
                    BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
                runner_group.add (proton_dxvk);
            }
            runner_group.add (vkd3d_options);
            runner_group.add (runner_advanced);
            foreach (var key in LutrisGameOptions.system_toggle_keys ()) {
                if (!baseline.has_toggle (key))
                    continue;
                var row = create_toggle (key);
                system_toggles.set (key, row);
                if (is_runtime_toggle (key))
                    system_advanced.add_row (row);
                else
                    system_group.add (row);
            }
            system_group.add (environment);
            system_group.add (system_advanced);
            system_advanced.add_row (prefix_override);
            system_advanced.add_row (prefix_entry);
            prefix_override.visible = baseline.command_prefix_editable;
            prefix_override.subtitle = baseline.inherited_prefix == null || baseline.inherited_prefix == "" ? "" :
                _("Inherited command prefix: %s").printf (baseline.inherited_prefix);
            prefix_override.active = baseline.command_prefix != null;
            prefix_entry.text = baseline.command_prefix ?? "";
            prefix_entry.visible = prefix_override.visible && prefix_override.active;
            environment.load (baseline, preserve_expansion);
            refresh_runtime_options ();
            system_group.visible = !system_toggles.is_empty || prefix_override.visible || environment.visible;
        }

        private static bool is_sync_toggle (string key) {
            return key == "esync" || key == "fsync";
        }

        private static bool is_runtime_toggle (string key) {
            return key == LutrisGameOptions.DISABLE_RUNTIME || key == LutrisGameOptions.PREFER_SYSTEM_LIBS;
        }

        private unowned Adw.ExpanderRow graphics_options (string component) {
            return component == "dxvk" ? dxvk_options : vkd3d_options;
        }

        private Adw.ComboRow create_toggle (string key) {
            string title;
            string subtitle = "";
            switch (key) {
                case "dxvk": title = _("Enable DXVK"); break;
                case "vkd3d": title = _("Enable VKD3D"); break;
                case "esync": title = _("Enable Esync"); break;
                case "fsync": title = _("Enable Fsync"); break;
                case "mangohud":
                    title = _("MangoHud");
                    subtitle = system_tool_status (LutrisSystemTools.MANGOHUD);
                    break;
                case "gamemode":
                    title = _("Feral GameMode");
                    subtitle = system_tool_status (LutrisSystemTools.GAMEMODE);
                    break;
                case LutrisGameOptions.DISABLE_RUNTIME:
                    title = _("Disable Lutris Runtime");
                    subtitle = _("Controls Lutris libraries. umu manages Proton’s Steam Runtime separately.");
                    break;
                default: title = _("Prefer system libraries"); break;
            }
            var inherited = baseline.get_inherited_toggle (key);
            var current = baseline.get_toggle (key);
            string[] labels = {
                inherited == null ? _("Inherit") : inherited == "true" ? _("Inherit (On)") : _("Inherit (Off)"),
                _("On"), _("Off")
            };
            var row = new Adw.ComboRow () {
                title = title, subtitle = subtitle, model = new Gtk.StringList (labels),
                selected = current == null ? 0 : current == "true" ? 1 : 2
            };
            row.set_data<uint> ("initial-selection", row.selected);
            row.notify["selected"].connect (() => {
                if (key == LutrisGameOptions.DISABLE_RUNTIME)
                    refresh_runtime_options ();
                changed ();
            });
            return row;
        }

        private string system_tool_status (LutrisSystemTools tool) {
            if ((baseline.system_tools & LutrisSystemTools.CHECKED) == 0)
                return _("Availability could not be checked");
            return (baseline.system_tools & tool) != 0 ? _("Available in this Lutris installation") :
                _("Unavailable in this Lutris installation");
        }

        private void refresh_runtime_options () {
            var prefer = system_toggles.get (LutrisGameOptions.PREFER_SYSTEM_LIBS);
            var disable = system_toggles.get (LutrisGameOptions.DISABLE_RUNTIME);
            var disabled = disable == null || disable.selected == 0
                ? baseline.get_inherited_toggle (LutrisGameOptions.DISABLE_RUNTIME) == "true"
                : disable.selected == 1;
            if (prefer != null)
                prefer.visible = !disabled;
            system_advanced.visible = disable != null || (prefer != null && prefer.visible) || prefix_override.visible;
        }

        private void add_version (LutrisGraphicsVersions choices) {
            var model = new Gtk.StringList (null);
            model.append (choices.inherited == null ? _("Inherit Lutris default") :
                _("Inherit Lutris default (%s)").printf (choices.inherited));
            uint selected = 0;
            foreach (var version in choices.versions) {
                if (version == choices.saved)
                    selected = model.get_n_items ();
                model.append (version);
            }
            if (choices.saved != null && selected == 0) {
                selected = model.get_n_items ();
                model.append (_("%s (Current setting)").printf (choices.saved));
            }
            var row = new Adw.ComboRow () {
                title = choices.component == "dxvk" ? _("DXVK version") : _("VKD3D version"),
                use_markup = false, model = model, selected = selected
            };
            row.set_data<uint> ("initial-selection", selected);
            versions.set (choices, row);
            graphics_options (choices.component).add_row (row);
            row.notify["selected"].connect (() => changed ());
        }

        public void set_runner_kind (Models.CompatibilityToolRuntimeKind kind) {
            var wine = kind == Models.CompatibilityToolRuntimeKind.WINE;
            var proton = kind == Models.CompatibilityToolRuntimeKind.PROTON;
            var dxvk = graphics_enabled ("dxvk", false);
            environment.set_runner_context (kind, dxvk);
            foreach (var entry in toggles.entries) {
                entry.value.visible = wine || (proton && entry.key != "vkd3d");
            }
            dxvk_options.visible = wine && toggles.has_key ("dxvk");
            vkd3d_options.visible = wine && toggles.has_key ("vkd3d");
            if (proton_dxvk != null)
                proton_dxvk.visible = proton;
            dxvk_options.subtitle = dxvk ? _("On") : _("Off");
            vkd3d_options.subtitle = graphics_enabled ("vkd3d", false) ? _("On") : _("Off");
            runner_advanced.visible = (wine || proton) && (toggles.has_key ("esync") || toggles.has_key ("fsync"));
            foreach (var entry in versions.entries) {
                var choices = entry.key;
                var row = entry.value;
                row.visible = wine && graphics_enabled (choices.component, choices.enabled);
                if (row.visible) {
                    var group = graphics_options (choices.component);
                    var selected = row.selected_item as Gtk.StringObject;
                    var version = row.selected == 0 ? choices.inherited ?? _("Lutris default") : selected?.string;
                    group.subtitle = version != null ? _("%s · %s").printf (_("On"), version) : _("On");
                    group.visible = true;
                }
            }
            if (baseline == null || (!wine && !proton)) {
                environment.set_browser_context (null);
                return;
            }
            // Limit the browser to capabilities known for this Lutris selection.
            // Build-specific Proton features require a separate tool probe.
            LaunchOptionCapability[] capabilities = {};
            if (proton)
                capabilities += LaunchOptionCapability.PROTON;
            if ((baseline.system_tools & LutrisSystemTools.MANGOHUD) != 0)
                capabilities += LaunchOptionCapability.MANGOHUD;
            if (dxvk) {
                capabilities += LaunchOptionCapability.DXVK;
                capabilities += LaunchOptionCapability.DXVK_LOG_PATH;
                capabilities += LaunchOptionCapability.DXVK_DEVICE_FILTER;
                capabilities += LaunchOptionCapability.DXVK_SHADER_CACHE;
                capabilities += LaunchOptionCapability.DXVK_SHADER_CACHE_PATH;
            }
            if (proton ? dxvk : graphics_enabled ("vkd3d", false)) {
                capabilities += LaunchOptionCapability.VKD3D_PROTON;
                capabilities += LaunchOptionCapability.VKD3D_DEVICE_FILTER;
                capabilities += LaunchOptionCapability.VKD3D_DEVICE_INDEX;
                capabilities += LaunchOptionCapability.VKD3D_LOG_FILE;
                capabilities += LaunchOptionCapability.VKD3D_FRAME_RATE;
                capabilities += LaunchOptionCapability.VKD3D_SHADER_CACHE_PATH;
            }
            environment.set_browser_context (new LaunchCommandCapabilityContext (capabilities));
        }

        private bool graphics_enabled (string key, bool fallback) {
            var toggle = toggles.get (key);
            if (toggle == null)
                return fallback;
            return toggle.selected == 0 ? baseline.get_inherited_toggle (key) != "false" : toggle.selected == 1;
        }

        public Gee.Map<string, string?> runner_changes () {
            var edits = new Gee.HashMap<string, string?> ();
            if (baseline == null)
                return edits;
            collect_toggle_changes (toggles, edits);
            foreach (var entry in versions.entries) {
                var row = entry.value;
                var choices = entry.key;
                if (row.visible && row.selected != row.get_data<uint> ("initial-selection") &&
                    row.selected <= choices.versions.size)
                    edits.set (choices.key, row.selected == 0 ? null : choices.versions[(int) row.selected - 1]);
            }
            return edits;
        }

        public Gee.Map<string, string?> system_changes () {
            var edits = new Gee.HashMap<string, string?> ();
            if (baseline == null)
                return edits;
            collect_toggle_changes (system_toggles, edits);
            if (prefix_override.visible) {
                string? prefix = prefix_override.active ? prefix_entry.text : null;
                if (prefix != baseline.command_prefix)
                    edits.set (LutrisGameOptions.COMMAND_PREFIX, prefix);
            }
            if (environment.visible) {
                var text = environment.serialize ();
                if (text != baseline.environment)
                    edits.set (LutrisGameOptions.ENVIRONMENT, text);
            }
            return edits;
        }

        private static void collect_toggle_changes (Gee.Map<string, Adw.ComboRow> rows, Gee.Map<string, string?> edits) {
            foreach (var entry in rows.entries) {
                var row = entry.value;
                if (row.visible && row.selected != row.get_data<uint> ("initial-selection"))
                    edits.set (entry.key, row.selected == 0 ? null : row.selected == 1 ? "true" : "false");
            }
        }
    }
}
