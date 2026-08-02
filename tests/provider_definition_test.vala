namespace AppTests.ProviderDefinitionTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Providers.Sources;

    public void register_tests () {
        Test.add_func ("/provider-definitions/snapshot", test_definition_snapshot);
        Test.add_func ("/provider-definitions/kron4ek-filters", test_kron4ek_filters);
        Test.add_func ("/provider-definitions/ph42on-asset-selection", test_ph42on_asset_selection);
        Test.add_func ("/provider-definitions/catalog-construction-isolation", test_catalog_construction_isolation);
        Test.add_func ("/provider-definitions/proton-tkg-archive-requirement", test_proton_tkg_archive_requirement);
        Test.add_func ("/provider-definitions/tinkergame", test_tinker_game);
    }

    private Json.Object get_snapshot () {
        var content = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "definitions", "runners.json")
        );
        try {
            var root = Json.from_string (content);
            assert (root.get_node_type () == Json.NodeType.OBJECT);
            return root.get_object ();
        } catch (Error e) {
            critical ("Could not parse definition snapshot: %s", e.message);
            assert_not_reached ();
        }
    }

    private ProviderDefinition get_definition (string provider_id) {
        var definition = new ProviderRegistry ().get_by_id (provider_id);
        assert (definition != null);
        return (!) definition;
    }

    private string category_name (Category category) {
        switch (category) {
        case Category.DXVK:
            return "DXVK";
        case Category.VKD3D:
            return "VKD3D";
        case Category.PROTON:
            return "Proton";
        case Category.WINE:
            return "Wine";
        default:
            assert_not_reached ();
        }
    }

    private string source_name (SourceType source_type) {
        switch (source_type) {
        case SourceType.GITHUB:
            return "GITHUB";
        case SourceType.GITHUB_ACTIONS:
            return "GITHUB_ACTION";
        case SourceType.GITLAB:
            return "GITLAB";
        case SourceType.FORGEJO:
            return "FORGEJO";
        default:
            assert_not_reached ();
        }
    }

    private Tools.ProviderTool? create_tool (ProviderDefinition definition, string family_id = "fixture") {
        var launcher = new Launcher ("Fixture launcher", Launcher.InstallationTypes.SYSTEM, "", {}, family_id);
        var group = new Group ("Fixture group", "", "", launcher, "fixture");
        return ProviderCatalog.create_tool (definition, group);
    }

    private void test_definition_snapshot () {
        var expected = get_snapshot ().get_array_member ("definitions");
        var definitions = new ProviderRegistry ().get_all ();
        assert (definitions.length == 19);
        assert (expected.get_length () == definitions.length);

        foreach (var expected_definition in expected.get_elements ()) {
            var object = expected_definition.get_object ();
            var definition = get_definition (object.get_string_member ("provider_id"));
            assert (definition.provider_id == object.get_string_member ("provider_id"));
            assert (definition.title == object.get_string_member ("title"));
            assert (category_name (definition.category) == object.get_string_member ("type"));
            assert (source_name (definition.source_type) == object.get_string_member ("source"));
            assert (definition.endpoint == object.get_string_member ("endpoint"));
            assert (definition.sort_priority == object.get_int_member ("priority"));
            assert (definition.tag == object.get_string_member_with_default ("tag", ""));
            assert (definition.legacy == object.get_boolean_member_with_default ("legacy", false));

            var expected_variants = object.get_array_member ("variants");
            var variants = definition.get_variants ();
            assert (variants.length == expected_variants.get_length ());
            for (var index = 0; index < variants.length; index++) {
                var actual = variants[index];
                var expected_variant = expected_variants.get_array_element (index);
                assert (actual.id == expected_variant.get_string_element (0));
                assert (actual.name == expected_variant.get_string_element (1));
                assert (actual.format == expected_variant.get_string_element (2));
                assert (actual.is_default == expected_variant.get_boolean_element (3));
            }
        }
    }

    private void test_kron4ek_filters () {
        var proton = get_definition ("wine-proton");
        assert (proton.asset_filters.length == 1);
        assert (proton.asset_filters[0] == "proton");
        assert (proton.asset_exclusions.length == 0);

        foreach (var provider_id in new string[] {
            "wine-staging", "wine-staging-tkg", "wine-vanilla"
        }) {
            var definition = get_definition (provider_id);
            assert (definition.asset_filters.length == 0);
            assert (definition.asset_exclusions.length == 2);
            assert (definition.asset_exclusions[0] == "proton");
            assert (definition.asset_exclusions[1] == ".0.");
        }
    }

    private void test_ph42on_asset_selection () {
        var definition = get_definition ("dxvk-gplasync-ph42on");
        var assets = new Gee.LinkedList<ProtonPlus.Models.Assets.Asset> ();
        assets.add (new ProtonPlus.Models.Assets.Asset (
            "dxvk-gplasync-v3.0-1-ci.zip", "https://example.invalid/ci.zip"
        ));
        assets.add (new ProtonPlus.Models.Assets.Asset (
            "dxvk-gplasync-v3.0-1.tar.gz", "https://example.invalid/release.tar.gz"
        ));

        var variants = CatalogReleaseBuilder.create_variants (definition, "v3.0-1", "v3.0-1", assets);
        assert (variants.size == 1);
        assert (variants[0].download_url == "https://example.invalid/release.tar.gz");
        var primary_asset = CatalogReleaseBuilder.select_default_asset (assets, variants);
        assert (primary_asset != null && primary_asset.name == "dxvk-gplasync-v3.0-1.tar.gz");
    }

    private void test_catalog_construction_isolation () {
        var definition = get_definition ("proton-ge");
        var first = create_tool (definition, "steam");
        var second = create_tool (definition, "steam");
        assert (first != null);
        assert (second != null);
        assert (first.variants.size == 2);
        assert (second.variants.size == 2);

        first.variants[0].download_url = "https://example.test/mutated";
        assert (second.variants[0].download_url == null);
        assert (definition.get_variants ()[0].name == "x86");
        assert (first.provider_id == definition.provider_id);
        assert (second.provider_id == definition.provider_id);
        assert (first.definition == definition);
        assert (second.definition == definition);
    }

    private void test_proton_tkg_archive_requirement () {
        var definition = get_definition ("proton-tkg");
        assert (definition.archive_install_requirement == ArchiveInstallRequirement.NESTED_ARCHIVE);
        var tool = create_tool (definition);
        assert (tool != null);
        assert (tool.archive_install_requirement == ArchiveInstallRequirement.NESTED_ARCHIVE);

        var job = new ProtonPlus.Services.InstallJob (new Release (
            "Fixture release", "", "", new ProtonPlus.Models.Assets.Asset ("fixture.zip", "https://example.test/fixture.zip"),
            "", 0, "fixture-release", "fixture-release"
        ), (!) tool);
        assert (job.archive_install_requirement == ArchiveInstallRequirement.NESTED_ARCHIVE);
    }

    private void test_tinker_game () {
        string root;
        try {
            root = DirUtils.make_tmp ("protonplus-tinkergame-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary launcher root: %s", e.message);
            assert_not_reached ();
        }

        var expected = get_snapshot ().get_object_member ("tinkergame");
        var install_path = Path.build_filename (root, expected.get_string_member ("installation_directory"));
        assert (ProtonPlus.Utils.Filesystem.create_directory (install_path));
        var launcher = new Launcher ("Steam", Launcher.InstallationTypes.SYSTEM, "", { root }, "steam");
        var group = new Group ("Proton", "", "", launcher);
        group.refresh_installed_state ();
        var tool = new ProtonPlus.Models.Tools.TinkerGame (group);
        assert (tool.title == expected.get_string_member ("title"));
        assert (tool.release_catalog != null);
        var loop = new MainLoop ();
        ProtonPlus.Models.ReleaseCatalogResult? catalog_result = null;
        tool.release_catalog.load.begin (false, (obj, async_result) => {
            catalog_result = tool.release_catalog.load.end (async_result);
            loop.quit ();
        });
        loop.run ();
        assert (catalog_result != null && catalog_result.succeeded && catalog_result.releases.size == 1);
        assert (catalog_result.releases[0].kind == Release.Kind.TINKERGAME);

        var compatibility_tool = new ProtonPlus.Models.CompatibilityTool ("Simple", "simple");
        assert (!compatibility_tool.get_type ().is_a (typeof (ProtonPlus.Models.Tool)));

        assert (DirUtils.remove (install_path) == 0);
        assert (FileUtils.remove (root) == 0);
    }
}
