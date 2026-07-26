namespace ProtonPlus.Models.Tools {
    public class ProviderTool : Tool {
        // ProviderTool owns tool identity, local variant configuration, and naming;
        // ReleaseCatalog owns all remote browsing state and source access.
        public ProtonPlus.Models.Providers.ProviderDefinition definition { get; construct; }
        public string endpoint {
            owned get { return definition.endpoint; }
        }
        internal string directory_name_format { get; set; }
        public string tag {
            owned get { return definition.tag; }
        }
        public Gee.LinkedList<Variant> variants { get; private set; default = new Gee.LinkedList<Variant> (); }

        public const int RELEASE_PAGE_SIZE = ReleaseCatalog.RELEASE_PAGE_SIZE;

        public ProviderTool.with_catalog (
            ProtonPlus.Models.Providers.ProviderDefinition definition,
            ProtonPlus.Providers.Sources.ReleaseSource release_source,
            Group group,
            string directory_name_format
        ) {
            Object (group: group, definition: definition);
            this.directory_name_format = directory_name_format;
            this.title = definition.title;
            this.description = Utils.safe_translate (definition.description);
            this.legacy = definition.legacy;
            this.sort_priority = definition.sort_priority;
            this.set_identity (definition.provider_id, definition.source_id);
            this.initialize_release_catalog (new ReleaseCatalog (id, title, definition, release_source));

            foreach (var configured_variant in definition.get_variants ()) {
                this.variants.add (new Variant (
                    configured_variant.id,
                    configured_variant.name,
                    configured_variant.format,
                    configured_variant.is_default,
                    null
                ));
            }
        }

        public string get_directory_name (string release_name) {
            if (release_name.contains ("Latest"))
                return release_name;

            var directory_name = new StringBuilder (directory_name_format);

            directory_name.replace ("$release_name", release_name);
            directory_name.replace ("$title", title);

            if (directory_name.len > 0 && directory_name.str[0] == '_') {
                directory_name.replace ("_", "", 1);
                directory_name.str = directory_name.str.ascii_down ();
            }

            if (directory_name.len > 0 && directory_name.str[0] == '!') {
                directory_name.replace ("!", "", 1);
                var split = directory_name.str.split (":");
                if (split.length >= 3)
                    directory_name.str = split[0].replace (split[1], split[2]);
            }

            if (directory_name.len > 0 && directory_name.str[0] == '&') {
                directory_name.replace ("&", "", 1);
                var split = directory_name.str.split (":");
                if (split.length >= 4)
                    directory_name.str = split[0].contains (split[1]) ? split[2] : split[3];
            }

            return directory_name.str;
        }

    }
}
