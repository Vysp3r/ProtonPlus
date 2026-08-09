namespace AppTests.VariantSelectorTest {
    using GLib;
    using Gee;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    public void register_tests () {
        Test.add_func ("/variant-selector/host-projections", test_host_projections);
        Test.add_func ("/variant-selector/unspecified-and-unknown-host", test_unspecified_and_unknown_host);
        Test.add_func ("/variant-selector/selection-and-display-index", test_selection_and_display_index);
        Test.add_func ("/variant-selector/proton-cachyos-levels", test_proton_cachyos_levels);
        Test.add_func ("/variant-selector/release-assets", test_release_assets);
        Test.add_func ("/variant-selector/installation-resolution", test_installation_resolution);
    }

    private ProtonPlus.Models.Variant variant (string id, string name, bool is_default, VariantCompatibility compatibility) {
        return new ProtonPlus.Models.Variant (id, name, "$release_name", is_default, null, compatibility);
    }

    private LinkedList<ProtonPlus.Models.Variant> variants () {
        var values = new LinkedList<ProtonPlus.Models.Variant> ();
        values.add (variant ("x86-64", "x86_64", true,
            VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)));
        values.add (variant ("x86-64-v2", "x86_64_v2", false,
            VariantCompatibility.for_x86_64_level (X86_64Level.V2)));
        values.add (variant ("x86-64-v3", "x86_64_v3", false,
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)));
        values.add (variant ("x86-64-v4", "x86_64_v4", false,
            VariantCompatibility.for_x86_64_level (X86_64Level.V4)));
        values.add (variant ("aarch64", "aarch64", false,
            VariantCompatibility.for_architecture (CpuArchitecture.AARCH64)));
        return values;
    }

    private void assert_projection (CpuCapabilities host, string[] expected) {
        var projected = VariantSelector.compatible_variants (variants (), host);
        assert (projected.size == expected.length);
        for (var index = 0; index < expected.length; index++)
            assert (projected[index].name == expected[index]);
    }

    private void test_host_projections () {
        assert_projection (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.BASELINE), { "x86_64" });
        assert_projection (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2), { "x86_64", "x86_64_v2" });
        assert_projection (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V3), { "x86_64", "x86_64_v2", "x86_64_v3" });
        assert_projection (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V4), { "x86_64", "x86_64_v2", "x86_64_v3", "x86_64_v4" });
        assert_projection (new CpuCapabilities (CpuArchitecture.AARCH64), {
            "x86_64", "x86_64_v2", "x86_64_v3", "x86_64_v4", "aarch64"
        });
    }

    private void test_unspecified_and_unknown_host () {
        var values = variants ();
        values.add (variant ("plain", "plain", false, VariantCompatibility.unspecified ()));
        values.add (variant ("independent", "independent", false, VariantCompatibility.independent ()));
        var unknown = VariantSelector.compatible_variants (values, new CpuCapabilities (CpuArchitecture.UNKNOWN));
        assert (unknown.size == values.size);
        var aarch64 = VariantSelector.compatible_variants (values, new CpuCapabilities (CpuArchitecture.AARCH64));
        assert (aarch64.size == values.size);
        assert (aarch64[4].name == "aarch64");
        assert (aarch64[5].name == "plain");
        assert (aarch64[6].name == "independent");
    }

    private void test_selection_and_display_index () {
        var host = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        var projected = VariantSelector.compatible_variants (variants (), host);
        assert (VariantSelector.select_variant (variants (), host, "x86_64_v2").name == "x86_64_v2");
        assert (VariantSelector.select_variant (variants (), host, "x86_64_v3").name == "x86_64");
        assert (VariantSelector.select_variant (variants (), host).name == "x86_64");
        assert (VariantSelector.should_show_dropdown (projected));
        assert (VariantSelector.variant_at_display_index (projected, 1).name == "x86_64_v2");
        assert (VariantSelector.variant_at_display_index (projected, 2) == null);

        var baseline = VariantSelector.compatible_variants (
            variants (), new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.BASELINE)
        );
        assert (baseline.size == 1);
        assert (VariantSelector.select_variant (baseline, host).name == "x86_64");
        assert (!VariantSelector.should_show_dropdown (baseline));

        var empty = VariantSelector.compatible_variants (variants (), new CpuCapabilities (CpuArchitecture.X86_32));
        assert (empty.size == 0);
        assert (!VariantSelector.has_compatible_variants (
            variants (), new CpuCapabilities (CpuArchitecture.X86_32)
        ));
        assert (VariantSelector.select_variant (variants (), new CpuCapabilities (CpuArchitecture.X86_32)) == null);
        assert (!VariantSelector.should_show_dropdown (empty));

        var aarch64 = new CpuCapabilities (CpuArchitecture.AARCH64);
        assert (VariantSelector.select_variant (variants (), aarch64).name == "aarch64");
        assert (VariantSelector.select_variant (variants (), aarch64, "x86_64").name == "x86_64");
    }

    private LinkedList<ProtonPlus.Models.Variant> provider_variants (ProviderDefinition definition) {
        var values = new LinkedList<ProtonPlus.Models.Variant> ();
        foreach (var configured in definition.get_variants ()) {
            values.add (new ProtonPlus.Models.Variant (
                configured.id, configured.name, configured.format, configured.is_default,
                null, configured.compatibility
            ));
        }
        return values;
    }

    private void test_proton_cachyos_levels () {
        var definition = new ProviderRegistry ().get_by_id ("proton-cachyos");
        assert (definition != null);
        var values = provider_variants ((!) definition);

        var v3 = VariantSelector.compatible_variants (
            values, new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V3)
        );
        assert (v3.size == 2);
        assert (v3[0].name == "x86_64");
        assert (v3[1].name == "x86_64_v3");
        assert (VariantSelector.select_variant (values,
            new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V3), "x86_64_v3").name == "x86_64_v3");

        var v2 = VariantSelector.compatible_variants (
            values, new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2)
        );
        assert (v2.size == 1);
        assert (v2[0].name == "x86_64");
        assert (VariantSelector.select_variant (values,
            new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2), "x86_64_v3").name == "x86_64");
    }

    private Release release_with_assets (ProtonPlus.Models.Variant[] values) {
        var release = new Release ("v1", "", "", new Assets.Asset ("fallback.tar.gz", "https://example.test/fallback.tar.gz"), "");
        foreach (var value in values)
            release.variants.add (value);
        return release;
    }

    private void test_release_assets () {
        var host = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        var selected = variant ("v2", "x86_64_v2", false,
            VariantCompatibility.for_x86_64_level (X86_64Level.V2));
        var incompatible_default = new ProtonPlus.Models.Variant ("v3", "x86_64_v3", "$release_name", true,
            "https://example.test/v3.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.V3));
        var release = release_with_assets ({ incompatible_default });
        assert (VariantSelector.resolve_release_variant (release, selected, host) == null);
        assert (VariantSelector.resolve_release_variant (release, selected, host, true) == null);

        var compatible_default = new ProtonPlus.Models.Variant ("base", "x86_64", "$release_name", true,
            "https://example.test/base.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE));
        release = release_with_assets ({ compatible_default });
        assert (VariantSelector.resolve_release_variant (release, selected, host) == null);
        assert (VariantSelector.resolve_release_variant (release, selected, host, true) == compatible_default);

        var selected_asset = new ProtonPlus.Models.Variant ("v2", "renamed-v2", "$release_name", false,
            "https://example.test/v2.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.V2));
        release = release_with_assets ({ selected_asset, incompatible_default });
        assert (VariantSelector.resolve_release_variant (release, selected, host) == selected_asset);

        var selected_incompatible = variant ("v3", "x86_64_v3", false,
            VariantCompatibility.for_x86_64_level (X86_64Level.V3));
        release = release_with_assets ({ incompatible_default });
        assert (VariantSelector.resolve_release_variant (release, selected_incompatible, host) == null);
    }

    private void test_installation_resolution () {
        var v2 = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        var release = release_with_assets ({
            new ProtonPlus.Models.Variant ("base", "Baseline", "", true,
                "https://example.test/base.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
            new ProtonPlus.Models.Variant ("v3", "Optimized", "", false,
                "https://example.test/v3.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.V3))
        });

        var selected_base = VariantSelector.resolve_installation_variant (release, "base", "", v2);
        assert (selected_base.variant != null && selected_base.variant.id == "base");
        assert (selected_base.has_explicit_selection);

        var selected_v3 = VariantSelector.resolve_installation_variant (release, "v3", "", v2);
        assert (selected_v3.variant == null);
        assert (selected_v3.matching_variant != null && selected_v3.matching_variant.id == "v3");

        var id_wins = VariantSelector.resolve_installation_variant (release, "base", "Optimized", v2);
        assert (id_wins.variant != null && id_wins.variant.id == "base");
        var legacy_name = VariantSelector.resolve_installation_variant (release, "", "Baseline", v2);
        assert (legacy_name.variant != null && legacy_name.variant.id == "base");

        var missing = VariantSelector.resolve_installation_variant (release, "missing", "", v2);
        assert (missing.variant == null && missing.matching_variant == null);
        var default_variant = VariantSelector.resolve_installation_variant (release, "", "", v2);
        assert (default_variant.variant != null && default_variant.variant.id == "base");

        var first_compatible = release_with_assets ({
            new ProtonPlus.Models.Variant ("v3", "Optimized", "", true,
                "https://example.test/v3.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.V3)),
            new ProtonPlus.Models.Variant ("base", "Baseline", "", false,
                "https://example.test/base.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE))
        });
        var fallback = VariantSelector.resolve_installation_variant (first_compatible, "", "", v2);
        assert (fallback.variant != null && fallback.variant.id == "base");

        var none = release_with_assets ({
            new ProtonPlus.Models.Variant ("v3", "Optimized", "", true,
                "https://example.test/v3.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.V3))
        });
        assert (VariantSelector.resolve_installation_variant (none, "", "", v2).variant == null);

        var aarch64 = new CpuCapabilities (CpuArchitecture.AARCH64);
        assert (VariantSelector.resolve_installation_variant (release, "base", "", aarch64).variant != null);
        var native_default = release_with_assets ({
            new ProtonPlus.Models.Variant ("base", "Baseline", "", true,
                "https://example.test/base.tar.gz", VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)),
            new ProtonPlus.Models.Variant ("arm", "AArch64", "", false,
                "https://example.test/arm.tar.gz", VariantCompatibility.for_architecture (CpuArchitecture.AARCH64))
        });
        var aarch64_default = VariantSelector.resolve_installation_variant (native_default, "", "", aarch64);
        assert (aarch64_default.variant != null && aarch64_default.variant.id == "arm");
        var unknown = new CpuCapabilities (CpuArchitecture.UNKNOWN);
        assert (VariantSelector.resolve_installation_variant (release, "v3", "", unknown).variant != null);
        var unrestricted = release_with_assets ({
            new ProtonPlus.Models.Variant ("plain", "Plain", "", true,
                "https://example.test/plain.tar.gz", VariantCompatibility.unspecified ())
        });
        assert (VariantSelector.resolve_installation_variant (unrestricted, "plain", "", aarch64).variant != null);
    }
}
