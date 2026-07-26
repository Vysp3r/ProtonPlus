namespace AppTests.ProviderRegistryTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Providers.Sources;

    public void register_tests () {
        Test.add_func ("/provider-registry/built-ins-valid", test_built_ins_are_valid);
        Test.add_func ("/provider-registry/lookups-and-order", test_lookups_and_order);
        Test.add_func ("/provider-registry/defensive-collections", test_defensive_collections);
        Test.add_func ("/provider-registry/validation/duplicate-provider", test_duplicate_provider_validation);
        Test.add_func ("/provider-registry/validation/invalid-variant", test_invalid_variant_validation);
        Test.add_func ("/provider-registry/validation/invalid-layout", test_invalid_layout_validation);
        Test.add_func ("/provider-registry/validation/github-actions-template", test_github_actions_template_validation);
        Test.add_func ("/provider-registry/validation/required-fields-and-source", test_required_field_and_source_validation);
        Test.add_func ("/provider-registry/sources-available", test_builtin_sources_are_available);
        Test.add_func ("/provider-registry/definition-only-provider-creates-standard-tool", test_definition_only_provider_creates_standard_tool);
        Test.add_func ("/provider-registry/unsupported-source-is-rejected", test_unsupported_source_is_rejected);
    }

    private ProviderDefinition valid_definition (string provider_id = "fixture") {
        return new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, provider_id, "Fixture", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }
        );
    }

    private Group fixture_group (string family_id = "fixture") {
        var launcher = new Launcher ("Fixture launcher", Launcher.InstallationTypes.SYSTEM, "", {}, family_id);
        return new Group ("Fixture group", "", "", launcher, "fixture");
    }

    private void assert_provider_ids (ProviderDefinition[] definitions, string[] expected_ids) {
        assert (definitions.length == expected_ids.length);
        for (var index = 0; index < definitions.length; index++)
            assert (definitions[index].provider_id == expected_ids[index]);
    }

    private bool has_message (ProviderRegistry registry, string expected_message) {
        foreach (var result in registry.get_validation_results ()) {
            foreach (var message in result.get_messages ()) {
                if (message == expected_message)
                    return true;
            }
        }
        return false;
    }

    private void test_built_ins_are_valid () {
        var registry = new ProviderRegistry ();
        assert (registry.is_valid);
        assert (registry.get_validation_results ().length == 0);

        foreach (var definition in registry.get_all ()) {
            var default_count = 0;
            var variant_ids = new Gee.HashSet<string> ();
            foreach (var variant in definition.get_variants ()) {
                assert (variant_ids.add (variant.id));
                if (variant.is_default)
                    default_count++;
            }
            assert (default_count == 1);

            var launcher_family_ids = new Gee.HashSet<string> ();
            foreach (var layout in definition.get_install_layouts ())
                assert (launcher_family_ids.add (layout.launcher_family_id));
        }
    }

    private void test_lookups_and_order () {
        var registry = new ProviderRegistry ();
        var expected_ids = new string[] {
            "dxvk-doitsujin", "dxvk-gplasync-ph42on", "dxvk-sarek",
            "vkd3d-proton", "vkd3d-lutris",
            "proton-ge", "proton-cachyos", "dw-proton", "proton-ge-rtsp", "proton-tkg",
            "proton-em", "proton-cachyos-wineland", "luxtorpeda", "boxtron", "roberta",
            "wine-proton", "wine-staging", "wine-staging-tkg", "wine-vanilla"
        };

        assert_provider_ids (registry.get_all (), expected_ids);
        assert_provider_ids (registry.get (Category.DXVK), expected_ids[0:3]);
        assert_provider_ids (registry.get (Category.VKD3D), expected_ids[3:5]);
        assert_provider_ids (registry.get (Category.PROTON), expected_ids[5:15]);
        assert_provider_ids (registry.get (Category.WINE), expected_ids[15:19]);

        foreach (var provider_id in expected_ids) {
            var definition = registry.get_by_id (provider_id);
            assert (definition != null);
            assert (definition.provider_id == provider_id);
        }
        assert (registry.get_by_id ("missing-provider") == null);
    }

    private void test_defensive_collections () {
        var registry = new ProviderRegistry ();
        var by_category = registry.get (Category.DXVK);
        var all = registry.get_all ();
        var first_id = by_category[0].provider_id;
        var all_first_id = all[0].provider_id;
        by_category[0] = registry.get_by_id ("dxvk-sarek");
        all[0] = registry.get_by_id ("wine-vanilla");
        assert (registry.get (Category.DXVK)[0].provider_id == first_id);
        assert (registry.get_all ()[0].provider_id == all_first_id);

        var filters = registry.get_by_id ("wine-proton").asset_filters;
        filters[0] = "changed";
        assert (registry.get_by_id ("wine-proton").asset_filters[0] == "proton");
    }

    private void test_duplicate_provider_validation () {
        var registry = new ProviderRegistry ({ valid_definition ("duplicate"), valid_definition ("duplicate") });
        assert (!registry.is_valid);
        assert (has_message (registry, "provider ID is duplicated"));
    }

    private void test_invalid_variant_validation () {
        var definition = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "invalid-variants", "Fixture", "",
            "https://example.test/releases", 1,
            {
                new VariantDefinition ("duplicate", "", "", true),
                new VariantDefinition ("duplicate", "second", "$release_name", true)
            },
            { InstallLayout.template ("default", "$release_name") }
        );
        var registry = new ProviderRegistry ({ definition });
        assert (!registry.is_valid);
        assert (has_message (registry, "variant ID is duplicated: duplicate"));
        assert (has_message (registry, "variant name is empty"));
        assert (has_message (registry, "variant format is empty"));
        assert (has_message (registry, "more than one default variant is configured"));

        var missing_default = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "missing-default", "Fixture", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", false) },
            { InstallLayout.template ("default", "$release_name") }
        );
        registry = new ProviderRegistry ({ missing_default });
        assert (!registry.is_valid);
        assert (has_message (registry, "default variant is missing"));
    }

    private void test_invalid_layout_validation () {
        var definition = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "invalid-layouts", "Fixture", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            {
                InstallLayout.template ("steam", "$release_name"),
                InstallLayout.template ("steam", "$release_name"),
                InstallLayout.template ("", "$release_name")
            }
        );
        var registry = new ProviderRegistry ({ definition });
        assert (!registry.is_valid);
        assert (has_message (registry, "install layout is duplicated for launcher family: steam"));
        assert (has_message (registry, "launcher family ID is empty"));
        assert (has_message (registry, "default install layout is missing"));
    }

    private void test_github_actions_template_validation () {
        var definition = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB_ACTIONS, "invalid-actions", "Fixture", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }
        );
        var registry = new ProviderRegistry ({ definition });
        assert (!registry.is_valid);
        assert (has_message (registry, "GitHub Actions source requires a URL template"));

        var accidental_template = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "invalid-template", "Fixture", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }, null, null, "", false,
            "https://example.test/artifacts/{id}"
        );
        registry = new ProviderRegistry ({ accidental_template });
        assert (!registry.is_valid);
        assert (has_message (registry, "only GitHub Actions sources may have a URL template"));
    }

    private void test_required_field_and_source_validation () {
        var definition = new ProviderDefinition (
            Category.PROTON, (SourceType) 999, "", "", "", "", 1, {}, {}
        );
        var registry = new ProviderRegistry ({ definition });
        assert (!registry.is_valid);
        assert (has_message (registry, "provider ID is empty"));
        assert (has_message (registry, "title is empty"));
        assert (has_message (registry, "endpoint is empty"));
        assert (has_message (registry, "source type has no supported source mapping"));
        assert (has_message (registry, "variants are missing"));
        assert (has_message (registry, "install layouts are missing"));
    }

    private void test_builtin_sources_are_available () {
        foreach (var definition in new ProviderRegistry ().get_all ()) {
            var source = ReleaseSourceRegistry.create (definition.source_type);
            assert (source != null);
            switch (definition.source_type) {
            case SourceType.GITHUB:
                assert (source is GitHubReleaseSource);
                break;
            case SourceType.GITHUB_ACTIONS:
                assert (source is GitHubActionsReleaseSource);
                break;
            case SourceType.GITLAB:
                assert (source is GitLabReleaseSource);
                break;
            case SourceType.FORGEJO:
                assert (source is ForgejoReleaseSource);
                break;
            default:
                assert_not_reached ();
            }
        }
    }

    private void test_definition_only_provider_creates_standard_tool () {
        var definition = valid_definition ("definition-only");
        var registry = new ProviderRegistry ({ definition });
        assert (registry.is_valid);

        var tool = ProviderCatalog.create_tool (definition, fixture_group ());
        assert (tool != null);
        assert (tool is Tools.ProviderTool);
        assert (tool.definition == definition);
        assert (tool.provider_id == "definition-only");
        assert (tool.release_catalog != null);
    }

    private void test_unsupported_source_is_rejected () {
        var definition = new ProviderDefinition (
            Category.PROTON, (SourceType) 999, "unsupported-source", "Fixture", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("standard", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }
        );
        var registry = new ProviderRegistry ({ definition });

        assert (!registry.is_valid);
        assert (has_message (registry, "source type has no supported source mapping"));
        assert (ReleaseSourceRegistry.create (definition.source_type) == null);
        assert (ProviderCatalog.create_tool (definition, fixture_group ()) == null);
    }
}
