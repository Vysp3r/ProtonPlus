namespace ProtonPlus.Models.Tools {
    public class Basic : Tool {
        // Basic owns tool identity, local variant configuration, and naming;
        // ReleaseCatalog owns all remote browsing state and source access.
        internal string endpoint { get; set; }
        internal string directory_name_format { get; set; }
        public string tag { get; set; }
        public bool is_github_actions_source { get; private set; default = false; }

        public const int RELEASE_PAGE_SIZE = ReleaseCatalog.RELEASE_PAGE_SIZE;

        protected Basic (Group group) {
            Object (group: group);
        }

        public Basic.with_catalog (
            ProtonPlus.Models.Providers.ProviderDefinition definition,
            ProtonPlus.Providers.Sources.ReleaseSource release_source,
            Group group,
            string directory_name_format
        ) {
            Object (group: group);
            this.endpoint = definition.endpoint;
            this.directory_name_format = directory_name_format;
            this.title = definition.title;
            this.description = Utils.safe_translate (definition.description);
            this.tag = definition.tag;
            this.legacy = definition.legacy;
            this.sort_priority = definition.sort_priority;
            this.is_github_actions_source =
                definition.source_type == ProtonPlus.Models.Providers.SourceType.GITHUB_ACTIONS;
            this.set_identity (definition.provider_id, definition.source_id);
            this.initialize_release_catalog (new ReleaseCatalog (id, title, definition, release_source));

            this.variants = new Gee.LinkedList<Variant> ();
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

        public virtual string get_directory_name (string release_name) {
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
