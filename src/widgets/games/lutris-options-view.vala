namespace ProtonPlus.Widgets.Games {
    using Services;

    internal class LutrisOptionsView : Gtk.Box {
        public signal void changed ();

        private Adw.PreferencesGroup runner_group = new Adw.PreferencesGroup () { title = _("Runner options") };
        private Adw.PreferencesGroup system_group = new Adw.PreferencesGroup () { title = _("System options") };
        private Adw.SwitchRow prefix_override = new Adw.SwitchRow () {
            title = _("Override command prefix"), use_markup = false
        };
        private Adw.EntryRow prefix_entry = new Adw.EntryRow () { title = _("Command prefix") };
        private Adw.ExpanderRow environment_row = new Adw.ExpanderRow () { title = _("Environment variables") };
        private Gtk.TextView environment_editor = new Gtk.TextView () {
            accepts_tab = false, wrap_mode = Gtk.WrapMode.NONE,
            left_margin = 8, right_margin = 8, top_margin = 6, bottom_margin = 6,
            monospace = true
        };

        private Gee.HashMap<string, Adw.ComboRow> toggles = new Gee.HashMap<string, Adw.ComboRow> ();
        private Gee.HashMap<LutrisGraphicsVersions, Adw.ComboRow> versions =
            new Gee.HashMap<LutrisGraphicsVersions, Adw.ComboRow> ();
        private LutrisGameOptions? baseline;

        public LutrisOptionsView () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
            append (runner_group);
            append (system_group);
            system_group.add (prefix_override);
            system_group.add (prefix_entry);
            system_group.add (environment_row);

            var environment_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                margin_start = 12, margin_end = 12, margin_top = 8, margin_bottom = 12
            };
            environment_content.append (new Gtk.Label (
                _("Enter one NAME=value per line. Removing an override restores any inherited value.")) {
                wrap = true, xalign = 0
            });
            var scroller = new Gtk.ScrolledWindow () {
                child = environment_editor, min_content_height = 105, has_frame = true
            };
            environment_content.append (scroller);
            environment_row.add_row (new Adw.PreferencesRow () { child = environment_content, activatable = false });

            prefix_override.notify["active"].connect (() => {
                prefix_entry.visible = prefix_override.visible && prefix_override.active;
                changed ();
            });
            prefix_entry.changed.connect (() => changed ());
            environment_editor.buffer.changed.connect (() => changed ());
        }

        public void load (Models.Games.Lutris? game) {
            foreach (var row in toggles.values)
                runner_group.remove (row);
            foreach (var row in versions.values)
                runner_group.remove (row);
            toggles.clear ();
            versions.clear ();

            baseline = game?.game_options;
            visible = baseline != null;
            if (baseline == null)
                return;
            foreach (var key in LutrisGameOptions.toggle_keys ()) {
                if (baseline.has_toggle (key))
                    add_toggle (key);
                if (game.graphics_versions != null)
                    foreach (var choices in game.graphics_versions)
                        if (choices.component == key && choices.editable)
                            add_version (choices);
            }
            prefix_override.visible = baseline.command_prefix_editable;
            prefix_override.subtitle = baseline.inherited_prefix == null || baseline.inherited_prefix == "" ? "" :
                _("Inherited command prefix: %s").printf (baseline.inherited_prefix);
            prefix_override.active = baseline.command_prefix != null;
            prefix_entry.text = baseline.command_prefix ?? "";
            prefix_entry.visible = prefix_override.visible && prefix_override.active;
            environment_row.visible = baseline.environment != null;
            environment_row.expanded = false;
            environment_editor.buffer.text = baseline.environment ?? "";
            system_group.visible = prefix_override.visible || environment_row.visible;
        }

        private void add_toggle (string key) {
            string title;
            switch (key) {
                case "dxvk": title = _("Enable DXVK"); break;
                case "vkd3d": title = _("Enable VKD3D"); break;
                case "esync": title = _("Enable Esync"); break;
                default: title = _("Enable Fsync"); break;
            }
            var inherited = baseline.get_inherited_toggle (key);
            var current = baseline.get_toggle (key);
            string[] labels = {
                inherited == null ? _("Inherit") : inherited == "true" ? _("Inherit (On)") : _("Inherit (Off)"),
                _("On"), _("Off")
            };
            var row = new Adw.ComboRow () {
                title = title, model = new Gtk.StringList (labels),
                selected = current == null ? 0 : current == "true" ? 1 : 2
            };
            row.set_data<uint> ("initial-selection", row.selected);
            toggles.set (key, row);
            runner_group.add (row);
            row.notify["selected"].connect (() => changed ());
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
            runner_group.add (row);
            row.notify["selected"].connect (() => changed ());
        }

        public void set_runner_kind (Models.CompatibilityToolRuntimeKind kind) {
            var wine = kind == Models.CompatibilityToolRuntimeKind.WINE;
            var proton = kind == Models.CompatibilityToolRuntimeKind.PROTON;
            var has_visible_runner_options = false;
            foreach (var entry in toggles.entries) {
                entry.value.visible = wine || (proton && entry.key != "vkd3d");
                has_visible_runner_options |= entry.value.visible;
            }
            foreach (var entry in versions.entries) {
                var toggle = toggles.get (entry.key.component);
                var enabled = entry.key.enabled;
                if (toggle != null)
                    enabled = toggle.selected == 0 ? baseline.get_inherited_toggle (entry.key.component) != "false" :
                        toggle.selected == 1;
                entry.value.visible = wine && enabled;
                has_visible_runner_options |= entry.value.visible;
            }
            runner_group.visible = has_visible_runner_options;
        }

        public Gee.Map<string, string?> runner_changes () {
            var edits = new Gee.HashMap<string, string?> ();
            if (baseline == null)
                return edits;
            foreach (var entry in toggles.entries) {
                var row = entry.value;
                if (row.visible && row.selected != row.get_data<uint> ("initial-selection"))
                    edits.set (entry.key, row.selected == 0 ? null : row.selected == 1 ? "true" : "false");
            }
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
            if (prefix_override.visible) {
                string? prefix = prefix_override.active ? prefix_entry.text : null;
                if (prefix != baseline.command_prefix)
                    edits.set (LutrisGameOptions.COMMAND_PREFIX, prefix);
            }
            if (environment_row.visible) {
                var text = environment_editor.buffer.text;
                if (text != baseline.environment)
                    edits.set (LutrisGameOptions.ENVIRONMENT, text);
            }
            return edits;
        }
    }
}
