namespace ProtonPlus.Providers.Sources {
    using Gee;

    // Shared catalog policies stay independent of individual source adapters.
    public class CatalogReleaseBuilder : Object {
        public static bool is_eligible (
            Models.Providers.ProviderDefinition definition,
            string release_title
        ) {
            if (definition.asset_filters.length > 0) {
                foreach (var filter in definition.asset_filters) {
                    if (!release_title.contains (filter))
                        return false;
                }
                return true;
            }

            foreach (var exclusion in definition.asset_exclusions) {
                if (release_title.contains (exclusion))
                    return false;
            }

            return true;
        }

        public static LinkedList<Models.Variant> create_variants (
            Models.Providers.ProviderDefinition definition,
            string release_name,
            string tag_name,
            LinkedList<Models.Assets.Asset> assets,
            string? fallback_download_url = null
        ) {
            var variants = new LinkedList<Models.Variant> ();

            foreach (var definition_variant in definition.get_variants ()) {
                string? download_url = null;
                Models.Assets.Asset? selected_asset = null;
                var expected_name = render_asset_name (definition_variant, definition.title, release_name, tag_name);

                foreach (var asset in assets) {
                    if (variant_matches_asset (expected_name, asset.name)) {
                        download_url = asset.download_url;
                        selected_asset = asset;
                        break;
                    }
                }

                if (download_url == null && definition_variant.is_default) {
                    download_url = fallback_download_url;
                    foreach (var asset in assets) {
                        if (asset.download_url == fallback_download_url) {
                            selected_asset = asset;
                            break;
                        }
                    }
                }

                variants.add (new Models.Variant (
                    definition_variant.id,
                    definition_variant.name,
                    definition_variant.format,
                    definition_variant.is_default,
                    download_url,
                    definition_variant.compatibility,
                    selected_asset
                ));
            }

            return variants;
        }

        public static Models.Assets.Asset? select_default_asset (
            LinkedList<Models.Assets.Asset> assets,
            LinkedList<Models.Variant> variants
        ) {
            var first_asset = assets.first ();
            if (first_asset == null)
                return null;

            foreach (var variant in variants) {
                if (!variant.is_default || variant.download_url == null || variant.download_url == "")
                    continue;

                foreach (var asset in assets) {
                    if (asset.download_url == variant.download_url)
                        return asset;
                }
            }

            return first_asset;
        }

        public static string render_asset_name (
            Models.Providers.VariantDefinition variant,
            string title,
            string release_name,
            string tag_name
        ) {
            return Models.Providers.ProviderTemplate.render (variant.format, title, release_name, tag_name);
        }

        private static bool variant_matches_asset (string expected_asset_name, string asset_name) {
            if (asset_name == expected_asset_name)
                return true;

            return Utils.ArchiveHelper.strip_archive_extension (asset_name) == expected_asset_name;
        }
    }
}
