namespace AppTests.FaugusLauncherTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Launchers;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Models.Tools;
    using ProtonPlus.Providers.Sources;
    using ProtonPlus.Services;

    private class CountingReleaseSource : Object, ReleaseSource {
        public int requests { get; private set; default = 0; }

        public async ReleasePageResult fetch_page (
            ProviderDefinition definition,
            int requested_page,
            int limit
        ) {
            requests++;
            var releases = new Gee.LinkedList<Release> ();
            releases.add (release ("fixture-release", "fixture-release-id", "fixture-tag"));
            return ReleasePageResult.success (new ReleasePage (releases, requested_page + 1, false));
        }
    }

    private class RecordingRestartChange : Object, SteamChangeRecorder {
        public Gee.List<SteamChangeReceipt> receipts = new Gee.ArrayList<SteamChangeReceipt> ();
        public SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            receipts.add (receipt);
            return SteamRestartRecordResult.ADDED;
        }
    }

    public void register_tests () {
        Test.add_func ("/faugus/identities-and-detection", test_identities_and_detection);
        Test.add_func ("/faugus/groups-providers-and-layouts", test_groups_providers_and_layouts);
        Test.add_func ("/faugus/shared-installed-state-and-operations", test_shared_installed_state_and_operations);
        Test.add_func ("/faugus/bulk-updates-deduplicate-shared-targets", test_bulk_updates_deduplicate_shared_targets);
        Test.add_func ("/faugus/lifecycle-receipt-uses-shared-steam-target", test_lifecycle_receipt_uses_shared_steam_target);
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-faugus-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create Faugus test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        var deleted = false;
        Utils.Filesystem.delete_directory.begin (path, (obj, result) => {
            deleted = Utils.Filesystem.delete_directory.end (result);
            loop.quit ();
        });
        loop.run ();
        return deleted;
    }

    private bool initialize_launcher (Launcher launcher) {
        var launchers = new Gee.LinkedList<Launcher> ();
        launchers.add (launcher);
        var loop = new MainLoop ();
        var initialized = false;
        Launcher.initialize_launchers.begin (launchers, new ProviderRegistry (), (obj, result) => {
            initialized = Launcher.initialize_launchers.end (result);
            loop.quit ();
        });
        loop.run ();
        return initialized;
    }

    private ReturnCode check_for_updates (List<Launcher> launchers) {
        var loop = new MainLoop ();
        var result = ReturnCode.FILESYSTEM_ERROR;
        InstallationService.instance.check_for_updates.begin (launchers, (obj, response) => {
            result = InstallationService.instance.check_for_updates.end (response);
            loop.quit ();
        });
        loop.run ();
        return result;
    }

    private ReturnCode remove (InstallJob job) {
        var loop = new MainLoop ();
        var result = ReturnCode.FILESYSTEM_ERROR;
        job.remove.begin (false, (obj, response) => {
            result = job.remove.end (response);
            loop.quit ();
        });
        loop.run ();
        return result;
    }

    private FaugusLauncher faugus (
        Launcher.InstallationTypes installation_type,
        string home,
        string host_data,
        string config,
        string data,
        string state
    ) {
        return new FaugusLauncher (installation_type, home, host_data, config, data, state);
    }

    private ProviderDefinition definition (string provider_id) {
        var value = new ProviderRegistry ().get_by_id (provider_id);
        assert (value != null);
        return (!) value;
    }

    private ProviderTool provider_tool (Group group, ProviderDefinition value) {
        var tool = ProviderCatalog.create_tool (value, group);
        assert (tool != null);
        group.tools.add ((!) tool);
        return (!) tool;
    }

    private ProviderTool catalog_tool (
        Group group,
        ProviderDefinition definition,
        ReleaseSource source
    ) {
        var tool = new ProviderTool.with_catalog (
            definition, source, group, definition.get_install_layout (group.launcher.tool_target_family_id)
        );
        group.tools.add (tool);
        return tool;
    }

    private Release release (string title, string upstream_id, string source_tag) {
        return new Release (
            title, "", "", new Models.Assets.Asset (
                "%s.tar.gz".printf (title), "https://example.test/%s.tar.gz".printf (title)
            ), "", 0, upstream_id, source_tag
        );
    }

    private void save_metadata (
        string path,
        string provider_id,
        string tool_id,
        string target_id,
        string tag = ""
    ) {
        var metadata = Utils.Metadata.load (path);
        metadata.provider_id = provider_id;
        metadata.tool_id = tool_id;
        metadata.launcher_id = target_id;
        metadata.tag = tag;
        assert (metadata.save (path));
    }

    private void test_identities_and_detection () {
        var root = temporary_directory ();
        var home = Path.build_filename (root, "home");
        var host_data = Path.build_filename (root, "host-data");
        var config = Path.build_filename (root, "config");
        var data = Path.build_filename (root, "data");
        var state = Path.build_filename (root, "state");
        var target = Path.build_filename (host_data, "Steam", "compatibilitytools.d");
        assert (Utils.Filesystem.create_directory (target));

        var system = faugus (Launcher.InstallationTypes.SYSTEM, home, host_data, config, data, state);
        var flatpak = faugus (Launcher.InstallationTypes.FLATPAK, home, host_data, config, data, state);
        assert (!system.installed);
        assert (!flatpak.installed);
        assert (system.instance_id == "faugus-system");
        assert (flatpak.instance_id == "faugus-flatpak");
        assert (system.tool_target_family_id == "steam");
        assert (flatpak.tool_target_family_id == "steam");
        assert (system.tool_target_id == "steam-system");
        assert (flatpak.tool_target_id == "steam-system");
        assert (system.directory == Path.build_filename (host_data, "Steam"));

        var steam = new Launcher ("Steam", Launcher.InstallationTypes.SYSTEM, "", {}, "steam");
        assert (steam.instance_id == "steam-system");
        assert (steam.tool_target_family_id == steam.family_id);
        assert (steam.tool_target_id == steam.instance_id);

        var system_marker = Path.build_filename (config, "faugus-launcher");
        assert (Utils.Filesystem.create_directory (system_marker));
        system = faugus (Launcher.InstallationTypes.SYSTEM, home, host_data, config, data, state);
        flatpak = faugus (Launcher.InstallationTypes.FLATPAK, home, host_data, config, data, state);
        assert (system.installed);
        assert (!flatpak.installed);

        assert (DirUtils.remove (system_marker) == 0);
        var flatpak_marker = Path.build_filename (
            home, ".var", "app", FaugusLauncher.FLATPAK_ID, "config", "faugus-launcher"
        );
        assert (Utils.Filesystem.create_directory (flatpak_marker));
        system = faugus (Launcher.InstallationTypes.SYSTEM, home, host_data, config, data, state);
        flatpak = faugus (Launcher.InstallationTypes.FLATPAK, home, host_data, config, data, state);
        assert (!system.installed);
        assert (flatpak.installed);

        assert (delete_directory (root));
    }

    private void test_groups_providers_and_layouts () {
        var root = temporary_directory ();
        var home = Path.build_filename (root, "home");
        var host_data = Path.build_filename (root, "host-data");
        var config = Path.build_filename (root, "config");
        var data = Path.build_filename (root, "data");
        var state = Path.build_filename (root, "state");
        assert (Utils.Filesystem.create_directory (Path.build_filename (config, "faugus-launcher")));

        var launcher = faugus (Launcher.InstallationTypes.SYSTEM, home, host_data, config, data, state);
        var target = Path.build_filename (host_data, "Steam", "compatibilitytools.d");
        assert (!FileUtils.test (target, FileTest.IS_DIR));
        assert (initialize_launcher (launcher));
        assert (FileUtils.test (target, FileTest.IS_DIR));
        assert (launcher.groups.length == 1);
        assert (launcher.groups[0].id == "proton");
        assert (launcher.groups[0].directory == "/compatibilitytools.d");
        assert (!launcher.has_library_support);

        var provider_ids = new Gee.HashSet<string> ();
        foreach (var tool in launcher.groups[0].tools) {
            var provider = tool as ProviderTool;
            assert (provider != null);
            provider_ids.add (((!) provider).provider_id);
        }
        assert (provider_ids.size == 4);
        assert (provider_ids.contains ("proton-ge"));
        assert (provider_ids.contains ("proton-em"));
        assert (provider_ids.contains ("proton-cachyos"));
        assert (provider_ids.contains ("dw-proton"));
        assert (!launcher.supports_provider_definition (definition ("luxtorpeda")));

        var steam = new Launcher (
            "Steam", Launcher.InstallationTypes.SYSTEM, "",
            { Path.build_filename (host_data, "Steam") }, "steam"
        );
        var steam_group = new Group ("Proton", "", "/compatibilitytools.d", steam, "proton");
        steam_group.tools = new Gee.LinkedList<Tool> ();
        var steam_ge = provider_tool (steam_group, definition ("proton-ge"));
        ProviderTool? faugus_ge = null;
        foreach (var tool in launcher.groups[0].tools) {
            if (tool.provider_id == "proton-ge")
                faugus_ge = tool as ProviderTool;
        }
        assert (faugus_ge != null);
        assert (((!) faugus_ge).get_directory_name ("GE-Proton10.1") == steam_ge.get_directory_name ("GE-Proton10.1"));
        assert (((!) faugus_ge).get_directory_name ("GE-Proton10-1") == steam_ge.get_directory_name ("GE-Proton10-1"));

        assert (delete_directory (root));
    }

    private void test_shared_installed_state_and_operations () {
        var root = temporary_directory ();
        var home = Path.build_filename (root, "home");
        var host_data = Path.build_filename (root, "host-data");
        var config = Path.build_filename (root, "config");
        var data = Path.build_filename (root, "data");
        var state = Path.build_filename (root, "state");
        var target = Path.build_filename (host_data, "Steam", "compatibilitytools.d");
        assert (Utils.Filesystem.create_directory (target));

        var faugus_launcher = faugus (Launcher.InstallationTypes.SYSTEM, home, host_data, config, data, state);
        var faugus_group = new Group ("Proton", "", "/compatibilitytools.d", faugus_launcher, "proton");
        faugus_group.tools = new Gee.LinkedList<Tool> ();
        var faugus_ge = provider_tool (faugus_group, definition ("proton-ge"));

        var steam_launcher = new Launcher (
            "Steam", Launcher.InstallationTypes.SYSTEM, "",
            { Path.build_filename (host_data, "Steam") }, "steam"
        );
        var steam_group = new Group ("Proton", "", "/compatibilitytools.d", steam_launcher, "proton");
        steam_group.tools = new Gee.LinkedList<Tool> ();
        var steam_ge = provider_tool (steam_group, definition ("proton-ge"));
        assert (faugus_ge.id == "steam-system/proton/proton-ge");
        assert (faugus_ge.id == steam_ge.id);

        var install = Path.build_filename (target, "Proton-GE Latest");
        assert (Utils.Filesystem.create_directory (install));
        save_metadata (install, steam_ge.provider_id, steam_ge.id, steam_launcher.tool_target_id);
        var metadata_before = Utils.Filesystem.get_file_content (Path.build_filename (install, ".protonplus"));
        faugus_group.refresh_installed_state ();
        assert (faugus_ge.is_installed ());
        assert (Utils.Filesystem.get_file_content (Path.build_filename (install, ".protonplus")) == metadata_before);

        save_metadata (install, faugus_ge.provider_id, faugus_ge.id, faugus_launcher.tool_target_id);
        steam_group.refresh_installed_state ();
        assert (steam_ge.is_installed ());

        var foreign_launcher = new Launcher (
            "Foreign", Launcher.InstallationTypes.SYSTEM, "",
            { Path.build_filename (host_data, "Steam") }, "lutris"
        );
        var foreign_group = new Group ("Proton", "", "/compatibilitytools.d", foreign_launcher, "proton");
        foreign_group.tools = new Gee.LinkedList<Tool> ();
        var foreign_ge = provider_tool (foreign_group, definition ("proton-ge"));
        foreign_group.refresh_installed_state ();
        assert (!foreign_ge.is_installed ());

        var same_release = release ("GE-Proton10.1", "release-one", "release-one");
        same_release.variants.add (new Models.Variant ("default", "default", "", true));
        same_release.variants.add (new Models.Variant ("alternate", "alternate", "", false));
        var steam_job = new InstallJob (same_release, steam_ge);
        var faugus_job = new InstallJob (same_release, faugus_ge);
        assert (steam_job.operation_id == faugus_job.operation_id);
        assert (steam_job.operation_id == "steam-system/steam-system/proton/proton-ge/versioned/release-one/default");

        var alternate_variant_job = new InstallJob (same_release, faugus_ge);
        alternate_variant_job.set_selected_variant ("alternate", new Models.Assets.Asset (
            "alternate.tar.gz", "https://example.test/alternate.tar.gz"
        ));
        assert (alternate_variant_job.operation_id != faugus_job.operation_id);

        var alternate_release = release ("GE-Proton10.2", "release-two", "release-two");
        var alternate_job = new InstallJob (alternate_release, faugus_ge);
        assert (alternate_job.operation_id != faugus_job.operation_id);

        var manager = Utils.DownloadManager.instance;
        assert (manager.active_downloads.size == 0);
        manager.add_download (steam_job);
        manager.add_download (faugus_job);
        assert (manager.active_downloads.size == 1);
        assert (manager.is_downloading (faugus_job));
        assert (remove (faugus_job) == ReturnCode.OPERATION_IN_PROGRESS);
        manager.remove_download (steam_job);

        assert (delete_directory (root));
    }

    private void test_lifecycle_receipt_uses_shared_steam_target () {
        var root = temporary_directory ();
        var home = Path.build_filename (root, "home");
        var host_data = Path.build_filename (root, "host-data");
        var config = Path.build_filename (root, "config");
        var data = Path.build_filename (root, "data");
        var state = Path.build_filename (root, "state");
        var shared_root = Path.build_filename (host_data, "Steam");
        assert (Utils.Filesystem.create_directory (Path.build_filename (shared_root, "compatibilitytools.d")));
        var launcher = faugus (Launcher.InstallationTypes.SYSTEM, home, host_data, config, data, state);
        var group = new Group ("Proton", "", "/compatibilitytools.d", launcher, "proton");
        group.tools = new Gee.LinkedList<Tool> ();
        var runner = provider_tool (group, definition ("proton-ge"));
        var job = new InstallJob (release ("Fixture Runner", "fixture", "fixture"), runner,
            InstallJob.Mode.VERSIONED, Path.build_filename (shared_root, "compatibilitytools.d", "Fixture Runner"));
        var recorder = new RecordingRestartChange ();
        InstallationService.instance.configure_steam_change_recorder (recorder);

        InstallationService.instance.record_completed_update (job);
        assert (recorder.receipts.size == 1);
        assert (recorder.receipts.get (0).kind == SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED);
        var native_target = SteamRestartTarget.for_native (shared_root, "Steam", "steam.desktop");
        assert (recorder.receipts.get (0).target.id == native_target.id);
        InstallationService.instance.record_completed_update (job);
        assert (recorder.receipts.size == 1);

        InstallationService.reset_lifecycle_configuration_for_tests ();
        assert (delete_directory (root));
    }

    private void test_bulk_updates_deduplicate_shared_targets () {
        var root = temporary_directory ();
        var host_data = Path.build_filename (root, "host-data");
        var target = Path.build_filename (host_data, "Steam");
        assert (Utils.Filesystem.create_directory (target));
        var runner_directory = Path.build_filename (target, "Fixture Runner Latest");
        assert (Utils.Filesystem.create_directory (runner_directory));

        var faugus_launcher = faugus (
            Launcher.InstallationTypes.SYSTEM,
            Path.build_filename (root, "home"),
            host_data,
            Path.build_filename (root, "config"),
            Path.build_filename (root, "data"),
            Path.build_filename (root, "state")
        );
        var steam_launcher = new Launcher (
            "Steam", Launcher.InstallationTypes.SYSTEM, "", { target }, "steam"
        );
        var provider = new ProviderDefinition (
            Category.PROTON, SourceType.GITHUB, "fixture-provider", "Fixture Runner", "",
            "https://example.test/releases", 1,
            { new VariantDefinition ("default", "default", "$release_name", true) },
            { InstallLayout.template ("default", "$release_name"), InstallLayout.template ("steam", "$release_name") }
        );

        var steam_group = new Group ("Proton", "", "", steam_launcher, "proton");
        steam_group.tools = new Gee.LinkedList<Tool> ();
        var faugus_group = new Group ("Proton", "", "", faugus_launcher, "proton");
        faugus_group.tools = new Gee.LinkedList<Tool> ();
        steam_launcher.groups = { steam_group };
        faugus_launcher.groups = { faugus_group };
        var steam_source = new CountingReleaseSource ();
        var faugus_source = new CountingReleaseSource ();
        var steam_runner = catalog_tool (steam_group, provider, steam_source);
        var faugus_runner = catalog_tool (faugus_group, provider, faugus_source);
        assert (steam_runner.id == faugus_runner.id);
        save_metadata (runner_directory, steam_runner.provider_id, steam_runner.id, steam_launcher.tool_target_id, "fixture-tag");

        var launchers = new List<Launcher> ();
        launchers.append (steam_launcher);
        launchers.append (faugus_launcher);
        assert (check_for_updates (launchers) == ReturnCode.NOTHING_TO_UPDATE);
        assert (steam_source.requests + faugus_source.requests == 1);

        assert (delete_directory (root));
    }
}
