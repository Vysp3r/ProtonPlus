namespace ProtonPlus.Models.Tools {
    public class Basic : Tool {
        // Basic owns tool identity, local variant configuration, and naming;
        // ReleaseCatalog owns all remote browsing state and source access.
        private ProtonPlus.Models.Providers.ProviderDefinition? definition;
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
            this.definition = definition;
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

        public virtual Gee.LinkedList<Variant> create_release_variants (
            string release_name,
            string tag_name,
            Gee.LinkedList<ProtonPlus.Models.Assets.IAsset> assets,
            string? fallback_download_url = null
        ) {
            if (definition == null)
                return new Gee.LinkedList<Variant> ();

            var catalog_assets = new Gee.LinkedList<ProtonPlus.Models.Assets.Asset> ();
            foreach (var asset in assets)
                catalog_assets.add (new ProtonPlus.Models.Assets.Asset (asset.name, asset.download_url));

            return ProtonPlus.Providers.Sources.CatalogReleaseBuilder.create_variants (
                definition, release_name, tag_name, catalog_assets, fallback_download_url
            );
        }

        public string? get_default_variant_download_url (Gee.LinkedList<Variant> release_variants, string? fallback_download_url = null) {
            return ProtonPlus.Providers.Sources.CatalogReleaseBuilder.get_default_variant_download_url (
                release_variants, fallback_download_url
            );
        }

        public virtual void update_variant_download_url (string release_name) {
            foreach (var variant in this.variants) {
                var url = new StringBuilder (variant.format);
                url.replace ("$title", title);
                url.replace ("$release_name", release_name);
                variant.download_url = url.str;
            }
        }

    }
}
