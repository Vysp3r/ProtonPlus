namespace ProtonPlus.Widgets.Games {
    using LaunchOptions;

    internal class LutrisEnvironmentBrowser : Adw.Dialog {
        private Gtk.SearchEntry search = new Gtk.SearchEntry () { placeholder_text = _("Search launch options") };
        private Gtk.Label no_results = new Gtk.Label (_("No matching launch options.")) {
            css_classes = { "dim-label" }, wrap = true
        };
        private Gee.HashMap<LaunchOptionCategory, Adw.PreferencesGroup> groups =
            new Gee.HashMap<LaunchOptionCategory, Adw.PreferencesGroup> ();
        private Gee.HashMap<LaunchOptionMetadata, Adw.ActionRow> choices =
            new Gee.HashMap<LaunchOptionMetadata, Adw.ActionRow> ();

        public string? selected_key { get; private set; }
        public string selected_value { get; private set; default = ""; }

        public LutrisEnvironmentBrowser (LaunchCommandCapabilityContext context) {
            Object (title: _("Browse launch options"), content_width: 520, content_height: 550);

            Utils.TextInputMetadataPolicy.apply (search, Utils.TextInputFieldKind.SEARCH);
            search.margin_start = 12;
            search.margin_end = 12;
            search.margin_top = 12;
            var sections = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_start = 12, margin_end = 12, margin_top = 12, margin_bottom = 12
            };
            var body = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            body.append (search);
            body.append (new Gtk.ScrolledWindow () {
                child = sections, hscrollbar_policy = Gtk.PolicyType.NEVER, vexpand = true
            });
            var toolbar = new Adw.ToolbarView () { content = body };
            toolbar.add_top_bar (new Adw.HeaderBar ());
            child = toolbar;

            var catalog = new LaunchOptionCatalog ();
            var resolver = new LaunchOptionCapabilityResolver (catalog);
            foreach (var option in catalog.get_ordered ()) {
                var value = environment_value (option);
                if (value == null || resolver.evaluate (option, context).kind != LaunchOptionEligibilityKind.AVAILABLE)
                    continue;
                var group = groups.get (option.category);
                if (group == null) {
                    group = new Adw.PreferencesGroup () {
                        title = Markup.escape_text (LaunchOptionCatalog.category_title (option.category))
                    };
                    sections.append (group);
                    groups.set (option.category, group);
                }
                var key = option.semantics.environment_key;
                var row = new Adw.ActionRow () {
                    title = option.title, subtitle = key + "\n" + option.description,
                    use_markup = false, activatable = true
                };
                row.add_suffix (new Gtk.Image.from_icon_name ("list-add-symbolic"));
                row.activated.connect (() => {
                    selected_key = key;
                    selected_value = value;
                    close ();
                });
                group.add (row);
                choices.set (option, row);
            }
            sections.append (no_results);
            search.search_changed.connect (filter);
            filter ();
        }

        public void focus_search () {
            search.grab_focus ();
        }

        private void filter () {
            foreach (var group in groups.values)
                group.visible = false;
            var any = false;
            foreach (var entry in choices.entries) {
                var option = entry.key;
                var matches = option.matches_search (search.text) ||
                    option.semantics.environment_key.down ().contains (search.text.strip ().down ());
                entry.value.visible = matches;
                if (matches) {
                    groups[option.category].visible = true;
                    any = true;
                }
            }
            no_results.visible = !any;
        }

        private static string? environment_value (LaunchOptionMetadata option) {
            var semantics = option.semantics;
            if (semantics == null || semantics.kind != LaunchOptionSemanticKind.ENVIRONMENT_ASSIGNMENT ||
                semantics.wrapper_id != "" || semantics.dependencies.length > 0 ||
                semantics.environment_value_prefix != "" ||
                !Services.LutrisConfigurationService.valid_env_name (semantics.environment_key))
                return null;
            var key = semantics.environment_key;
            // Lutris owns these switches. Its Wine runner also assembles DLL overrides.
            if (key in new string[] { "MANGOHUD", "GAMEMODE", "PROTON_NO_ESYNC", "WINEESYNC",
                "PROTON_NO_FSYNC", "WINEFSYNC", "PROTON_USE_WINED3D", "PROTON_DXVK_D3D8", "WINEDLLOVERRIDES",
                "WINE_LARGE_ADDRESS_AWARE" })
                return null;
            // The legacy catalog key differs from VKD3D-Proton's documented VKD3D_DEBUG.
            if (key == "VKD3D_LOG_LEVEL")
                return null;
            if (semantics.emission_mode == LaunchOptionEmissionMode.DYNAMIC_ENVIRONMENT_VALUE)
                return semantics.implicit_value;
            if (semantics.emission_mode != LaunchOptionEmissionMode.FIXED_TOKENS || semantics.fixed_tokens.length != 1)
                return null;
            var tokens = new LaunchOptionShellTokenizer ().tokenize (semantics.fixed_tokens[0]);
            var prefix = key + "=";
            if (tokens.size != 1 || tokens[0].is_opaque || tokens[0].has_unquoted_glob ||
                !tokens[0].value.has_prefix (prefix) || tokens[0].value.contains ("%command%") ||
                tokens[0].value.contains ("\n") || tokens[0].value.contains ("\r"))
                return null;
            return tokens[0].value.substring (prefix.length);
        }
    }
}
