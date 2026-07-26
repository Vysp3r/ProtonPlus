namespace ProtonPlus.Models.Providers {
    using Gee;

    // Validation diagnostics describe static application configuration and are
    // deliberately not user-facing strings.
    public class ProviderDefinitionValidationResult : Object {
        public string provider_id { get; private set; }
        private string[] messages;

        public ProviderDefinitionValidationResult (string provider_id, string[] messages) {
            this.provider_id = provider_id;
            this.messages = copy_messages (messages);
        }

        public string[] get_messages () {
            return copy_messages (messages);
        }

        private static string[] copy_messages (string[] values) {
            var copied = new string[values.length];
            for (var index = 0; index < values.length; index++)
                copied[index] = values[index];
            return copied;
        }
    }

    // The registry indexes immutable built-in definitions. It deliberately
    // contains no launcher policy, filesystem paths, or source construction.
    public class ProviderRegistry : Object {
        private HashMap<string, ProviderDefinition> definitions_by_id =
            new HashMap<string, ProviderDefinition> ();
        private HashMap<Category, ArrayList<ProviderDefinition>> definitions_by_category =
            new HashMap<Category, ArrayList<ProviderDefinition>> ();
        private ArrayList<ProviderDefinition> all_definitions = new ArrayList<ProviderDefinition> ();
        private ArrayList<ProviderDefinitionValidationResult> validation_results =
            new ArrayList<ProviderDefinitionValidationResult> ();

        public bool is_valid {
            get { return validation_results.size == 0; }
        }

        public ProviderRegistry (ProviderDefinition[]? definitions = null) {
            initialize_categories ();
            var configured_definitions = definitions ?? BuiltInProviderDefinitions.create_all ();
            foreach (var definition in configured_definitions)
                add (definition);
            validate ();
        }

        public ProviderDefinition? get_by_id (string provider_id) {
            return definitions_by_id.get (provider_id);
        }

        public new ProviderDefinition[] get (Category category) {
            var definitions = definitions_by_category.get (category);
            if (definitions == null)
                return {};
            return copy_definitions (definitions);
        }

        public ProviderDefinition[] get_all () {
            var copied = new ArrayList<ProviderDefinition> ();
            foreach (var category in new Category[] {
                Category.DXVK, Category.VKD3D, Category.PROTON, Category.WINE
            }) {
                foreach (var definition in get (category))
                    copied.add (definition);
            }
            return copy_definitions (copied);
        }

        public ProviderDefinitionValidationResult[] get_validation_results () {
            return copy_validation_results (validation_results);
        }

        private void initialize_categories () {
            foreach (var category in new Category[] {
                Category.DXVK, Category.VKD3D, Category.PROTON, Category.WINE
            }) {
                definitions_by_category.set (category, new ArrayList<ProviderDefinition> ());
            }
        }

        private void add (ProviderDefinition definition) {
            all_definitions.add (definition);

            var category_definitions = definitions_by_category.get (definition.category);
            if (category_definitions != null)
                category_definitions.add (definition);

            // Keep the first definition addressable for diagnostics and callers
            // of custom fixture registries; duplicates make the registry invalid.
            if (!definitions_by_id.has_key (definition.provider_id))
                definitions_by_id.set (definition.provider_id, definition);
        }

        private void validate () {
            var seen_provider_ids = new HashSet<string> ();
            foreach (var definition in all_definitions) {
                var messages = new ArrayList<string> ();

                if (definition.provider_id == "")
                    messages.add ("provider ID is empty");
                if (!seen_provider_ids.add (definition.provider_id))
                    messages.add ("provider ID is duplicated");

                if (definition.title == "")
                    messages.add ("title is empty");
                if (definition.endpoint == "")
                    messages.add ("endpoint is empty");
                if (definition.source_id == "")
                    messages.add ("source type has no supported source mapping");

                validate_variants (definition, messages);
                validate_install_layouts (definition, messages);

                if (definition.source_type == SourceType.GITHUB_ACTIONS && definition.url_template == "")
                    messages.add ("GitHub Actions source requires a URL template");
                if (definition.source_type != SourceType.GITHUB_ACTIONS && definition.url_template != "")
                    messages.add ("only GitHub Actions sources may have a URL template");

                if (messages.size > 0) {
                    validation_results.add (new ProviderDefinitionValidationResult (
                        definition.provider_id, copy_messages (messages)
                    ));
                }
            }
        }

        private static void validate_variants (ProviderDefinition definition, ArrayList<string> messages) {
            var variants = definition.get_variants ();
            if (variants.length == 0) {
                messages.add ("variants are missing");
                return;
            }

            var variant_ids = new HashSet<string> ();
            var default_count = 0;
            foreach (var variant in variants) {
                if (variant.id == "")
                    messages.add ("variant ID is empty");
                if (!variant_ids.add (variant.id))
                    messages.add ("variant ID is duplicated: %s".printf (variant.id));
                if (variant.name == "")
                    messages.add ("variant name is empty");
                if (variant.format == "")
                    messages.add ("variant format is empty");
                if (variant.is_default)
                    default_count++;
            }

            if (default_count == 0)
                messages.add ("default variant is missing");
            else if (default_count > 1)
                messages.add ("more than one default variant is configured");
        }

        private static void validate_install_layouts (ProviderDefinition definition, ArrayList<string> messages) {
            var layouts = definition.get_install_layouts ();
            if (layouts.length == 0) {
                messages.add ("install layouts are missing");
                return;
            }

            var launcher_family_ids = new HashSet<string> ();
            var has_default_layout = false;
            foreach (var layout in layouts) {
                if (layout.launcher_family_id == "")
                    messages.add ("launcher family ID is empty");
                if (!launcher_family_ids.add (layout.launcher_family_id))
                    messages.add ("install layout is duplicated for launcher family: %s".printf (layout.launcher_family_id));
                if (layout.launcher_family_id == "default")
                    has_default_layout = true;
            }

            if (!has_default_layout)
                messages.add ("default install layout is missing");
        }

        private static ProviderDefinition[] copy_definitions (Collection<ProviderDefinition> values) {
            var copied = new ProviderDefinition[values.size];
            var index = 0;
            foreach (var value in values)
                copied[index++] = value;
            return copied;
        }

        private static ProviderDefinitionValidationResult[] copy_validation_results (
            Collection<ProviderDefinitionValidationResult> values
        ) {
            var copied = new ProviderDefinitionValidationResult[values.size];
            var index = 0;
            foreach (var value in values)
                copied[index++] = value;
            return copied;
        }

        private static string[] copy_messages (Collection<string> values) {
            var copied = new string[values.size];
            var index = 0;
            foreach (var value in values)
                copied[index++] = value;
            return copied;
        }
    }
}
