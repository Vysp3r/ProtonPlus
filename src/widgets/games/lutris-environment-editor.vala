namespace ProtonPlus.Widgets.Games {
    using LaunchOptions;

    internal class LutrisEnvironmentRow : Adw.PreferencesRow {
        public signal void changed ();
        public signal void remove_requested (LutrisEnvironmentRow row);

        public Gtk.Entry variable_name { get; private set; }
        public Gtk.Entry variable_value { get; private set; }
        private Gtk.Label overlap_note = new Gtk.Label (null) {
            xalign = 0, wrap = true, visible = false, css_classes = { "dim-label" }
        };

        public LutrisEnvironmentRow (string key, string value) {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                margin_start = 12, margin_end = 12, margin_top = 6, margin_bottom = 6
            };
            var fields = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
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
            content.append (fields);
            content.append (overlap_note);
            child = content;
            activatable = false;
            selectable = false;
            variable_name.changed.connect (() => changed ());
            variable_value.changed.connect (() => changed ());
        }

        public void set_overlap_note (string? note) {
            overlap_note.label = note ?? "";
            overlap_note.visible = note != null;
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

        private Gtk.Button add_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
            css_classes = { "flat" }, valign = Gtk.Align.CENTER,
            tooltip_text = _("Add variable")
        };
        private Gtk.Button browse_button = new Gtk.Button.from_icon_name ("edit-find-symbolic") {
            css_classes = { "flat" }, valign = Gtk.Align.CENTER,
            tooltip_text = _("Browse launch options"), sensitive = false
        };
        private Adw.ActionRow dxvk_hint = new Adw.ActionRow () {
            title = _("DXVK log level"),
            subtitle = _("In Lutris, set Output debugging info to Inherit from environment to use this value."),
            visible = false
        };
        private Adw.ActionRow inheritance_unavailable = new Adw.ActionRow () {
            title = _("Some inherited values could not be read."),
            visible = false
        };
        private Gee.ArrayList<LutrisEnvironmentRow> rows = new Gee.ArrayList<LutrisEnvironmentRow> ();
        private Gee.ArrayList<Adw.ActionRow> inherited_rows = new Gee.ArrayList<Adw.ActionRow> ();
        private Gee.HashSet<string> unknown_inheritance = new Gee.HashSet<string> ();
        private LaunchCommandCapabilityContext? browser_context;
        private Models.CompatibilityToolRuntimeKind runner_kind;
        private bool dxvk_enabled;
        private uint load_generation;
        public string? validation_error { get; private set; }
        public bool can_clear { get { return visible && !rows.is_empty; } }

        public LutrisEnvironmentEditor () {
            Object (title: _("Environment variables"), subtitle: _("Removing an override restores any inherited value."));
            add_row (dxvk_hint);
            add_row (inheritance_unavailable);
            browse_button.update_property (Gtk.AccessibleProperty.LABEL, browse_button.tooltip_text, -1);
            browse_button.clicked.connect (browse);
            add_suffix (browse_button);
            add_button.update_property (Gtk.AccessibleProperty.LABEL, add_button.tooltip_text, -1);
            add_button.clicked.connect (() => {
                var row = append_variable ("", "");
                expanded = true;
                refresh ();
                row.variable_name.grab_focus ();
            });
            add_suffix (add_button);
        }

        public void load (Services.LutrisGameOptions options, bool preserve_expansion) {
            load_generation++;
            remove_variables ();
            foreach (var row in inherited_rows)
                remove (row);
            inherited_rows.clear ();
            unknown_inheritance.clear ();
            var source = options.environment;
            visible = source != null;
            if (!preserve_expansion)
                expanded = false;
            if (source != null && source != "") {
                foreach (var line in source.split ("\n")) {
                    var separator = line.index_of_char ('=');
                    var key = line.substring (0, separator);
                    append_variable (key, line.substring (separator + 1));
                    var inherited = options.get_inherited_environment (key);
                    if (inherited != null)
                        append_inherited_row (key, inherited);
                    else if (!options.environment_inheritance_complete)
                        unknown_inheritance.add (key);
                }
            }
            refresh ();
        }

        private void append_inherited_row (string key, Services.LutrisInheritedEnvironmentValue inherited) {
            var value = inherited.value == "" ? _("Empty value") : inherited.value;
            var row = new Adw.ActionRow () {
                title = key,
                subtitle = inherited.from_wine_runner ? _("Inherited from the Wine runner\n%s").printf (value) :
                    _("Inherited from Lutris global settings\n%s").printf (value),
                subtitle_lines = 2,
                tooltip_text = value,
                use_markup = false,
                selectable = false,
                visible = false
            };
            inherited_rows.add (row);
            add_row (row);
        }

        public void set_runner_context (Models.CompatibilityToolRuntimeKind kind, bool use_dxvk) {
            runner_kind = kind;
            dxvk_enabled = use_dxvk;
            foreach (var row in rows)
                row.set_overlap_note (overlap_note_for (row.variable_name.text));
        }

        private string? overlap_note_for (string key) {
            if (key == "MANGOHUD")
                return _("Setting this to 1 can enable MangoHud for Vulkan even when the MangoHud switch is off.");
            var proton = runner_kind == Models.CompatibilityToolRuntimeKind.PROTON;
            if (!proton && runner_kind != Models.CompatibilityToolRuntimeKind.WINE)
                return null;
            switch (key) {
                case "WINEESYNC":
                    return _("This value takes precedence over the Lutris Esync setting for Wine.");
                case "WINEFSYNC":
                    return _("This value takes precedence over the Lutris Fsync setting for Wine.");
                case "PROTON_NO_ESYNC":
                    return proton ? _("This value takes precedence over the Lutris Esync setting for Proton.") : null;
                case "PROTON_NO_FSYNC":
                    return proton ? _("This value takes precedence over the Lutris Fsync setting for Proton.") : null;
                case "PROTON_USE_WINED3D":
                    if (proton)
                        return dxvk_enabled ?
                            _("Setting this to 1 makes Proton use WineD3D. Lutris also sets it to 1 when Vulkan is unavailable.") :
                            _("Lutris sets this to 1 when DXVK is off.");
                    return null;
                case "PROTON_DXVK_D3D8":
                    return proton ? _("This value controls Proton’s DXVK support for Direct3D 8.") : null;
                default:
                    return null;
            }
        }

        public void set_browser_context (LaunchCommandCapabilityContext? context) {
            browser_context = context;
            browse_button.sensitive = context != null;
        }

        private void browse () {
            if (browser_context == null || !get_mapped ())
                return;
            var generation = load_generation;
            var existing_keys = new Gee.HashSet<string> ();
            foreach (var row in rows)
                existing_keys.add (row.variable_name.text);
            var dialog = new LutrisEnvironmentBrowser (browser_context, existing_keys);
            weak LutrisEnvironmentBrowser current = dialog;
            dialog.closed.connect (() => {
                var key = current.selected_key;
                var value = current.selected_value;
                if (key != null) {
                    Idle.add (() => {
                        if (load_generation == generation && get_mapped ())
                            select_variable (key, value);
                        return Source.REMOVE;
                    });
                }
            });
            Window.present_dialog_for_controller (dialog, this);
            dialog.focus_search ();
        }

        private void select_variable (string key, string value) {
            var row = rows.first_match ((candidate) => candidate.variable_name.text == key);
            if (row == null) {
                row = append_variable (key, value);
                refresh ();
            }
            expanded = true;
            row.variable_value.grab_focus ();
        }

        public void clear_variables () {
            remove_variables ();
            refresh ();
            if (!inherited_rows.is_empty || inheritance_unavailable.visible)
                expanded = true;
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
                add_button.grab_focus ();
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
                row.set_overlap_note (overlap_note_for (key));
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
            foreach (var row in inherited_rows)
                row.visible = !names.contains (row.title);
            inheritance_unavailable.visible = unknown_inheritance.any_match ((key) => !names.contains (key));
            variables_changed ();
        }
    }
}
