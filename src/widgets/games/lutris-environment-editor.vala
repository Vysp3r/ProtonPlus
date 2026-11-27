namespace ProtonPlus.Widgets.Games {
    using LaunchOptions;

    internal class LutrisEnvironmentRow : Adw.PreferencesRow {
        public signal void changed ();
        public signal void remove_requested (LutrisEnvironmentRow row);

        public Gtk.Entry variable_name { get; private set; }
        public Gtk.Entry variable_value { get; private set; }

        public LutrisEnvironmentRow (string key, string value) {
            var fields = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin_start = 12, margin_end = 12, margin_top = 6, margin_bottom = 6
            };
            variable_name = make_field (_("Name"), key);
            variable_value = make_field (_("Value"), value);
            var remove_button = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
                css_classes = { "flat" }, valign = Gtk.Align.CENTER,
                tooltip_text = _("Remove environment variable")
            };
            remove_button.update_property (Gtk.AccessibleProperty.LABEL, remove_button.tooltip_text, -1);
            remove_button.clicked.connect (() => remove_requested (this));
            fields.append (variable_name);
            fields.append (variable_value);
            fields.append (remove_button);
            child = fields;
            activatable = false;
            selectable = false;
            variable_name.changed.connect (() => changed ());
            variable_value.changed.connect (() => changed ());
        }

        private static Gtk.Entry make_field (string label, string value) {
            var field = new Gtk.Entry () {
                placeholder_text = label, text = value, width_chars = 1, hexpand = true
            };
            field.update_property (Gtk.AccessibleProperty.LABEL, label, -1);
            Utils.TextInputMetadataPolicy.apply (field, Utils.TextInputFieldKind.PATH_OR_IDENTIFIER);
            return field;
        }
    }

    internal class LutrisEnvironmentEditor : Adw.ExpanderRow {
        public signal void variables_changed ();

        private Adw.ComboRow preset_picker = new Adw.ComboRow () { title = _("Add preset"), visible = false };
        private Gtk.Button insert_preset_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
            css_classes = { "flat" }, valign = Gtk.Align.CENTER,
            tooltip_text = _("Insert preset"), sensitive = false
        };
        private Adw.ActionRow add_row_action = new Adw.ActionRow () { title = _("Add variable") };
        private Adw.ActionRow dxvk_hint = new Adw.ActionRow () {
            title = _("DXVK log level"),
            subtitle = _("In Lutris, set Output debugging info to Inherit from environment to use this value."),
            visible = false
        };
        private Gee.ArrayList<LutrisEnvironmentRow> rows = new Gee.ArrayList<LutrisEnvironmentRow> ();
        private Gee.ArrayList<LaunchOptionMetadata> presets = new Gee.ArrayList<LaunchOptionMetadata> ();
        private LaunchOptionMetadata? dxvk_log;
        private LaunchOptionMetadata? proton_log;
        private Models.CompatibilityToolRuntimeKind runner_kind;
        public string? validation_error { get; private set; }
        public bool can_clear { get { return visible && !rows.is_empty; } }

        public LutrisEnvironmentEditor () {
            Object (title: _("Environment variables"), subtitle: _("Removing an override restores any inherited value."));
            add_row (preset_picker);
            insert_preset_button.update_property (Gtk.AccessibleProperty.LABEL, insert_preset_button.tooltip_text, -1);
            insert_preset_button.clicked.connect (add_preset);
            preset_picker.add_suffix (insert_preset_button);
            preset_picker.notify["selected"].connect (() => {
                insert_preset_button.sensitive = preset_picker.selected > 0 && preset_picker.selected <= presets.size;
            });
            add_row (dxvk_hint);
            add_row (add_row_action);
            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
                css_classes = { "flat" }, valign = Gtk.Align.CENTER,
                tooltip_text = _("Add variable")
            };
            add_button.update_property (Gtk.AccessibleProperty.LABEL, add_button.tooltip_text, -1);
            add_button.clicked.connect (() => {
                var row = append_variable ("", "");
                refresh ();
                row.variable_name.grab_focus ();
            });
            add_row_action.add_suffix (add_button);
            add_row_action.activatable_widget = add_button;
        }

        public void load (string? source, bool preserve_expansion) {
            remove_variables ();
            visible = source != null;
            if (visible && dxvk_log == null) {
                var catalog = new LaunchOptionCatalog ();
                dxvk_log = catalog.lookup ("dxvk-log-level");
                proton_log = catalog.lookup ("proton-debug-log");
            }
            if (!preserve_expansion)
                expanded = false;
            if (source != null && source != "") {
                foreach (var line in source.split ("\n")) {
                    var separator = line.index_of_char ('=');
                    append_variable (line.substring (0, separator), line.substring (separator + 1));
                }
            }
            refresh ();
        }

        public void set_runner (Models.CompatibilityToolRuntimeKind runner) {
            if (runner_kind == runner)
                return;
            runner_kind = runner;
            update_presets ();
        }

        public void clear_variables () {
            remove_variables ();
            refresh ();
        }

        public string serialize () {
            var text = new StringBuilder ();
            foreach (var row in rows) {
                if (text.len != 0)
                    text.append_c ('\n');
                text.append ("%s=%s".printf (row.variable_name.text, row.variable_value.text));
            }
            return text.str;
        }

        private LutrisEnvironmentRow append_variable (string key, string value) {
            var row = new LutrisEnvironmentRow (key, value);
            row.changed.connect (refresh);
            row.remove_requested.connect (remove_variable);
            rows.add (row);
            add_row (row);
            return row;
        }

        private void remove_variable (LutrisEnvironmentRow row) {
            var index = rows.index_of (row);
            rows.remove_at (index);
            remove (row);
            refresh ();
            if (index < rows.size)
                rows[index].variable_name.grab_focus ();
            else
                add_row_action.activatable_widget.grab_focus ();
        }

        private void remove_variables () {
            foreach (var row in rows)
                remove (row);
            rows.clear ();
        }

        private bool contains_variable (string key) {
            return rows.any_match ((row) => row.variable_name.text == key);
        }

        private void refresh () {
            validation_error = null;
            var names = new Gee.HashSet<string> ();
            foreach (var row in rows) {
                var key = row.variable_name.text;
                var valid = Services.LutrisConfigurationService.valid_env_name (key);
                var duplicate = valid && !names.add (key);
                var value = row.variable_value.text;
                var multiline = value.contains ("\n") || value.contains ("\r");
                if (validation_error == null) {
                    if (!valid)
                        validation_error = _("Enter a valid name for each environment variable.");
                    else if (duplicate)
                        validation_error = _("Each environment variable needs a unique name.");
                    else if (multiline)
                        validation_error = _("Environment variable values must fit on one line.");
                }
            }
            dxvk_hint.visible = contains_variable ("DXVK_LOG_LEVEL");
            update_presets ();
            variables_changed ();
        }

        private void update_presets () {
            var available = new Gee.ArrayList<LaunchOptionMetadata> ();
            if (runner_kind == Models.CompatibilityToolRuntimeKind.WINE ||
                runner_kind == Models.CompatibilityToolRuntimeKind.PROTON) {
                if (dxvk_log != null && !contains_variable (dxvk_log.semantics.environment_key))
                    available.add (dxvk_log);
            }
            if (runner_kind == Models.CompatibilityToolRuntimeKind.PROTON && proton_log != null &&
                !contains_variable (proton_log.semantics.environment_key))
                available.add (proton_log);
            preset_picker.visible = !available.is_empty;
            if (available.size == presets.size && available.all_match ((option) => option in presets))
                return;
            presets = available;
            var model = new Gtk.StringList ({ _("Choose a preset") });
            foreach (var preset in presets)
                model.append (preset.title);
            preset_picker.model = model;
            preset_picker.selected = 0;
        }

        private void add_preset () {
            if (preset_picker.selected == 0 || preset_picker.selected > presets.size)
                return;
            var preset = presets[(int) preset_picker.selected - 1];
            var sample = preset.raw_tokens[0];
            var value = sample.substring (sample.index_of_char ('=') + 1);
            var row = append_variable (preset.semantics.environment_key, value);
            refresh ();
            row.variable_value.grab_focus ();
        }
    }
}
