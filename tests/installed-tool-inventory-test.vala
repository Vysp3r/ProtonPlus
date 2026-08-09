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

    private class InventorySteam : ProtonPlus.Models.Launchers.Steam {
        public InventorySteam (string root) {
            base (Launcher.InstallationTypes.SNAP);
            directory = root;
            installed = true;
            groups = {};
        }
    }

    public void register_tests () {
        Test.add_func ("/installed-tool-inventory/stable-identity-wins-and-constrains-launcher", test_stable_identity);
        Test.add_func ("/installed-tool-inventory/unambiguous-legacy-endpoint-migrates", test_legacy_endpoint_migration);
        Test.add_func ("/installed-tool-inventory/legacy-tag-and-directory-fallbacks", test_legacy_tag_and_directory_fallbacks);
        Test.add_func ("/installed-tool-inventory/vdf-internal-and-display-title-fallbacks", test_vdf_fallbacks);
        Test.add_func ("/installed-tool-inventory/latest-and-variant-directories", test_latest_and_variant_directories);
        Test.add_func ("/installed-tool-inventory/job-usage-identity-follows-installed-entry", test_job_usage_identity);
        Test.add_func ("/installed-tool-inventory/steam-tinker-launch-usage", test_steam_tinker_launch_usage);
        Test.add_func ("/installed-tool-inventory/queries-are-cached-and-invalidation-refreshes", test_cached_queries_and_refresh);
        Test.add_func ("/installed-tool-inventory/groups-are-isolated", test_group_isolation);
        Test.add_func ("/installed-tool-inventory/ignores-symlinked-directories", test_ignores_symlinked_directories);
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
            Category.PROTON, SourceType.GITHUB, id, title, "", endpoint, "https://example.test/source", 1,
            {
                new VariantDefinition ("default", "default", "$release_name", true),
                new VariantDefinition ("arm", "Arm 64", "$release_name-arm", false)
            },
            { InstallLayout.template ("default", "$release_name") }
        );
    }

    private Tools.ProviderTool add_tool (Group group, ProviderDefinition definition) {
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

    private void save_metadata (
        string path,
        string provider_id = "",
        string tool_id = "",
        string launcher_id = "",
        string tag = "",
        string variant_id = "",
        string release_id = ""
    ) {
        var metadata = ProtonPlus.Utils.Metadata.load (path);
        metadata.provider_id = provider_id;
        metadata.tool_id = tool_id;
        metadata.launcher_id = launcher_id;
        metadata.tag = tag;
        metadata.variant_id = variant_id;
        metadata.release_id = release_id;
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
        assert (tool.release_catalog != null);
        tool.release_catalog.releases.add (release ("release-name", "legacy-tag"));

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
        var internal_entries = internal_group.get_installed_tool_snapshot ();
        InstalledToolEntry? internal_entry = null;
        foreach (var entry in internal_entries) {
            if (entry.path == internal_path)
                internal_entry = entry;
        }
        assert (internal_entry != null);
        assert (((!) internal_entry).internal_title == "Internal Match");
        assert (((!) internal_entry).display_title == "Different Display");

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
        var display_entries = display_group.get_installed_tool_snapshot ();
        InstalledToolEntry? display_entry = null;
        foreach (var entry in display_entries) {
            if (entry.path == display_path)
                display_entry = entry;
        }
        assert (display_entry != null);
        assert (((!) display_entry).internal_title == "Internal Usage Name");
        assert (((!) display_entry).display_title == "Display Match");

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
        assert (tool.release_catalog != null);
        tool.release_catalog.releases.add (release ("v1"));
        value.refresh_installed_state ();
        assert (tool.is_installed ());

        assert (delete_directory (root));
    }

    private void test_job_usage_identity () {
        var root = temporary_directory ();
        var managed_root = Path.build_filename (root, "compatibilitytools.d");
        assert (ProtonPlus.Utils.Filesystem.create_directory (managed_root));
        var launcher = new InventorySteam (root);
        var value = new Group ("Fixture group", "", "/compatibilitytools.d", launcher, "proton");
        value.tools = new Gee.LinkedList<Tool> ();
        var tool = add_tool (value, definition ("runner", "Runner"));
        launcher.groups = { value };

        var latest_release = release ("v1");
        latest_release.variants.add (new ProtonPlus.Models.Variant (
            "arm", "Arm 64", "$release_name-arm", false,
            "https://example.test/fixture-arm.tar.gz"
        ));
        var job = new ProtonPlus.Services.InstallJob (
            latest_release, tool, ProtonPlus.Services.InstallJob.Mode.LATEST
        );
        job.set_selected_variant ("Arm 64", null, "arm");

        var physical_path = Path.build_filename (managed_root, "Runner Latest-Arm_64");
        assert (job.install_location == physical_path);
        // With no cached installed entry, retain the legacy physical-directory fallback.
        assert (job.get_usage_identifier () == "Runner Latest-Arm_64");

        assert (ProtonPlus.Utils.Filesystem.create_directory (physical_path));
        write_vdf (physical_path, "Runner Latest", "Runner Latest");
        save_metadata (
            physical_path, tool.provider_id, tool.id, launcher.tool_target_id,
            "v1", "arm", "fixture-release"
        );

        launcher.default_compatibility_tool = "Runner Latest";
        var active_profile = new SteamProfile (
            launcher, "Active", "76561197960265729",
            Path.build_filename (root, "userdata", "1")
        );
        var explicit_game = new ProtonPlus.Models.Games.Steam.non_steam (
            1, "Explicit game", "", "Runner Latest", launcher
        );
        explicit_game.is_native = false;
        active_profile.non_steam_games.append (explicit_game);
        launcher.profiles.append (active_profile);
        launcher.profile = active_profile;
        launcher.games.append (explicit_game);
        var default_game = new ProtonPlus.Models.Games.Steam (
            2, "Default game", "missing-default", 0, root, launcher
        );
        default_game.compatibility_tool = "Default";
        default_game.is_native = false;
        launcher.games.append (default_game);
        var native_game = new ProtonPlus.Models.Games.Steam (
            3, "Native game", "missing-native", 0, root, launcher
        );
        native_game.compatibility_tool = "Default";
        native_game.is_native = true;
        launcher.games.append (native_game);
        var other_profile = new SteamProfile (
            launcher, "Other", "76561197960265730",
            Path.build_filename (root, "userdata", "2")
        );
        var other_profile_game = new ProtonPlus.Models.Games.Steam.non_steam (
            4, "Other profile game", "", "Runner Latest", launcher
        );
        other_profile_game.is_native = false;
        other_profile.non_steam_games.append (other_profile_game);
        launcher.profiles.append (other_profile);

        value.refresh_installed_state ();
        var generation = value.installed_tool_inventory.refresh_generation;
        assert (job.get_usage_identifier () == "Runner Latest");
        assert (value.installed_tool_inventory.refresh_generation == generation);
        var usage_games = launcher.get_compatibility_tool_usage_games (job.get_usage_identifier ());
        assert (usage_games.size == 3);
        assert (usage_games[0] == explicit_game);
        assert (usage_games[1] == default_game);
        assert (usage_games[2] == other_profile_game);
        assert (launcher.get_compatibility_tool_usage_count (job.get_usage_identifier ()) == 3);
        assert (tool.is_used ());
        assert (job.install_location == physical_path);

        assert (FileUtils.remove (Path.build_filename (physical_path, "compatibilitytool.vdf")) == 0);
        value.refresh_installed_state ();
        assert (job.get_usage_identifier () == "Runner Latest-Arm_64");
        assert (job.install_location == physical_path);

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
        var job = new ProtonPlus.Services.InstallJob (
            release ("SteamTinkerLaunch"), tool,
            ProtonPlus.Services.InstallJob.Mode.STEAM_TINKER_LAUNCH, null, root
        );
        assert (job.get_usage_identifier () == "Proton-stl");

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

    private void test_ignores_symlinked_directories () {
        var root = temporary_directory ();
        var external_root = temporary_directory ();
        var launcher = new InventoryLauncher (root);
        var value = group (launcher);
        var tool = add_tool (value, definition ("linked", "Linked Tool"));
        var external_tool = Path.build_filename (external_root, "Linked Tool");
        var linked_tool = Path.build_filename (root, "Linked Tool");
        var linked_root = Path.build_filename (root, "linked-root");
        assert (ProtonPlus.Utils.Filesystem.create_directory (external_tool));
        save_metadata (external_tool, tool.provider_id, tool.id, launcher.instance_id);
        assert (Posix.symlink (external_tool, linked_tool) == 0);
        assert (Posix.symlink (external_root, linked_root) == 0);

        value.refresh_installed_state ();
        assert (!tool.is_installed ());
        assert (value.get_installed_tool_snapshot ().size == 1);
        assert (value.get_installed_tool_snapshot ()[0].path == root);

        var linked_root_launcher = new InventoryLauncher (linked_root);
        var linked_root_group = group (linked_root_launcher);
        var linked_root_tool = add_tool (linked_root_group, definition ("linked", "Linked Tool"));
        linked_root_group.refresh_installed_state ();
        assert (!linked_root_tool.is_installed ());
        assert (linked_root_group.get_installed_tool_snapshot ().size == 0);

        assert (Posix.unlink (linked_tool) == 0);
        assert (Posix.unlink (linked_root) == 0);
        assert (delete_directory (root));
        assert (delete_directory (external_root));
    }
}
