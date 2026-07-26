namespace AppTests.ProviderDefinitionTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers.Runners;

    private interface FilterInspectable : Object {
        public abstract int filter_count { get; }
        public abstract int exclude_count { get; }
        public abstract string? get_filter (int index);
        public abstract string? get_exclude (int index);
    }

    private class InspectWineProton : Wine.Proton, FilterInspectable {
        public int filter_count { get { return request_asset_filter != null ? request_asset_filter.size : 0; } }
        public int exclude_count { get { return request_asset_exclude != null ? request_asset_exclude.size : 0; } }
        public string? get_filter (int index) { return request_asset_filter != null ? request_asset_filter.get (index) : null; }
        public string? get_exclude (int index) { return request_asset_exclude != null ? request_asset_exclude.get (index) : null; }
    }

    private class InspectWineStaging : Wine.Staging, FilterInspectable {
        public int filter_count { get { return request_asset_filter != null ? request_asset_filter.size : 0; } }
        public int exclude_count { get { return request_asset_exclude != null ? request_asset_exclude.size : 0; } }
        public string? get_filter (int index) { return request_asset_filter != null ? request_asset_filter.get (index) : null; }
        public string? get_exclude (int index) { return request_asset_exclude != null ? request_asset_exclude.get (index) : null; }
    }

    private class InspectWineStagingTkg : Wine.StagingTkg, FilterInspectable {
        public int filter_count { get { return request_asset_filter != null ? request_asset_filter.size : 0; } }
        public int exclude_count { get { return request_asset_exclude != null ? request_asset_exclude.size : 0; } }
        public string? get_filter (int index) { return request_asset_filter != null ? request_asset_filter.get (index) : null; }
        public string? get_exclude (int index) { return request_asset_exclude != null ? request_asset_exclude.get (index) : null; }
    }

    private class InspectWineVanilla : Wine.Vanilla, FilterInspectable {
        public int filter_count { get { return request_asset_filter != null ? request_asset_filter.size : 0; } }
        public int exclude_count { get { return request_asset_exclude != null ? request_asset_exclude.size : 0; } }
        public string? get_filter (int index) { return request_asset_filter != null ? request_asset_filter.get (index) : null; }
        public string? get_exclude (int index) { return request_asset_exclude != null ? request_asset_exclude.get (index) : null; }
    }

    private class SteamUsageLauncher : Launcher {
        public SteamUsageLauncher (string root) {
            base ("Steam", Launcher.InstallationTypes.SYSTEM, "", { root });
        }

        public override int get_compatibility_tool_usage_count (string compatibility_tool_name) {
            return compatibility_tool_name == "Proton-stl" ? 1 : 0;
        }
    }

    public void register_tests () {
        Test.add_func ("/provider-definitions/snapshot", test_definition_snapshot);
        Test.add_func ("/provider-definitions/variant-asset-suffixes", test_variant_asset_suffixes);
        Test.add_func ("/provider-definitions/kron4ek-filters", test_kron4ek_filters);
        Test.add_func ("/provider-definitions/ph42on-asset-selection", test_ph42on_asset_selection);
        Test.add_func ("/provider-definitions/steam-tinker-launch", test_steam_tinker_launch);
    }

    internal Json.Object get_snapshot () {
        try {
            var content = ProtonPlus.Utils.Filesystem.get_file_content (
                Path.build_filename ("fixtures", "definitions", "runners.json")
            );
            var root = Json.from_string (content);
            assert (root.get_node_type () == Json.NodeType.OBJECT);
            return root.get_object ();
        } catch (Error e) {
            critical ("Could not load definition snapshot: %s", e.message);
            assert_not_reached ();
        }
    }

    internal Gee.ArrayList<IRunner> get_all_runners () {
        var all_runners = new Gee.ArrayList<IRunner> ();
        var runners = new Runners ();
        foreach (var type in new RunnerType[] { RunnerType.DXVK, RunnerType.VKD3D, RunnerType.Proton, RunnerType.Wine }) {
            all_runners.add_all (runners.getRunners (type));
        }
        return all_runners;
    }

    internal IRunner get_runner (string title) {
        foreach (var runner in get_all_runners ()) {
            if (runner.title == title)
                return runner;
        }
        assert_not_reached ();
    }

    internal string runner_type_name (string title) {
        var runners = new Runners ();
        foreach (var type in new RunnerType[] { RunnerType.DXVK, RunnerType.VKD3D, RunnerType.Proton, RunnerType.Wine }) {
            foreach (var runner in runners.getRunners (type)) {
                if (runner.title == title) {
                    switch (type) {
                    case RunnerType.DXVK:
                        return "DXVK";
                    case RunnerType.VKD3D:
                        return "VKD3D";
                    case RunnerType.Proton:
                        return "Proton";
                    case RunnerType.Wine:
                        return "Wine";
                    }
                }
            }
        }
        assert_not_reached ();
    }

    internal Tools.Basic? create_tool (IRunner runner) {
        string root;
        try {
            root = DirUtils.make_tmp ("protonplus-definition-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary launcher root: %s", e.message);
            assert_not_reached ();
        }
        var launcher = new Launcher ("Test launcher", Launcher.InstallationTypes.SYSTEM, "", { root });
        var tool = runner.create_tool (new Group ("Test", "", "", launcher));
        assert (FileUtils.remove (root) == 0);
        return tool;
    }

    internal string source_name (SourceType source_type) {
        switch (source_type) {
        case SourceType.GITHUB:
            return "GITHUB";
        case SourceType.GITHUB_ACTION:
            return "GITHUB_ACTION";
        case SourceType.GITLAB:
            return "GITLAB";
        case SourceType.FORGEJO:
            return "FORGEJO";
        default:
            assert_not_reached ();
        }
    }

    internal string render_format (string format, string title, string release_name, string tag_name) {
        return format.replace ("$title", title)
                     .replace ("$release_name", release_name)
                     .replace ("$tag_name", tag_name);
    }

    internal void assert_variants_match (IRunner runner, Json.Array expected_variants) {
        assert (runner.variants.size == expected_variants.get_length ());
        for (var index = 0; index < expected_variants.get_length (); index++) {
            var expected = expected_variants.get_array_element (index);
            var actual = runner.variants.get (index);
            assert (actual.name == expected.get_string_element (0));
            if (actual.format != expected.get_string_element (1)) {
                Test.message ("%s variant %s: expected %s, got %s", runner.title, actual.name,
                              expected.get_string_element (1), actual.format);
                assert_not_reached ();
            }
            assert (actual.is_default == expected.get_boolean_element (2));
        }
    }

    private void test_definition_snapshot () {
        var snapshot = get_snapshot ();
        var definitions = snapshot.get_array_member ("definitions");
        var runners = get_all_runners ();
        assert (definitions.get_length () == 19);
        assert (runners.size == definitions.get_length ());

        var titles = new Gee.HashSet<string> ();
        foreach (var runner in runners) {
            assert (titles.add (runner.title));
        }

        for (var index = 0; index < definitions.get_length (); index++) {
            var expected = definitions.get_object_element (index);
            var runner = get_runner (expected.get_string_member ("title"));
            var base_runner = runner as Base;
            assert (base_runner != null);
            assert (runner_type_name (runner.title) == expected.get_string_member ("type"));
            assert (runner.endpoint == expected.get_string_member ("endpoint"));
            assert (source_name (base_runner.source_type) == expected.get_string_member ("source"));
            assert (base_runner.sort_priority == expected.get_int_member ("priority"));
            assert_variants_match (runner, expected.get_array_member ("variants"));

            var tool = create_tool (runner);
            assert (tool != null);
            assert (tool.tag == expected.get_string_member_with_default ("tag", ""));
            assert (tool.legacy == expected.get_boolean_member_with_default ("legacy", false));
        }
    }

    private void test_variant_asset_suffixes () {
        var snapshot = get_snapshot ();
        var release_name = snapshot.get_string_member ("release_name");
        var tag_name = snapshot.get_string_member ("tag_name");
        var definitions = snapshot.get_array_member ("definitions");

        for (var definition_index = 0; definition_index < definitions.get_length (); definition_index++) {
            var expected = definitions.get_object_element (definition_index);
            var runner = get_runner (expected.get_string_member ("title"));
            var tool = create_tool (runner);
            assert (tool != null);
            var expected_variants = expected.get_array_member ("variants");
            var assets = new Gee.LinkedList<ProtonPlus.Models.Internal.Assets.IAsset> ();

            for (var variant_index = 0; variant_index < expected_variants.get_length (); variant_index++) {
                var expected_variant = expected_variants.get_array_element (variant_index);
                var asset_name = render_format (
                    expected_variant.get_string_element (1), tool.title, release_name, tag_name
                );
                assets.add (new ProtonPlus.Models.Internal.Assets.Asset (
                    asset_name, "https://example.invalid/%d/%d".printf (definition_index, variant_index)
                ));
            }

            var variants = tool.create_release_variants (release_name, tag_name, assets);
            assert (variants.size == expected_variants.get_length ());
            for (var variant_index = 0; variant_index < variants.size; variant_index++) {
                assert (variants.get (variant_index).download_url ==
                        "https://example.invalid/%d/%d".printf (definition_index, variant_index));
            }
        }
    }

    private void test_kron4ek_filters () {
        var shared_endpoint = "https://api.github.com/repos/Kron4ek/Wine-Builds/releases";
        var runners = get_all_runners ();
        var matching = new Gee.ArrayList<IRunner> ();
        foreach (var runner in runners) {
            if (runner.endpoint == shared_endpoint)
                matching.add (runner);
        }
        assert (matching.size == 4);

        var inspected_runners = new FilterInspectable[] {
            new InspectWineProton (), new InspectWineStaging (),
            new InspectWineStagingTkg (), new InspectWineVanilla ()
        };
        for (var index = 0; index < inspected_runners.length; index++) {
            var inspected = inspected_runners[index];

            if (index == 0) {
                assert (inspected.filter_count == 1);
                assert (inspected.get_filter (0) == "proton");
                assert (inspected.exclude_count == 0);
            } else {
                assert (inspected.filter_count == 0);
                assert (inspected.exclude_count == 2);
                assert (inspected.get_exclude (0) == "proton");
                assert (inspected.get_exclude (1) == ".0.");
            }
        }
    }

    private void test_ph42on_asset_selection () {
        var tool = create_tool (get_runner ("DXVK GPL+Async (Ph42oN)"));
        assert (tool != null);
        var assets = new Gee.LinkedList<ProtonPlus.Models.Internal.Assets.IAsset> ();
        assets.add (new ProtonPlus.Models.Internal.Assets.Asset (
            "dxvk-gplasync-v3.0-1-ci.zip", "https://example.invalid/ci.zip"
        ));
        assets.add (new ProtonPlus.Models.Internal.Assets.Asset (
            "dxvk-gplasync-v3.0-1.tar.gz", "https://example.invalid/release.tar.gz"
        ));

        var variants = tool.create_release_variants ("v3.0-1", "v3.0-1", assets);
        assert (variants.size == 1);
        assert (variants.get (0).download_url == "https://example.invalid/release.tar.gz");
    }

    private void test_steam_tinker_launch () {
        string root;
        try {
            root = DirUtils.make_tmp ("protonplus-steamtinkerlaunch-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary launcher root: %s", e.message);
            assert_not_reached ();
        }
        var snapshot = get_snapshot ().get_object_member ("steam_tinker_launch");
        var install_path = Path.build_filename (root, snapshot.get_string_member ("installation_directory"));
        assert (ProtonPlus.Utils.Filesystem.create_directory (install_path));

        var group = new Group ("Proton", "", "", new SteamUsageLauncher (root));
        group.rebuild_installed_tool_index ();
        var tool = new ProtonPlus.Models.Tools.SteamTinkerLaunch (group);
        assert (tool.title == snapshot.get_string_member ("title"));
        assert (tool.is_installed ());
        assert (tool.is_used ());

        assert (DirUtils.remove (install_path) == 0);
        assert (FileUtils.remove (root) == 0);
    }
}
