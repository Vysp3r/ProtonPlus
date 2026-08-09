namespace AppTests.SteamCompatibilityToolDiscoveryTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Services;

    private class StoppedSessionFixture : Object, SteamSessionBackend {
        public string? get_boot_id () { return "discovery-test"; }
        public int64 get_monotonic_time_usec () { return 1000000; }
        public int64 get_clock_ticks_per_second () { return 100; }
        public NativeProcessQuery query_native_processes () { return new NativeProcessQuery (true); }
        public FlatpakProcessQuery query_flatpak_processes () { return new FlatpakProcessQuery (true); }
        public SteamDesktopEntry? find_desktop_entry (string? id) { return null; }
        public bool is_steamos_gaming_mode () { return false; }
    }

    public void register_tests () {
        Test.add_func ("/steam-compatibility-tool-discovery/native-distro-paths-and-projection", test_native_distro_paths_and_projection);
        Test.add_func ("/steam-compatibility-tool-discovery/steam-library-app-identities", test_steam_library_app_identities);
        Test.add_func ("/steam-compatibility-tool-discovery/external-tools-stay-out-of-managed-inventory", test_external_tools_stay_out_of_inventory);
        Test.add_func ("/steam-compatibility-tool-discovery/flatpak-launcher-uses-extension-roots-only", test_flatpak_launcher_uses_extension_roots_only);
        Test.add_func ("/steam-compatibility-tool-discovery/missing-denied-and-symlink-roots-are-safe", test_unavailable_and_symlink_roots);
        Test.add_func ("/steam-compatibility-tool-discovery/deduplication-follows-steam-root-precedence", test_deduplication_precedence);
        Test.add_func ("/steam-compatibility-tool-discovery/exact-title-persistence-and-disappearance", test_persistence_and_disappearance);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-steam-tool-discovery-test-XXXXXX");
        } catch (FileError error) {
            critical ("Could not create temporary directory: %s", error.message);
            assert_not_reached ();
        }
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        var deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (object, result) => {
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (result);
            loop.quit ();
        });
        loop.run ();
        return deleted;
    }

    private string create_tool (
        string root,
        string directory_name,
        string internal_title,
        string display_title,
        bool proton = true
    ) {
        var path = Path.build_filename (root, directory_name);
        assert (ProtonPlus.Utils.Filesystem.create_directory (path));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (path, "compatibilitytool.vdf"),
            "\"compatibilitytools\"\n{\n\t\"compat_tools\"\n\t{\n\t\t\"%s\"\n\t\t{\n\t\t\t\"display_name\"\t\"%s\"\n\t\t}\n\t}\n}\n".printf (
                internal_title, display_title
            )
        );
        if (proton) {
            var proton_path = Path.build_filename (path, "proton");
            ProtonPlus.Utils.Filesystem.create_file (proton_path, "#!/bin/sh\n");
            assert (Posix.chmod (proton_path, 0755) == 0);
        }
        return path;
    }

    private string create_steam_library_tool (
        string root,
        string directory_name,
        bool proton
    ) {
        var path = Path.build_filename (root, directory_name);
        assert (ProtonPlus.Utils.Filesystem.create_directory (path));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (path, "toolmanifest.vdf"),
            "\"manifest\" { \"version\" \"2\" }"
        );
        if (proton) {
            var proton_path = Path.build_filename (path, "proton");
            ProtonPlus.Utils.Filesystem.create_file (proton_path, "#!/bin/sh\n");
            assert (Posix.chmod (proton_path, 0755) == 0);
        }
        return path;
    }

    private string create_flatpak_extension_tool (
        string runtime_root,
        string extension_id,
        string deployment,
        string directory_name,
        string internal_title
    ) {
        var tools_root = Path.build_filename (
            runtime_root, extension_id, "x86_64", "stable", deployment,
            "files", "share", "steam", "compatibilitytools.d"
        );
        assert (ProtonPlus.Utils.Filesystem.create_directory (tools_root));
        return create_tool (tools_root, directory_name, internal_title, directory_name);
    }

    private ProtonPlus.Models.Launchers.Steam steam_with_discovery (
        string steam_root,
        Launcher.InstallationTypes installation_type,
        SteamCompatibilityToolDiscovery discovery
    ) {
        var steam = new ProtonPlus.Models.Launchers.Steam (installation_type, null, discovery);
        steam.directory = steam_root;
        steam.installed = true;
        steam.compatibility_tool_hashtable = new HashTable<uint, string> (null, null);
        return steam;
    }

    private CompatibilityTool? find (Gee.Iterable<CompatibilityTool> tools, string internal_title) {
        foreach (var tool in tools) {
            if (tool.internal_title == internal_title)
                return tool;
        }
        return null;
    }

    private void test_native_distro_paths_and_projection () {
        var root = temporary_directory ();
        var steam_root = Path.build_filename (root, "Steam");
        var inspection_root = Path.build_filename (root, "host-usr-tools");
        assert (ProtonPlus.Utils.Filesystem.create_directory (steam_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (inspection_root));
        create_tool (inspection_root, "CachyOS Proton", "proton-cachyos", "Proton-CachyOS");

        var logical_root = "/usr/share/steam/compatibilitytools.d";
        var discovery = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, true, logical_root, inspection_root, {}
        );
        var steam = steam_with_discovery (steam_root, Launcher.InstallationTypes.SYSTEM, discovery);
        steam.refresh_compatibility_tools ();

        var tool = steam.find_compatibility_tool ("proton-cachyos");
        assert (tool != null);
        assert (((!) tool).display_title == "Proton-CachyOS");
        assert (((!) tool).path == Path.build_filename (logical_root, "CachyOS Proton"));
        assert (((!) tool).inspection_path == Path.build_filename (inspection_root, "CachyOS Proton"));
        assert (((!) tool).externally_managed);
        assert (((!) tool).runtime_kind == CompatibilityToolRuntimeKind.PROTON);
        assert (steam.can_assign_compatibility_tool ("proton-cachyos"));
        assert (find (steam.get_assignable_compatibility_tools (), "proton-cachyos") == tool);
        assert (steam.resolve_effective_proton_executable ("proton-cachyos")
            == Path.build_filename (logical_root, "CachyOS Proton", "proton"));
        assert (!((!) steam.resolve_effective_proton_executable ("proton-cachyos")).has_prefix ("/run/host/"));

        var package_root_steam = steam_with_discovery (
            "/usr/share/steam", Launcher.InstallationTypes.SYSTEM,
            new SteamCompatibilityToolDiscovery (
                Launcher.InstallationTypes.SYSTEM, false, logical_root, inspection_root, {}
            )
        );
        var package_group = new Group (
            "Proton", "", "/compatibilitytools.d", package_root_steam, "proton"
        );
        var package_managed_root = package_root_steam.get_managed_tool_directories (package_group).nth_data (0);
        assert (package_managed_root == Path.build_filename (
            Environment.get_user_data_dir (), "Steam", "compatibilitytools.d"
        ));
        assert (!package_managed_root.has_prefix ("/usr/"));
        package_group.tools = new Gee.LinkedList<Tool> ();
        var package_provider_tool = ProviderCatalog.create_tool (definition (), package_group);
        assert (package_provider_tool != null);
        package_group.tools.add ((!) package_provider_tool);
        var release = new Release (
            "Fixture release", "", "",
            new ProtonPlus.Models.Assets.Asset (
                "fixture.tar.gz", "https://example.test/fixture.tar.gz"
            ),
            "", 0, "fixture-release"
        );
        var install_job = new InstallJob (
            release, (!) package_provider_tool, InstallJob.Mode.VERSIONED
        );
        assert (install_job.install_location.has_prefix (package_managed_root + "/"));
        assert (!install_job.install_location.has_prefix ("/usr/"));

        assert (delete_directory (root));
    }

    private ProviderDefinition definition () {
        return new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "external-match", "Proton-CachyOS", "",
            "https://example.test/releases", "https://example.test/source", 1,
            { new VariantDefinition ("default", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name") }
        );
    }

    private void test_steam_library_app_identities () {
        var root = temporary_directory ();
        var proton_path = create_steam_library_tool (root, "Proton 11.0", true);
        var runtime_path = create_steam_library_tool (root, "SteamLinuxRuntime_4", false);
        var discovery = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false,
            Path.build_filename (root, "system"), Path.build_filename (root, "system"), {}
        );

        discovery.add_steam_library_app (
            proton_path, 4628710, "proton_11", "Proton 11.0",
            CompatibilityToolRuntimeKind.PROTON
        );
        discovery.add_steam_library_app (
            runtime_path, 4183110, "steamlinuxruntime_4", "Steam Linux Runtime 4.0",
            CompatibilityToolRuntimeKind.NATIVE
        );

        var proton = find (discovery.get_snapshot (), "proton_11");
        var runtime = find (discovery.get_snapshot (), "steamlinuxruntime_4");
        assert (proton != null && ((!) proton).externally_managed);
        assert (runtime != null && ((!) runtime).externally_managed);
        assert (discovery.remains_available ((!) proton));
        assert (discovery.remains_available ((!) runtime));

        assert (FileUtils.remove (Path.build_filename (proton_path, "toolmanifest.vdf")) == 0);
        assert (!discovery.remains_available ((!) proton));
        assert (delete_directory (root));
    }

    private void test_external_tools_stay_out_of_inventory () {
        var root = temporary_directory ();
        var steam_root = Path.build_filename (root, "Steam");
        var managed_root = Path.build_filename (steam_root, "compatibilitytools.d");
        var inspection_root = Path.build_filename (root, "system-tools");
        assert (ProtonPlus.Utils.Filesystem.create_directory (managed_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (inspection_root));
        create_tool (inspection_root, "External", "external-match", "Proton-CachyOS");

        var discovery = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false, "/usr/share/steam/compatibilitytools.d",
            inspection_root, {}
        );
        var steam = steam_with_discovery (steam_root, Launcher.InstallationTypes.SYSTEM, discovery);
        var group = new Group ("Proton", "", "/compatibilitytools.d", steam, "proton");
        group.tools = new Gee.LinkedList<Tool> ();
        var provider_tool = ProviderCatalog.create_tool (definition (), group);
        assert (provider_tool != null);
        group.tools.add ((!) provider_tool);
        steam.groups = { group };

        steam.refresh_compatibility_tools ();
        group.refresh_installed_state ();
        assert (steam.find_compatibility_tool ("external-match") != null);
        foreach (var entry in group.get_installed_tool_snapshot ())
            assert (!entry.path.has_prefix (inspection_root));
        assert (!((!) provider_tool).is_installed ());
        assert (((!) provider_tool).resolved_installed_entry == null);
        var managed_directories = steam.get_managed_tool_directories (group);
        assert (managed_directories.length () == 1);
        assert (managed_directories.nth_data (0) == managed_root);

        assert (delete_directory (root));
    }

    private void test_flatpak_launcher_uses_extension_roots_only () {
        var root = temporary_directory ();
        var steam_root = Path.build_filename (root, "FlatpakSteam");
        var distro_root = Path.build_filename (root, "host-usr-tools");
        var user_runtime = Path.build_filename (root, "user-runtime");
        var system_runtime = Path.build_filename (root, "system-runtime");
        assert (ProtonPlus.Utils.Filesystem.create_directory (steam_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (distro_root));
        create_tool (distro_root, "HostOnly", "host-only", "Host only");
        create_flatpak_extension_tool (
            user_runtime, "com.valvesoftware.Steam.CompatibilityTool.User", "commit-a",
            "User Tool", "user-extension"
        );
        create_flatpak_extension_tool (
            user_runtime, "com.valvesoftware.Steam.CompatibilityTool.User", "commit-z",
            "Active User Tool", "user-extension"
        );
        var user_branch = Path.build_filename (
            user_runtime, "com.valvesoftware.Steam.CompatibilityTool.User",
            "x86_64", "stable"
        );
        assert (Posix.symlink ("commit-z", Path.build_filename (user_branch, "active")) == 0);
        var utility_deployment = Path.build_filename (
            system_runtime, "com.valvesoftware.Steam.Utility.System",
            "x86_64", "stable", "commit-b"
        );
        assert (ProtonPlus.Utils.Filesystem.create_directory (utility_deployment));
        create_tool (utility_deployment, "files", "system-extension", "System Tool", false);

        var discovery = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.FLATPAK, false,
            "/usr/share/steam/compatibilitytools.d", distro_root,
            { user_runtime, system_runtime }
        );
        var steam = steam_with_discovery (steam_root, Launcher.InstallationTypes.FLATPAK, discovery);
        steam.refresh_compatibility_tools ();

        assert (steam.find_compatibility_tool ("host-only") == null);
        assert (steam.find_compatibility_tool ("user-extension") != null);
        assert (((!) steam.find_compatibility_tool ("user-extension")).display_title == "Active User Tool");
        assert (steam.find_compatibility_tool ("system-extension") != null);
        assert (((!) steam.find_compatibility_tool ("user-extension")).externally_managed);
        assert (((!) steam.find_compatibility_tool ("system-extension")).externally_managed);

        assert (delete_directory (root));
    }

    private void test_unavailable_and_symlink_roots () {
        var root = temporary_directory ();
        var real_root = Path.build_filename (root, "real-root");
        var symlink_root = Path.build_filename (root, "root-link");
        var child_target_root = Path.build_filename (root, "child-targets");
        assert (ProtonPlus.Utils.Filesystem.create_directory (real_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (child_target_root));
        var target = create_tool (child_target_root, "Target", "symlink-target", "Symlink target");
        assert (Posix.symlink (target, Path.build_filename (real_root, "Linked child")) == 0);
        assert (Posix.symlink (real_root, symlink_root) == 0);

        var missing = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false, "/logical", Path.build_filename (root, "missing"), {}
        );
        missing.discover_launcher_roots (Path.build_filename (root, "missing-managed"));
        assert (missing.get_snapshot ().size == 0);

        var root_link = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false, "/logical", symlink_root, {}
        );
        root_link.discover_launcher_roots (Path.build_filename (root, "missing-managed"));
        assert (root_link.get_snapshot ().size == 0);

        var child_link = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false, "/logical", real_root, {}
        );
        child_link.discover_launcher_roots (Path.build_filename (root, "missing-managed"));
        assert (child_link.get_snapshot ().size == 0);

        var denied_root = Path.build_filename (root, "denied");
        assert (ProtonPlus.Utils.Filesystem.create_directory (denied_root));
        assert (Posix.chmod (denied_root, 0000) == 0);
        var denied = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false, "/logical", denied_root, {}
        );
        denied.discover_launcher_roots (Path.build_filename (root, "missing-managed"));
        assert (Posix.chmod (denied_root, 0700) == 0);

        assert (delete_directory (root));
    }

    private void test_deduplication_precedence () {
        var root = temporary_directory ();
        var steam_root = Path.build_filename (root, "Steam");
        var managed_root = Path.build_filename (steam_root, "compatibilitytools.d");
        var system_root = Path.build_filename (root, "system-tools");
        assert (ProtonPlus.Utils.Filesystem.create_directory (managed_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (system_root));
        create_tool (managed_root, "Managed", "proton_11", "Managed winner");
        var external_path = create_steam_library_tool (system_root, "Proton 11.0", true);

        var discovery = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, true,
            "/usr/share/steam/compatibilitytools.d", system_root, {}
        );
        discovery.add_steam_library_app (
            external_path, 4628710, "proton_11", "Proton 11.0",
            CompatibilityToolRuntimeKind.PROTON
        );
        discovery.discover_launcher_roots (managed_root);
        var snapshot = discovery.get_snapshot ();
        assert (snapshot.size == 1);
        assert (snapshot[0].display_title == "Managed winner");
        assert (!snapshot[0].externally_managed);

        assert (delete_directory (root));
    }

    private void test_persistence_and_disappearance () {
        var root = temporary_directory ();
        var steam_root = Path.build_filename (root, "Steam");
        var config_root = Path.build_filename (steam_root, "config");
        var system_root = Path.build_filename (root, "system-tools");
        assert (ProtonPlus.Utils.Filesystem.create_directory (config_root));
        assert (ProtonPlus.Utils.Filesystem.create_directory (system_root));
        var tool_path = create_tool (
            system_root, "Distro Tool", "Exact Internal Title", "Friendly distro title"
        );
        var config_path = Path.build_filename (config_root, "config.vdf");
        ProtonPlus.Utils.Filesystem.create_file (
            config_path,
            "\"InstallConfigStore\"\n{\n\t\"Software\"\n\t{\n\t\t\"Valve\"\n\t\t{\n\t\t\t\"Steam\"\n\t\t\t{\n\t\t\t}\n\t\t}\n\t}\n}\n"
        );

        var discovery = new SteamCompatibilityToolDiscovery (
            Launcher.InstallationTypes.SYSTEM, false,
            "/usr/share/steam/compatibilitytools.d", system_root, {}
        );
        var steam = steam_with_discovery (steam_root, Launcher.InstallationTypes.SYSTEM, discovery);
        steam.refresh_compatibility_tools ();
        var sessions = new SteamSessionService (new StoppedSessionFixture ());
        var manager = new SteamRestartManager (
            sessions, new SteamRestartStateStore (Path.build_filename (root, "restart-state.json"))
        );
        var service = new SteamConfigurationService (sessions, manager);
        manager.configure_configuration_reconciler (service);
        SteamConfigurationService.configure (service);
        var game = new ProtonPlus.Models.Games.Steam (42, "Fixture", "Fixture", 0, root, steam);

        assert (game.change_compatibility_tool ("Exact Internal Title"));
        var changed = ProtonPlus.Utils.Filesystem.get_file_content (config_path);
        assert (changed.contains ("Exact Internal Title"));
        assert (!changed.contains ("Friendly distro title"));

        assert (FileUtils.remove (Path.build_filename (tool_path, "compatibilitytool.vdf")) == 0);
        assert (!steam.can_assign_compatibility_tool ("Exact Internal Title"));
        assert (!game.change_compatibility_tool ("Exact Internal Title"));
        steam.compatibility_tool_hashtable.set (42, "Exact Internal Title");
        steam.refresh_compatibility_tools ();
        var stale = steam.find_compatibility_tool ("Exact Internal Title");
        assert (stale != null);
        assert (!((!) stale).is_available);
        assert (!((!) stale).is_assignable);
        assert (((!) stale).display_title.contains ("Exact Internal Title"));
        assert (((!) stale).display_title != "Default");
        assert (find (steam.get_assignable_compatibility_tools (), "Exact Internal Title") == null);

        SteamConfigurationService.reset_configuration ();
        assert (delete_directory (root));
    }
}
