namespace AppTests.VariantCompatibilityTest {
    using GLib;
    using Gee;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Models.Tools;
    using ProtonPlus.Providers.Sources;

    public void register_tests () {
        Test.add_func ("/variant-compatibility/unrestricted-and-independent", test_unrestricted_and_independent);
        Test.add_func ("/variant-compatibility/architecture-restrictions", test_architecture_restrictions);
        Test.add_func ("/variant-compatibility/x86-64-levels", test_x86_64_levels);
        Test.add_func ("/variant-compatibility/aarch64-levels", test_aarch64_levels);
        Test.add_func ("/variant-compatibility/defensive-copies-and-propagation", test_defensive_copies_and_propagation);
        Test.add_func ("/variant-compatibility/definition-validation", test_definition_validation);
        Test.add_func ("/variant-compatibility/release-json", test_release_json);
        Test.add_func ("/variant-compatibility/built-in-annotations", test_built_in_annotations);
    }

    private CpuCapabilities host (
        CpuArchitecture architecture,
        X86_64Level x86_64_level = X86_64Level.UNKNOWN,
        Aarch64Level aarch64_level = Aarch64Level.UNKNOWN
    ) {
        return new CpuCapabilities (architecture, x86_64_level, aarch64_level);
    }

    private ProviderDefinition definition (VariantCompatibility? compatibility = null) {
        return new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "compatibility-fixture", "Fixture", "",
            "https://example.test/releases", "https://example.test/source", 1,
            { new VariantDefinition ("default", "default", "$release_name", true, compatibility) },
            { InstallLayout.template ("default", "$release_name") }
        );
    }

    private void test_unrestricted_and_independent () {
        var unspecified = VariantCompatibility.unspecified ();
        assert (!unspecified.is_specified);
        foreach (var architecture in new CpuArchitecture[] {
            CpuArchitecture.X86_32, CpuArchitecture.X86_64, CpuArchitecture.AARCH64, CpuArchitecture.UNKNOWN
        }) {
            assert (unspecified.is_compatible_with (host (architecture, X86_64Level.V4)));
        }

        var independent = VariantCompatibility.independent ();
        assert (independent.is_specified);
        foreach (var architecture in new CpuArchitecture[] {
            CpuArchitecture.X86_32, CpuArchitecture.X86_64, CpuArchitecture.AARCH64, CpuArchitecture.UNKNOWN
        }) {
            assert (independent.is_compatible_with (host (architecture, X86_64Level.V4)));
        }
    }

    private void test_architecture_restrictions () {
        var x86_32 = VariantCompatibility.for_architecture (CpuArchitecture.X86_32);
        var aarch64 = VariantCompatibility.for_architecture (CpuArchitecture.AARCH64);
        var x86_64 = VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE);

        assert (x86_32.is_compatible_with (host (CpuArchitecture.X86_32)));
        assert (!x86_32.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V4)));
        assert (!x86_32.is_compatible_with (host (CpuArchitecture.AARCH64)));
        assert (aarch64.is_compatible_with (host (CpuArchitecture.AARCH64)));
        assert (!aarch64.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V4)));
        assert (x86_64.is_compatible_with (host (CpuArchitecture.AARCH64)));
        assert (x86_64.is_compatible_with (host (CpuArchitecture.UNKNOWN)));
    }

    private void test_x86_64_levels () {
        var baseline = VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE);
        var v2 = VariantCompatibility.for_x86_64_level (X86_64Level.V2);
        var v3 = VariantCompatibility.for_x86_64_level (X86_64Level.V3);
        var v4 = VariantCompatibility.for_x86_64_level (X86_64Level.V4);

        assert (baseline.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.BASELINE)));
        assert (!v2.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.BASELINE)));
        assert (v2.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V2)));
        assert (v3.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V3)));
        assert (baseline.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V3)));
        assert (v2.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V3)));
        assert (!v3.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V2)));
        assert (!v4.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V3)));
        foreach (var requirement in new VariantCompatibility[] { baseline, v2, v3, v4 })
            assert (requirement.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V4)));
        foreach (var requirement in new VariantCompatibility[] { baseline, v2, v3, v4 })
            assert (requirement.is_compatible_with (host (CpuArchitecture.AARCH64)));
    }

    private void test_aarch64_levels () {
        var v8_0 = VariantCompatibility.for_aarch64_level (Aarch64Level.V8_0);
        var v8_1 = VariantCompatibility.for_aarch64_level (Aarch64Level.V8_1);
        var old_arm = host (CpuArchitecture.AARCH64);
        var new_arm = host (
            CpuArchitecture.AARCH64, X86_64Level.UNKNOWN, Aarch64Level.V8_1
        );

        assert (v8_0.is_compatible_with (old_arm));
        assert (!v8_1.is_compatible_with (old_arm));
        assert (v8_0.is_compatible_with (new_arm));
        assert (v8_1.is_compatible_with (new_arm));
        assert (!v8_1.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V4)));

        var x86_64 = VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE);
        assert (x86_64.is_compatible_with (old_arm));
    }

    private void test_defensive_copies_and_propagation () {
        var architectures = new CpuArchitecture[] { CpuArchitecture.X86_64 };
        var compatibility = new VariantCompatibility (architectures, X86_64Level.V3);
        architectures[0] = CpuArchitecture.AARCH64;
        assert (compatibility.get_supported_architectures ()[0] == CpuArchitecture.X86_64);
        var returned_architectures = compatibility.get_supported_architectures ();
        returned_architectures[0] = CpuArchitecture.AARCH64;
        assert (compatibility.get_supported_architectures ()[0] == CpuArchitecture.X86_64);

        var configured = definition (compatibility);
        assert (configured.get_variants ()[0].compatibility.equals (compatibility));
        var copied_variants = configured.get_variants ();
        assert (copied_variants[0].compatibility != compatibility);
        assert (copied_variants[0].compatibility.equals (compatibility));

        var launcher = new Launcher ("Fixture", Launcher.InstallationTypes.SYSTEM, "", {}, "fixture");
        var group = new Group ("Fixture", "", "", launcher, "fixture");
        var layout = configured.get_install_layout ("fixture");
        assert (layout != null);
        var tool = new ProviderTool.with_catalog (configured, new GitHubReleaseSource (), group, (!) layout);
        assert (tool.variants.size == 1);
        assert (tool.variants[0].compatibility.equals (compatibility));

        var variants = CatalogReleaseBuilder.create_variants (
            configured, "v1", "v1", new LinkedList<Assets.Asset> ()
        );
        assert (variants.size == 1);
        assert (variants[0].compatibility.equals (compatibility));
    }

    private bool has_message (ProviderRegistry registry, string expected) {
        foreach (var result in registry.get_validation_results ()) {
            foreach (var message in result.get_messages ()) {
                if (message == expected)
                    return true;
            }
        }
        return false;
    }

    private void test_definition_validation () {
        var invalid = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "invalid-compatibility", "Fixture", "",
            "https://example.test/releases", "https://example.test/source", 1,
            {
                new VariantDefinition (
                    "default", "default", "$release_name", true,
                    new VariantCompatibility ({ CpuArchitecture.UNKNOWN, CpuArchitecture.X86_64, CpuArchitecture.X86_64 })
                ),
                new VariantDefinition (
                    "level-without-x86-64", "alt", "$release_name-alt", false,
                    new VariantCompatibility ({ CpuArchitecture.AARCH64 }, X86_64Level.V3)
                ),
                new VariantDefinition (
                    "level-without-aarch64", "arm-alt", "$release_name-arm-alt", false,
                    new VariantCompatibility (
                        { CpuArchitecture.X86_64 }, X86_64Level.BASELINE, false,
                        Aarch64Level.V8_1
                    )
                )
            },
            { InstallLayout.template ("default", "$release_name") }
        );
        var registry = new ProviderRegistry ({ invalid });
        assert (!registry.is_valid);
        assert (has_message (registry, "variant compatibility contains unknown architecture: default"));
        assert (has_message (registry, "variant compatibility architecture is duplicated: default"));
        assert (has_message (registry, "x86-64 compatibility requires at least the baseline level: default"));
        assert (has_message (registry, "x86-64 compatibility level requires x86-64 architecture: level-without-x86-64"));
        assert (has_message (registry, "AArch64 compatibility level requires AArch64 architecture: level-without-aarch64"));
    }

    private Json.Object object_from_json (string content) {
        try {
            var root = Json.from_string (content);
            assert (root.get_node_type () == Json.NodeType.OBJECT);
            return root.get_object ();
        } catch (Error e) {
            critical ("Could not parse JSON fixture: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_release_json () {
        var release = new Release (
            "v1", "", "", new Assets.Asset ("v1.tar.gz", "https://example.test/v1.tar.gz"), "", 0, "1", "v1"
        );
        release.variants.add (new ProtonPlus.Models.Variant (
            "v3", "x86_64_v3", "$release_name-v3", true, "https://example.test/v1-v3.tar.gz",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));
        release.variants.add (new ProtonPlus.Models.Variant (
            "arm", "aarch64", "$release_name-arm", false, "https://example.test/v1-arm.tar.gz",
            VariantCompatibility.for_aarch64_level (Aarch64Level.V8_1)
        ));
        var round_trip = Release.from_json (release.to_json ());
        assert (round_trip != null && round_trip.variants.size == 2);
        assert (round_trip.variants[0].compatibility.equals (VariantCompatibility.for_x86_64_level (X86_64Level.V3)));
        assert (round_trip.variants[1].compatibility.equals (VariantCompatibility.for_aarch64_level (Aarch64Level.V8_1)));

        var legacy = Release.from_json (object_from_json (
            "{\"kind\":\"generic\",\"title\":\"v1\",\"asset\":{\"name\":\"v1.tar.gz\",\"download_url\":\"https://example.test/v1.tar.gz\"},\"upstream_release_id\":\"1\",\"variants\":[{\"id\":\"default\",\"name\":\"default\",\"format\":\"$release_name\",\"default\":true,\"download_url\":\"https://example.test/v1.tar.gz\"}]}"
        ));
        assert (legacy != null && legacy.variants.size == 1);
        assert (!legacy.variants[0].compatibility.is_specified);
        assert (legacy.variants[0].is_compatible_with (host (CpuArchitecture.AARCH64)));

        var unknown = Release.from_json (object_from_json (
            "{\"kind\":\"generic\",\"title\":\"v1\",\"asset\":{\"name\":\"v1.tar.gz\",\"download_url\":\"https://example.test/v1.tar.gz\"},\"upstream_release_id\":\"1\",\"variants\":[{\"id\":\"default\",\"name\":\"default\",\"format\":\"$release_name\",\"default\":true,\"download_url\":\"https://example.test/v1.tar.gz\",\"compatibility\":{\"architectures\":[\"mips64\"],\"minimum_x86_64_level\":\"v9\",\"architecture_independent\":false}}]}"
        ));
        assert (unknown != null && unknown.variants.size == 1);
        assert (!unknown.variants[0].compatibility.is_specified);
        assert (unknown.variants[0].is_compatible_with (host (CpuArchitecture.AARCH64)));

        var unknown_level = Release.from_json (object_from_json (
            "{\"kind\":\"generic\",\"title\":\"v1\",\"asset\":{\"name\":\"v1.tar.gz\",\"download_url\":\"https://example.test/v1.tar.gz\"},\"upstream_release_id\":\"1\",\"variants\":[{\"id\":\"default\",\"name\":\"default\",\"format\":\"$release_name\",\"default\":true,\"download_url\":\"https://example.test/v1.tar.gz\",\"compatibility\":{\"architectures\":[\"x86_64\"],\"minimum_x86_64_level\":\"v9\",\"architecture_independent\":false}}]}"
        ));
        assert (unknown_level != null && unknown_level.variants.size == 1);
        assert (!unknown_level.variants[0].compatibility.is_specified);
        assert (unknown_level.variants[0].is_compatible_with (host (CpuArchitecture.AARCH64)));

        var legacy_aarch64 = Release.from_json (object_from_json (
            "{\"kind\":\"generic\",\"title\":\"v1\",\"asset\":{\"name\":\"v1.tar.gz\",\"download_url\":\"https://example.test/v1.tar.gz\"},\"upstream_release_id\":\"1\",\"variants\":[{\"id\":\"arm\",\"name\":\"aarch64\",\"format\":\"$release_name\",\"default\":true,\"download_url\":\"https://example.test/v1.tar.gz\",\"compatibility\":{\"architectures\":[\"aarch64\"],\"minimum_x86_64_level\":\"\",\"architecture_independent\":false}}]}"
        ));
        assert (legacy_aarch64 != null && legacy_aarch64.variants.size == 1);
        assert (legacy_aarch64.variants[0].compatibility.minimum_aarch64_level == Aarch64Level.V8_0);
        assert (legacy_aarch64.variants[0].is_compatible_with (host (CpuArchitecture.AARCH64)));
    }

    private void test_built_in_annotations () {
        var registry = new ProviderRegistry ();
        assert (registry.is_valid);
        var cachyos = registry.get_by_id ("proton-cachyos");
        assert (cachyos != null);
        var variants = cachyos.get_variants ();
        assert (variants[1].id == "x86-64-v3");
        assert (variants[1].compatibility.minimum_x86_64_level == X86_64Level.V3);
        assert (variants[0].compatibility.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V3)));
        assert (variants[1].compatibility.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V3)));
        assert (!variants[1].compatibility.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V2)));
        assert (variants[2].compatibility.minimum_aarch64_level == Aarch64Level.V8_1);
        assert (!variants[2].compatibility.is_compatible_with (host (CpuArchitecture.AARCH64)));
        assert (variants[2].compatibility.is_compatible_with (host (
            CpuArchitecture.AARCH64, X86_64Level.UNKNOWN, Aarch64Level.V8_1
        )));
        assert (!variants[2].compatibility.is_compatible_with (host (CpuArchitecture.X86_64, X86_64Level.V4)));

        var unspecified = registry.get_by_id ("proton-tkg");
        assert (unspecified != null);
        assert (!unspecified.get_variants ()[0].compatibility.is_specified);
        assert (unspecified.get_variants ()[0].compatibility.is_compatible_with (host (CpuArchitecture.AARCH64)));
    }
}
