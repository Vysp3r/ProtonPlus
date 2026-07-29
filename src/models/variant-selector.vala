namespace ProtonPlus.Models {
    /// The outcome of resolving a provider release asset for installation.
    /// Keeping the matching variant separate from the usable variant lets
    /// callers distinguish a stale explicit selection from an incompatible
    /// one without duplicating compatibility rules outside model code.
    public class InstallationVariantResolution : Object {
        public Variant? variant { get; private set; default = null; }
        public Variant? matching_variant { get; private set; default = null; }
        public bool has_explicit_selection { get; private set; default = false; }

        public InstallationVariantResolution (
            Variant? variant,
            Variant? matching_variant,
            bool has_explicit_selection
        ) {
            this.variant = variant;
            this.matching_variant = matching_variant;
            this.has_explicit_selection = has_explicit_selection;
        }
    }

    /// Builds UI-safe variant projections from catalog data without changing
    /// either the provider definition or release metadata.
    public class VariantSelector : Object {
        public static Gee.LinkedList<Variant> compatible_variants (
            Gee.Iterable<Variant> variants,
            CpuCapabilities capabilities
        ) {
            var compatible = new Gee.LinkedList<Variant> ();
            foreach (var variant in variants) {
                if (variant.is_compatible_with (capabilities))
                    compatible.add (variant);
            }
            return compatible;
        }

        public static bool has_compatible_variants (
            Gee.Iterable<Variant> variants,
            CpuCapabilities capabilities
        ) {
            foreach (var variant in variants) {
                if (variant.is_compatible_with (capabilities))
                    return true;
            }
            return false;
        }

        // The saved value deliberately remains the user-visible variant name:
        // it is an established settings contract, not a stable-ID migration.
        public static Variant? select_variant (
            Gee.Iterable<Variant> variants,
            CpuCapabilities capabilities,
            string saved_variant_name = ""
        ) {
            var compatible = compatible_variants (variants, capabilities);
            if (saved_variant_name != "") {
                foreach (var variant in compatible) {
                    if (variant.name == saved_variant_name)
                        return variant;
                }
            }

            foreach (var variant in compatible) {
                if (variant.is_default)
                    return variant;
            }

            return compatible.size > 0 ? compatible[0] : null;
        }

        public static bool should_show_dropdown (Gee.Collection<Variant> displayed_variants) {
            return displayed_variants.size >= 2;
        }

        public static Variant? variant_at_display_index (
            Gee.List<Variant> displayed_variants,
            int index
        ) {
            return index >= 0 && index < displayed_variants.size ? displayed_variants[index] : null;
        }

        // Versioned rows require the chosen asset exactly. Latest rows may use
        // a compatible release default when that chosen asset is unavailable.
        public static Variant? resolve_release_variant (
            Release release,
            Variant? selected_variant,
            CpuCapabilities capabilities,
            bool allow_compatible_default_fallback = false
        ) {
            if (selected_variant == null)
                return null;

            var matching = find_matching_release_variant (release, selected_variant);
            if (matching != null && has_download_url (matching) &&
                matching.is_compatible_with (capabilities))
                return matching;

            if (!allow_compatible_default_fallback)
                return null;

            foreach (var variant in release.variants) {
                if (variant.is_default && has_download_url (variant) &&
                    variant.is_compatible_with (capabilities))
                    return variant;
            }
            return null;
        }

        /// Resolves the only release asset a provider install may use.  A
        /// requested stable ID wins over a legacy name, while a request that
        /// cannot be honoured never falls back to another release variant.
        public static InstallationVariantResolution resolve_installation_variant (
            Release release,
            string? selected_variant_id,
            string? selected_variant_name,
            CpuCapabilities capabilities
        ) {
            var has_id = selected_variant_id != null && selected_variant_id != "";
            var has_name = selected_variant_name != null && selected_variant_name != "";
            var explicit_selection = has_id || has_name;
            Variant? matching = null;

            if (has_id)
                matching = find_release_variant_by_id (release, (!) selected_variant_id);
            if (matching == null && has_name)
                matching = find_release_variant_by_name (release, (!) selected_variant_name);

            if (explicit_selection) {
                if (matching != null && has_download_url (matching) &&
                    matching.is_compatible_with (capabilities))
                    return new InstallationVariantResolution (matching, matching, true);
                return new InstallationVariantResolution (null, matching, true);
            }

            foreach (var variant in release.variants) {
                if (variant.is_default && has_download_url (variant) &&
                    variant.is_compatible_with (capabilities))
                    return new InstallationVariantResolution (variant, null, false);
            }
            foreach (var variant in release.variants) {
                if (has_download_url (variant) && variant.is_compatible_with (capabilities))
                    return new InstallationVariantResolution (variant, null, false);
            }
            return new InstallationVariantResolution (null, null, false);
        }

        private static Variant? find_matching_release_variant (Release release, Variant selected_variant) {
            var by_id = find_release_variant_by_id (release, selected_variant.id);
            return by_id ?? find_release_variant_by_name (release, selected_variant.name);
        }

        private static Variant? find_release_variant_by_id (Release release, string id) {
            foreach (var variant in release.variants) {
                if (variant.id == id)
                    return variant;
            }
            return null;
        }

        private static Variant? find_release_variant_by_name (Release release, string name) {
            foreach (var variant in release.variants) {
                if (variant.name == name)
                    return variant;
            }
            return null;
        }

        private static bool has_download_url (Variant? variant) {
            return variant != null && variant.download_url != null && variant.download_url != "";
        }
    }
}
