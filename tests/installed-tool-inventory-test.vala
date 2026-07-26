namespace AppTests.InstalledToolInventoryTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    private class InventoryLauncher : Launcher {
        public string used_identifier { get; set; default = ""; }

        public InventoryLauncher (string root) {
            base ("Fixture launcher", InstallationTypes.SYSTEM, "", { root }, "fixture");
        }

        public override int get_compatibility_tool_usage_count (string identifier) {
            return identifier == used_identifier ? 1 : 0;
        }
    }

    public void register_tests () {
        Test.add_func ("/installed-tool-inventory/stable-identity-wins-and-constrains-launcher", test_stable_identity);
        Test.add_func ("/installed-tool-inventory/unambiguous-legacy-endpoint-migrates", test_legacy_endpoint_migration);
        Test.add_func ("/installed-tool-inventory/legacy-tag-and-directory-fallbacks", test_legacy_tag_and_directory_fallbacks);
        Test.add_func ("/installed-tool-inventory/vdf-internal-and-display-title-fallbacks", test_vdf_fallbacks);
        Test.add_func ("/installed-tool-inventory/latest-and-variant-directories", test_latest_and_variant_directories);
        Test.add_func ("/installed-tool-inventory/steam-tinker-launch-usage", test_steam_tinker_launch_usage);
        Test.add_func ("/installed-tool-inventory/queries-are-cached-and-invalidation-refreshes", test_cached_queries_and_refresh);
        Test.add_func ("/installed-tool-inventory/groups-are-isolated", test_group_isolation);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-inventory-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        var deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, result) => {
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result);
            loop.quit ();
        });
        loop.run ();
        return deleted;
    }

    private ProviderDefinition definition (string id, string title, string endpoint = "https://example.test/releases") {
        return new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, id, title, "", endpoint, 1,
            {
                new VariantDefinition ("default", "default", "$release_name", true),
                new VariantDefinition ("arm", "Arm 64", "$release_name-arm", false)
            },
            { new DirectoryNameFormat ("default", "$release_name") }
        );
    }

    private Tools.Basic add_tool (Group group, ProviderDefinition definition) {
        var tool = ProviderCatalog.create_tool (definition, group);
        assert (tool != null);
        group.tools.add ((!) tool);
        return (!) tool;
    }

    private Group group (InventoryLauncher launcher, string directory = "") {
        var value = new Group ("Fixture group", "", directory, launcher, "fixture");
        value.tools = new Gee.LinkedList<Tool> ();
        return value;
    }

    private void save_metadata (string path, string provider_id = "", string tool_id = "", string launcher_id = "", string tag = "") {
        var metadata = ProtonPlus.Utils.Metadata.load (path);
        metadata.provider_id = provider_id;
        metadata.tool_id = tool_id;
        metadata.launcher_id = launcher_id;
        metadata.tag = tag;
        assert (metadata.save (path));
    }

    private Release release (string title, string source_tag = "") {
        return new Release (
            title, "", "", new ProtonPlus.Models.Assets.Asset ("fixture.tar.gz", "https://example.test/fixture.tar.gz"),
            "", 0, "fixture-release", source_tag
        );
    }

    private void test_stable_identity () {
        var root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        var value = group (launcher);
        var alpha = add_tool (value, definition ("alpha", "Alpha"));
        var beta = add_tool (value, definition ("beta", "Beta"));
        var path = Path.build_filename (root, "Alpha");
        assert (ProtonPlus.Utils.Filesystem.create_directory (path));

        // A persisted identity for beta must not use Alpha's directory name.
        save_metadata (path, beta.provider_id, beta.id, launcher.instance_id);
        value.refresh_installed_state ();
        assert (!alpha.is_installed ());
        assert (beta.is_installed ());

        // Matching tool/provider IDs from another launcher instance cannot
        // fall through to legacy directory matching either.
        save_metadata (path, alpha.provider_id, alpha.id, "other-system");
        value.refresh_installed_state ();
        assert (!alpha.is_installed ());
        assert (!beta.is_installed ());

        assert (delete_directory (root));
    }

    private void test_legacy_tag_and_directory_fallbacks () {
        var root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        var value = group (launcher);
        var tool = add_tool (value, definition ("tag-tool", "Tag Tool"));
        tool.releases.add (release ("release-name", "legacy-tag"));

        var tagged = Path.build_filename (root, "old-installation");
        assert (ProtonPlus.Utils.Filesystem.create_directory (tagged));
        save_metadata (tagged, "", "", "", "legacy-tag");
        value.refresh_installed_state ();
        assert (tool.is_installed ());
        var migrated = ProtonPlus.Utils.Metadata.load (tagged);
        assert (migrated.tool_id == tool.id);
        assert (migrated.provider_id == tool.provider_id);
        assert (migrated.launcher_id == launcher.instance_id);

        ProtonPlus.Utils.Filesystem.delete_file (Path.build_filename (tagged, ".protonplus"));
        assert (DirUtils.remove (tagged) == 0);
        var directory_fallback = Path.build_filename (root, "Tag Tool");
        assert (ProtonPlus.Utils.Filesystem.create_directory (directory_fallback));
        value.refresh_installed_state ();
        assert (tool.is_installed ());
        assert (tool.resolved_installed_entry != null);
        assert (((!) tool.resolved_installed_entry).directory_name == "Tag Tool");

        assert (delete_directory (root));
    }

    private void test_legacy_endpoint_migration () {
        var root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        var value = group (launcher);
        var tool = add_tool (value, definition ("endpoint-tool", "Endpoint Tool"));
        var path = Path.build_filename (root, "old-endpoint-installation");
        assert (ProtonPlus.Utils.Filesystem.create_directory (path));
        var metadata = ProtonPlus.Utils.Metadata.load (path);
        metadata.runner_endpoint = "https://example.test/releases";
        assert (metadata.save (path));

        value.refresh_installed_state ();
        assert (tool.is_installed ());
        var migrated = ProtonPlus.Utils.Metadata.load (path);
        assert (migrated.provider_id == tool.provider_id);
        assert (migrated.tool_id == tool.id);
        assert (migrated.launcher_id == launcher.instance_id);

        assert (delete_directory (root));
    }

    private void write_vdf (string path, string internal_title, string display_title) {
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (path, "compatibilitytool.vdf"),
            "\"compat_tools\" // tools\n{\n\t\"%s\" // Internal name of this tool\n\t{\n\t\t\"display_name\" \"%s\"\n\t}\n}\n".printf (internal_title, display_title)
        );
    }

    private void test_vdf_fallbacks () {
        var root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        var internal_group = group (launcher);
        var internal_tool = add_tool (internal_group, definition ("internal", "Internal Match"));
        var internal_path = Path.build_filename (root, "internal-directory");
        assert (ProtonPlus.Utils.Filesystem.create_directory (internal_path));
        write_vdf (internal_path, "Internal Match", "Different Display");
        launcher.used_identifier = "Internal Match";
        internal_group.refresh_installed_state ();
        assert (internal_tool.is_installed ());
        assert (internal_tool.is_used ());

        assert (delete_directory (internal_path));
        var display_group = group (launcher);
        var display_tool = add_tool (display_group, definition ("display", "Display Match"));
        var display_path = Path.build_filename (root, "display-directory");
        assert (ProtonPlus.Utils.Filesystem.create_directory (display_path));
        write_vdf (display_path, "Internal Usage Name", "Display Match");
        launcher.used_identifier = "Internal Usage Name";
        display_group.refresh_installed_state ();
        assert (display_tool.is_installed ());
        assert (display_tool.is_used ());

        assert (delete_directory (root));
    }

    private void test_latest_and_variant_directories () {
        var root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        var value = group (launcher);
        var tool = add_tool (value, definition ("runner", "Runner"));

        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.build_filename (root, "Runner Latest")));
        value.refresh_installed_state ();
        assert (tool.is_installed ());
        assert (delete_directory (Path.build_filename (root, "Runner Latest")));

        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.build_filename (root, "v1-Arm_64")));
        value.refresh_installed_state ();
        assert (!tool.is_installed ());
        tool.releases.add (release ("v1"));
        value.refresh_installed_state ();
        assert (tool.is_installed ());

        assert (delete_directory (root));
    }

    private void test_steam_tinker_launch_usage () {
        var root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        launcher.used_identifier = "Proton-stl";
        var value = group (launcher);
        var tool = new Tools.SteamTinkerLaunch (value);
        value.tools.add (tool);
        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.build_filename (root, "SteamTinkerLaunch")));

        value.refresh_installed_state ();
        assert (tool.is_installed ());
        assert (tool.is_used ());

        assert (delete_directory (root));
    }

    private void test_cached_queries_and_refresh () {
        var root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        var value = group (launcher);
        var tool = add_tool (value, definition ("cached", "Cached Tool"));
        var path = Path.build_filename (root, "Cached Tool");
        assert (ProtonPlus.Utils.Filesystem.create_directory (path));
        save_metadata (path, tool.provider_id, tool.id, launcher.instance_id);

        value.refresh_installed_state ();
        var generation = value.installed_tool_inventory.refresh_generation;
        var metadata_path = Path.build_filename (path, ".protonplus");
        var metadata_before = ProtonPlus.Utils.Filesystem.get_file_content (metadata_path);
        for (var index = 0; index < 20; index++) {
            assert (tool.is_installed ());
            assert (!tool.is_used ());
        }
        assert (value.installed_tool_inventory.refresh_generation == generation);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (metadata_path) == metadata_before);

        assert (delete_directory (path));
        value.invalidate_installed_state ();
        assert (value.installed_tool_inventory.is_stale);
        assert (value.get_installed_tool_snapshot ().size == 0);
        assert (!tool.is_installed ());
        value.refresh_installed_state ();
        assert (!tool.is_installed ());

        assert (delete_directory (root));
    }

    private void test_group_isolation () {
        var root = temporary_directory ();
        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.build_filename (root, "one")));
        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.build_filename (root, "two")));
        var launcher = new InventoryLauncher (root);
        var first = group (launcher, "/one");
        var second = group (launcher, "/two");
        var first_tool = add_tool (first, definition ("first", "First Tool"));
        var second_tool = add_tool (second, definition ("second", "Second Tool"));
        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.build_filename (root, "one", "First Tool")));

        first.refresh_installed_state ();
        second.refresh_installed_state ();
        assert (first_tool.is_installed ());
        assert (!second_tool.is_installed ());

        assert (delete_directory (root));
    }
}
