namespace AppTests.InstallerTransactionTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Services;

    private class FixtureJob : ProtonPlus.Services.InstallJob {
        private string fixture_path;
        private bool cancel_download;
        private bool fail_promotion;
        public int download_calls { get; private set; default = 0; }

        public FixtureJob (
            Models.Tools.ProviderTool runner,
            string location,
            string fixture_path,
            bool cancel_download = false,
            bool fail_promotion = false,
            ProtonPlus.Services.InstallJob.Mode mode = ProtonPlus.Services.InstallJob.Mode.VERSIONED,
            int64 download_size = 0,
            string digest = ""
        ) {
            base (new Release (
                "Fixture Runner", "", "", new Models.Assets.Asset (
                    "runner.zip", "https://fixtures.invalid/%s".printf (Path.get_basename (fixture_path)),
                    download_size, digest
                ),
                "", null, "fixture-release-id", "fixture-tag"
            ), runner, mode, location);
            this.fixture_path = fixture_path;
            this.cancel_download = cancel_download;
            this.fail_promotion = fail_promotion;
            release.variants.add (new Models.Variant (
                "fixture-default", "Default", "", true,
                "https://fixtures.invalid/%s".printf (Path.get_basename (fixture_path)),
                null,
                release.asset
            ));
        }

        public override async bool download_archive (string url, string path, out string? error_message) {
            download_calls++;
            if (cancel_download) {
                ProtonPlus.Utils.Filesystem.create_file (path, "partial download");
                canceled = true;
                error_message = "Download canceled";
                return false;
            }
            var copied = yield ProtonPlus.Utils.Filesystem.copy_file (fixture_path, path);
            error_message = copied ? null : "Could not copy fixture";
            return copied;
        }

        public override async bool promote_staged_installation (string staged_install_path) {
            if (fail_promotion)
                return false;
            return yield base.promote_staged_installation (staged_install_path);
        }
    }

    private class RecordingLauncher : Launcher {
        public string registered_path { get; private set; default = ""; }
        public string removed_path { get; private set; default = ""; }

        public RecordingLauncher () {
            base ("Recording launcher", InstallationTypes.SYSTEM, "", {}, "recording");
        }

        public override void register_compatibility_tool_from_path (string tool_path) {
            registered_path = tool_path;
        }

        public override void unregister_compatibility_tool_by_path (string tool_path) {
            removed_path = tool_path;
        }
    }

    private class RestartTargetLauncher : Launcher {
        private SteamRestartTarget target;
        public RestartTargetLauncher (string root) {
            base ("Steam fixture", InstallationTypes.SYSTEM, "", { root }, "steam-fixture");
            target = SteamRestartTarget.for_native (root);
        }
        public override SteamRestartTarget? get_steam_restart_target () { return target; }
    }

    private class RecordingRestartChange : Object, SteamChangeRecorder {
        public SteamRestartRecordResult next_result = SteamRestartRecordResult.ADDED;
        public int calls = 0;
        public SteamChangeReceipt? last_receipt = null;
        public Gee.List<SteamChangeReceipt> receipts = new Gee.ArrayList<SteamChangeReceipt> ();
        public SteamRestartRecordResult record (SteamChangeReceipt receipt) {
            calls++;
            last_receipt = receipt;
            receipts.add (receipt);
            return next_result;
        }
    }

    public void register_tests () {
        Test.add_func ("/installer-transaction/stages-promotes-cleans-and-writes-metadata", test_stages_promotes_and_writes_metadata);
        Test.add_func ("/installer-transaction/canceled-download-cleans-private-workspace", test_canceled_download_cleans_workspace);
        Test.add_func ("/installer-transaction/failed-promotion-restores-previous-installation", test_failed_promotion_restores_previous_installation);
        Test.add_func ("/installer-transaction/duplicate-is-rejected-before-workflow", test_duplicate_is_rejected_before_workflow);
        Test.add_func ("/installer-transaction/standard-removal-finalizes-common-lifecycle", test_standard_removal_finalizes_common_lifecycle);
        Test.add_func ("/installer-transaction/standard-finalization-uses-launcher-capabilities", test_standard_finalization_uses_launcher_capabilities);
        Test.add_func ("/installer-transaction/operation-identity-prevents-duplicates", test_operation_identity_prevents_duplicates);
        Test.add_func ("/installer-transaction/nested-archive-requirement-extracts-nested-archive", test_nested_archive_requirement_extracts_nested_archive);
        Test.add_func ("/installer-transaction/invalid-download-is-not-cached", test_invalid_download_is_not_cached);
        Test.add_func ("/installer-transaction/extraction-failure-evicts-cached-archive", test_extraction_failure_evicts_cached_archive);
        Test.add_func ("/installer-transaction/integrity-metadata-rejects-corrupt-cache", test_integrity_metadata_rejects_corrupt_cache);
        Test.add_func ("/installer-transaction/digest-mismatch-rejects-download", test_digest_mismatch_rejects_download);
        Test.add_func ("/installer-transaction/latest-rewrites-supported-compatibility-manifest-layouts", test_latest_rewrites_supported_compatibility_manifest_layouts);
        Test.add_func ("/installer-transaction/versioned-install-preserves-compatibility-manifest", test_versioned_install_preserves_compatibility_manifest);
        Test.add_func ("/installer-transaction/latest-rejects-malformed-compatibility-manifest", test_latest_rejects_malformed_compatibility_manifest);
        Test.add_func ("/installer-transaction/all-built-in-providers-use-latest-workflow", test_all_built_in_providers_use_latest_workflow);
        Test.add_func ("/installer-transaction/aarch64-host-installs-x86-64-variant", test_aarch64_host_installs_x86_64_variant);
        Test.add_func ("/installer-transaction/aarch64-host-defaults-to-native-variant", test_aarch64_host_defaults_to_native_variant);
        Test.add_func ("/installer-transaction/x86-64-host-rejects-aarch64-variant", test_x86_64_host_rejects_aarch64_variant);
        Test.add_func ("/installer-transaction/incompatible-variant-stops-before-download", test_incompatible_variant_stops_before_download);
        Test.add_func ("/installer-transaction/incompatible-variant-stops-update-install", test_incompatible_variant_stops_update_install);
        Test.add_func ("/installer-transaction/records-completed-steam-workflow-and-persistence-failure", test_records_completed_steam_workflow_and_persistence_failure);
    }

    private string temporary_directory () {
        try { return DirUtils.make_tmp ("protonplus-installer-transaction-test-XXXXXX"); }
        catch (FileError e) { critical ("Could not create test directory: %s", e.message); assert_not_reached (); }
    }
    private string fixture_archive (string root) {
        return fixture_archive_named (root, "runner.zip.base64");
    }
    private string fixture_archive_named (string root, string fixture_name) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename ("fixtures", "archives", fixture_name)
        ).strip ();
        var path = Path.build_filename (root, fixture_name.replace (".base64", ""));
        try { FileUtils.set_data (path, Base64.decode (encoded)); }
        catch (FileError e) { critical ("Could not write archive fixture: %s", e.message); assert_not_reached (); }
        return path;
    }
    private string nested_fixture_archive (string root) {
        var encoded = ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename ("fixtures", "archives", "nested-runner.zip.base64")).strip ();
        var path = Path.build_filename (root, "nested-runner.zip");
        try { FileUtils.set_data (path, Base64.decode (encoded)); }
        catch (FileError e) { critical ("Could not write nested archive fixture: %s", e.message); assert_not_reached (); }
        return path;
    }
    private Models.Tools.ProviderTool runner (
        string root,
        ArchiveInstallRequirement archive_install_requirement = ArchiveInstallRequirement.STANDARD,
        Launcher? target_launcher = null
    ) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (root));
        Launcher launcher;
        if (target_launcher == null)
            launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { root });
        else
            launcher = (!) target_launcher;
        var group = new Group ("Test", "", "", launcher);
        ProviderDefinition? definition = new ProviderRegistry ().get_by_id ("proton-ge");
        if (archive_install_requirement == ArchiveInstallRequirement.NESTED_ARCHIVE) {
            definition = new ProviderDefinition (
                Category.PROTON, SourceType.GITHUB, "nested-fixture", "Fixture Runner", "",
                "https://example.test/releases", "https://example.test/source", 1,
                { new VariantDefinition ("standard", "default", "$release_name", true) },
                { InstallLayout.template ("default", "$release_name") }, null, null, "", false, "",
                archive_install_requirement
            );
        }
        assert (definition != null);
        var value = ProviderCatalog.create_tool ((!) definition, group);
        assert (value != null);
        return (!) value;
    }
    private Models.Tools.ProviderTool runner_for_definition (string root, ProviderDefinition definition) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (root));
        var launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { root });
        var group = new Group ("Test", "", "", launcher);
        var value = ProviderCatalog.create_tool (definition, group);
        assert (value != null);
        return (!) value;
    }
    private ReturnCode install (FixtureJob job, bool replacement = false) {
        var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR;
        if (replacement) job.install_replacement.begin ((obj, res) => { code = job.install_replacement.end (res); loop.quit (); });
        else job.install.begin ((obj, res) => { code = job.install.end (res); loop.quit (); });
        loop.run (); return code;
    }
    private ReturnCode install_for_update (FixtureJob job) {
        var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR;
        ProtonPlus.Services.InstallationService.instance.install_for_update.begin (job, (obj, res) => {
            code = ProtonPlus.Services.InstallationService.instance.install_for_update.end (res);
            loop.quit ();
        });
        loop.run (); return code;
    }
    private ReturnCode remove (ProtonPlus.Services.InstallJob job) {
        var loop = new MainLoop (); ReturnCode code = ReturnCode.FILESYSTEM_ERROR;
        job.remove.begin (false, (obj, res) => { code = job.remove.end (res); loop.quit (); });
        loop.run (); return code;
    }
    private bool delete_directory (string path) {
        var loop = new MainLoop (); var deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, res) => { deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (res); loop.quit (); });
        loop.run (); return deleted;
    }
    private void no_entries (string directory, string prefix) {
        try { var entries = Dir.open (directory); string? name; while ((name = entries.read_name ()) != null) assert (!name.has_prefix (prefix)); }
        catch (FileError e) { critical ("Could not inspect temporary directory: %s", e.message); assert_not_reached (); }
    }
    private void prepare (out string root, out string cache, out string tools, out string location) {
        root = temporary_directory (); cache = Path.build_filename (root, "cache"); tools = Path.build_filename (root, "tools"); location = Path.build_filename (tools, "Fixture Runner");
        Globals.CACHE_PATH = cache; assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
    }
    private string archive_cache_path (string cache, string url) {
        return Path.build_filename (
            cache, "archives", "%s.zip".printf (Checksum.compute_for_string (ChecksumType.SHA256, url))
        );
    }
    private string file_sha256 (string path) {
        try {
            uint8[] contents;
            FileUtils.get_data (path, out contents);
            return Checksum.compute_for_data (ChecksumType.SHA256, contents);
        } catch (FileError e) {
            critical ("Could not checksum archive fixture: %s", e.message);
            assert_not_reached ();
        }
    }
    private void test_stages_promotes_and_writes_metadata () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var target = runner (tools); var job = new FixtureJob (target, location, fixture_archive (root));
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (location, "marker.txt")) == "new runner\n");
        var metadata = ProtonPlus.Utils.Metadata.load (location);
        assert (metadata.tool_id == target.id); assert (metadata.release_id == "fixture-release-id"); assert (metadata.tag == "fixture-tag");
        assert (job.is_finished && job.install_success);
        assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0);
        no_entries (cache, ".protonplus-install-"); no_entries (tools, ".protonplus-stage-"); assert (delete_directory (root));
    }
    private void test_canceled_download_cleans_workspace () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (runner (tools), location, fixture_archive (root), true);
        assert (install (job) == ReturnCode.DOWNLOAD_FAILED); assert (job.canceled); assert (job.is_finished && !job.install_success); assert (job.state == ProtonPlus.Services.InstallJob.State.NOT_INSTALLED); assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0); assert (!FileUtils.test (location, FileTest.EXISTS)); no_entries (cache, ".protonplus-install-"); assert (delete_directory (root));
    }
    private void test_failed_promotion_restores_previous_installation () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        assert (ProtonPlus.Utils.Filesystem.create_directory (location)); ProtonPlus.Utils.Filesystem.create_file (Path.build_filename (location, "marker.txt"), "previous runner\n");
        var job = new FixtureJob (runner (tools), location, fixture_archive (root), false, true);
        assert (install (job, true) == ReturnCode.FILESYSTEM_ERROR); assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (location, "marker.txt")) == "previous runner\n");
        assert (job.is_finished && !job.install_success); assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0); no_entries (tools, ".protonplus-previous-"); assert (delete_directory (root));
    }

    private void test_duplicate_is_rejected_before_workflow () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (runner (tools), location, fixture_archive (root));
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        manager.add_download (job);
        assert (install (job) == ReturnCode.OPERATION_IN_PROGRESS);
        assert (job.download_calls == 0);
        manager.remove_download (job);
        assert (delete_directory (root));
    }

    private void test_incompatible_variant_stops_before_download () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (runner (tools), location, "not-used.zip");
        job.release.variants.add (new ProtonPlus.Models.Variant (
            "v3", "x86_64_v3", "", true, "https://fixtures.invalid/v3.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));
        job.set_selected_variant ("x86_64_v3", null, "v3");
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        assert (install (job) == ReturnCode.INCOMPATIBLE_VARIANT);
        assert (job.download_calls == 0);
        assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0);
        assert (!FileUtils.test (location, FileTest.EXISTS));
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_aarch64_host_installs_x86_64_variant () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var archive = fixture_archive (root);
        var job = new FixtureJob (runner (tools), location, archive);
        job.release.variants.add (new ProtonPlus.Models.Variant (
            "x86-64", "x86_64", "", false, "https://fixtures.invalid/runner.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)
        ));
        job.set_selected_variant ("x86_64", null, "x86-64");
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.AARCH64);
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (job.download_calls == 1);
        assert (FileUtils.test (location, FileTest.IS_DIR));
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_x86_64_host_rejects_aarch64_variant () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (runner (tools), location, "not-used.zip");
        job.release.variants.add (new ProtonPlus.Models.Variant (
            "aarch64", "aarch64", "", false, "https://fixtures.invalid/aarch64.zip",
            VariantCompatibility.for_architecture (CpuArchitecture.AARCH64)
        ));
        job.set_selected_variant ("aarch64", null, "aarch64");
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V4);
        assert (install (job) == ReturnCode.INCOMPATIBLE_VARIANT);
        assert (job.download_calls == 0);
        assert (!FileUtils.test (location, FileTest.EXISTS));
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_aarch64_host_defaults_to_native_variant () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var archive = fixture_archive (root);
        var job = new FixtureJob (runner (tools), location, archive);
        job.release.variants.add (new ProtonPlus.Models.Variant (
            "x86-64", "x86_64", "", true, "https://fixtures.invalid/runner.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.BASELINE)
        ));
        job.release.variants.add (new ProtonPlus.Models.Variant (
            "aarch64", "aarch64", "", false, "https://fixtures.invalid/runner.zip",
            VariantCompatibility.for_architecture (CpuArchitecture.AARCH64)
        ));
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.AARCH64);
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (job.selected_variant_id == "aarch64");
        assert (job.download_calls == 1);
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_incompatible_variant_stops_update_install () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (runner (tools), location, "not-used.zip", false, false,
            ProtonPlus.Services.InstallJob.Mode.LATEST);
        job.release.variants.add (new ProtonPlus.Models.Variant (
            "v3", "x86_64_v3", "", false, "https://fixtures.invalid/v3.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));
        job.set_selected_variant ("x86_64_v3", null, "v3");
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        assert (install_for_update (job) == ReturnCode.INCOMPATIBLE_VARIANT);
        assert (job.download_calls == 0);
        assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0);
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_records_completed_steam_workflow_and_persistence_failure () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var recorder = new RecordingRestartChange ();
        InstallationService.instance.configure_steam_change_recorder (recorder);
        var launcher = new RestartTargetLauncher (root);
        var job = new FixtureJob (runner (tools, ArchiveInstallRequirement.STANDARD, launcher), location, fixture_archive (root));
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (recorder.calls == 1);
        assert (recorder.last_receipt.kind == SteamChangeKind.COMPATIBILITY_TOOL_INSTALLED);
        assert (recorder.last_receipt.resource_key == Filename.canonicalize (location, null));
        assert (job.has_steam_restart_record_result);

        var replacement = new FixtureJob (runner (Path.build_filename (root, "tools-two"), ArchiveInstallRequirement.STANDARD, launcher),
            Path.build_filename (root, "tools-two", "Fixture Runner"), fixture_archive (root));
        assert (install (replacement, true) == ReturnCode.RUNNER_INSTALLED);
        assert (recorder.calls == 2);
        assert (recorder.last_receipt.kind == SteamChangeKind.COMPATIBILITY_TOOL_UPDATED_OR_REPLACED);
        /* The workflow reports its completed update after install_for_update;
         * a duplicate internal callback must not create another receipt. */
        InstallationService.instance.record_completed_update (replacement);
        assert (recorder.calls == 2);

        assert (remove (replacement) == ReturnCode.RUNNER_REMOVED);
        assert (recorder.calls == 3);
        assert (recorder.last_receipt.kind == SteamChangeKind.COMPATIBILITY_TOOL_REMOVED);

        var no_op = new FixtureJob (runner (Path.build_filename (root, "tools-three"), ArchiveInstallRequirement.STANDARD, launcher),
            Path.build_filename (root, "tools-three", "Fixture Runner"), fixture_archive (root));
        assert (remove (no_op) == ReturnCode.RUNNER_REMOVED);
        assert (recorder.calls == 3);

        recorder.next_result = SteamRestartRecordResult.PERSISTENCE_FAILED;
        var persistence = new FixtureJob (runner (Path.build_filename (root, "tools-four"), ArchiveInstallRequirement.STANDARD, launcher),
            Path.build_filename (root, "tools-four", "Fixture Runner"), fixture_archive (root));
        assert (install (persistence) == ReturnCode.RUNNER_INSTALLED);
        assert (recorder.calls == 4);
        assert (persistence.steam_restart_warning != null);
        assert (FileUtils.test (persistence.install_location, FileTest.IS_DIR));

        recorder.next_result = SteamRestartRecordResult.ADDED;
        var cancel_cache = Path.build_filename (root, "cancel-cache");
        assert (ProtonPlus.Utils.Filesystem.create_directory (cancel_cache));
        Globals.CACHE_PATH = cancel_cache;
        var cancelled = new FixtureJob (runner (Path.build_filename (root, "tools-five"), ArchiveInstallRequirement.STANDARD, launcher),
            Path.build_filename (root, "tools-five", "Fixture Runner"), fixture_archive (root), true);
        assert (install (cancelled) != ReturnCode.RUNNER_INSTALLED);
        assert (cancelled.canceled);
        assert (recorder.calls == 4);

        var failed = new FixtureJob (runner (Path.build_filename (root, "tools-six"), ArchiveInstallRequirement.STANDARD, launcher),
            Path.build_filename (root, "tools-six", "Fixture Runner"), fixture_archive (root), false, true);
        assert (install (failed) == ReturnCode.FILESYSTEM_ERROR);
        assert (recorder.calls == 4);

        var incompatible = new FixtureJob (runner (Path.build_filename (root, "tools-seven"), ArchiveInstallRequirement.STANDARD, launcher),
            Path.build_filename (root, "tools-seven", "Fixture Runner"), "not-used.zip");
        incompatible.release.variants.add (new Models.Variant (
            "v3", "x86_64_v3", "", true, "https://fixtures.invalid/v3.zip",
            VariantCompatibility.for_x86_64_level (X86_64Level.V3)
        ));
        incompatible.set_selected_variant ("x86_64_v3", null, "v3");
        var original_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        assert (install (incompatible) == ReturnCode.INCOMPATIBLE_VARIANT);
        Globals.CPU_CAPABILITIES = original_capabilities;
        assert (recorder.calls == 4);

        /* A later transaction may record independently after the per-job
         * duplicate guard has finished its operation. */
        recorder.next_result = SteamRestartRecordResult.PERSISTENCE_FAILED;
        var second_persistence = new FixtureJob (runner (Path.build_filename (root, "tools-eight"), ArchiveInstallRequirement.STANDARD, launcher),
            Path.build_filename (root, "tools-eight", "Fixture Runner"), fixture_archive (root));
        assert (install (second_persistence) == ReturnCode.RUNNER_INSTALLED);
        assert (recorder.calls == 5);
        assert (second_persistence.steam_restart_warning != null);
        InstallationService.reset_lifecycle_configuration_for_tests ();
        assert (delete_directory (root));
    }

    private void test_standard_removal_finalizes_common_lifecycle () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        assert (ProtonPlus.Utils.Filesystem.create_directory (location));
        var job = new FixtureJob (runner (tools), location, fixture_archive (root));
        assert (remove (job) == ReturnCode.RUNNER_REMOVED);
        assert (!FileUtils.test (location, FileTest.EXISTS));
        assert (job.state == ProtonPlus.Services.InstallJob.State.NOT_INSTALLED);
        assert (job.step == ProtonPlus.Services.InstallJob.Step.NOTHING);
        assert (ProtonPlus.Utils.DownloadManager.instance.active_downloads.size == 0);
        assert (delete_directory (root));
    }

    private void test_standard_finalization_uses_launcher_capabilities () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var launcher = new RecordingLauncher ();
        var target = runner (tools, ArchiveInstallRequirement.STANDARD, launcher);
        var job = new ProtonPlus.Services.InstallJob (new Release (
            "Fixture Runner", "", "", new Models.Assets.Asset ("runner.zip", "https://fixtures.invalid/runner.zip"),
            "", 0, "fixture-release-id", "fixture-tag"
        ), target, ProtonPlus.Services.InstallJob.Mode.VERSIONED, location);
        var workflow = new ProtonPlus.Services.StandardArchiveWorkflow ();

        workflow.finalize_install_success (job);
        assert (launcher.registered_path == location);
        workflow.finalize_removal_success (job);
        assert (launcher.removed_path == location);
        assert (delete_directory (root));
    }

    private void test_operation_identity_prevents_duplicates () {
        var root = temporary_directory ();
        var target = runner (root);
        var release = new Release (
            "Same display title", "", "", new Models.Assets.Asset ("runner.zip", "https://fixtures.invalid/runner.zip"),
            "", 0, "release-one", "release-one"
        );
        release.variants.add (new ProtonPlus.Models.Variant ("default", "Default", "", true));
        release.variants.add (new ProtonPlus.Models.Variant ("alternate", "Alternate", "", false));

        var first = new ProtonPlus.Services.InstallJob (release, target);
        var same_target = new ProtonPlus.Services.InstallJob (release, target);
        var different_release = new ProtonPlus.Services.InstallJob (new Release (
            "Same display title", "", "", new Models.Assets.Asset ("runner.zip", "https://fixtures.invalid/runner.zip"),
            "", 0, "release-two", "release-two"
        ), target);
        different_release.release.variants.add (new ProtonPlus.Models.Variant ("default", "Default", "", true));
        var alternate = new ProtonPlus.Services.InstallJob (release, target);
        alternate.set_selected_variant ("Alternate", new Models.Assets.Asset ("alternate.zip", "https://fixtures.invalid/alternate.zip"));
        var latest_one = new ProtonPlus.Services.InstallJob (release, target, ProtonPlus.Services.InstallJob.Mode.LATEST);
        var latest_two = new ProtonPlus.Services.InstallJob (different_release.release, target, ProtonPlus.Services.InstallJob.Mode.LATEST);
        var steam_tinker_launch = new ProtonPlus.Services.InstallJob (release, target, ProtonPlus.Services.InstallJob.Mode.STEAM_TINKER_LAUNCH, null, root);
        var special_release = new Release (
            "Steam Tinker Launch", "", "", new Models.Assets.Asset ("stl.zip", "https://fixtures.invalid/stl.zip"),
            "", 0, "stl-release", "stl-release", Release.Kind.STEAM_TINKER_LAUNCH
        );
        var automatically_selected_stl = new ProtonPlus.Services.InstallJob (special_release, target, ProtonPlus.Services.InstallJob.Mode.VERSIONED, null, root);

        assert (first.steam_tinker_launch_context == null);
        assert (steam_tinker_launch.steam_tinker_launch_context != null);
        assert (automatically_selected_stl.steam_tinker_launch_context != null);
        assert (first.operation_id == same_target.operation_id);
        assert (first.operation_id != different_release.operation_id);
        assert (first.operation_id != alternate.operation_id);
        assert (latest_one.operation_id == latest_two.operation_id);
        assert (latest_one.operation_id != steam_tinker_launch.operation_id);

        var manager = ProtonPlus.Utils.DownloadManager.instance;
        assert (manager.active_downloads.size == 0);
        manager.add_download (first);
        manager.add_download (same_target);
        assert (manager.active_downloads.size == 1);
        assert (manager.is_downloading (same_target));
        assert (manager.get_active_download (same_target) == first);
        manager.remove_download (first);
        assert (manager.active_downloads.size == 0);

        assert (delete_directory (root));
    }

    private void test_nested_archive_requirement_extracts_nested_archive () {
        string root, cache, tools, location; prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (
            runner (tools, ArchiveInstallRequirement.NESTED_ARCHIVE), location, nested_fixture_archive (root)
        );
        assert (job.archive_install_requirement == ArchiveInstallRequirement.NESTED_ARCHIVE);
        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (Path.build_filename (location, "marker.txt")) == "nested runner\n");
        assert (delete_directory (root));
    }

    private void test_invalid_download_is_not_cached () {
        string root, cache, tools, location;
        prepare (out root, out cache, out tools, out location);
        var invalid_archive = Path.build_filename (root, "invalid.zip");
        ProtonPlus.Utils.Filesystem.create_file (invalid_archive, "not an archive");
        var job = new FixtureJob (runner (tools), location, invalid_archive);
        var cache_path = archive_cache_path (cache, job.selected_asset.download_url);

        assert (install (job) == ReturnCode.EXTRACTION_FAILED);
        assert (job.download_calls == 1);
        assert (!FileUtils.test (cache_path, FileTest.EXISTS));
        assert (delete_directory (root));
    }

    private void test_extraction_failure_evicts_cached_archive () {
        string root, cache, tools, location;
        prepare (out root, out cache, out tools, out location);
        var fixture = fixture_archive (root);
        var first = new FixtureJob (runner (tools), location, fixture);
        var cache_path = archive_cache_path (cache, first.selected_asset.download_url);
        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.get_dirname (cache_path)));
        ProtonPlus.Utils.Filesystem.create_file (cache_path, "truncated archive");

        assert (install (first) == ReturnCode.EXTRACTION_FAILED);
        assert (first.download_calls == 0);
        assert (!FileUtils.test (cache_path, FileTest.EXISTS));

        var retry = new FixtureJob (runner (Path.build_filename (root, "retry-tools")), location, fixture);
        assert (install (retry) == ReturnCode.RUNNER_INSTALLED);
        assert (retry.download_calls == 1);
        assert (FileUtils.test (cache_path, FileTest.IS_REGULAR));
        assert (delete_directory (root));
    }

    private void test_integrity_metadata_rejects_corrupt_cache () {
        string root, cache, tools, location;
        prepare (out root, out cache, out tools, out location);
        var fixture = fixture_archive (root);
        Posix.Stat fixture_stat;
        assert (Posix.stat (fixture, out fixture_stat) == 0);
        var job = new FixtureJob (
            runner (tools), location, fixture, false, false,
            ProtonPlus.Services.InstallJob.Mode.VERSIONED, fixture_stat.st_size,
            "sha256:%s".printf (file_sha256 (fixture))
        );
        var cache_path = archive_cache_path (cache, job.selected_asset.download_url);
        assert (ProtonPlus.Utils.Filesystem.create_directory (Path.get_dirname (cache_path)));
        ProtonPlus.Utils.Filesystem.create_file (cache_path, "short");

        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        assert (job.download_calls == 1);
        Posix.Stat cache_stat;
        assert (Posix.stat (cache_path, out cache_stat) == 0);
        assert (cache_stat.st_size == fixture_stat.st_size);
        assert (delete_directory (root));
    }

    private void test_digest_mismatch_rejects_download () {
        string root, cache, tools, location;
        prepare (out root, out cache, out tools, out location);
        var fixture = fixture_archive (root);
        var job = new FixtureJob (
            runner (tools), location, fixture, false, false,
            ProtonPlus.Services.InstallJob.Mode.VERSIONED, 0,
            "sha256:0000000000000000000000000000000000000000000000000000000000000000"
        );
        var cache_path = archive_cache_path (cache, job.selected_asset.download_url);

        assert (install (job) == ReturnCode.DOWNLOAD_FAILED);
        assert (job.download_calls == 1);
        assert (!FileUtils.test (cache_path, FileTest.EXISTS));
        assert (delete_directory (root));
    }

    private void test_latest_rewrites_supported_compatibility_manifest_layouts () {
        foreach (var fixture_name in new string[] {
            "wrapped-manifest-runner.zip.base64", "direct-manifest-runner.zip.base64"
        }) {
            string root, cache, tools, location;
            prepare (out root, out cache, out tools, out location);
            var target = runner (tools);
            var job = new FixtureJob (
                target, location, fixture_archive_named (root, fixture_name), false, false,
                ProtonPlus.Services.InstallJob.Mode.LATEST
            );

            assert (install (job) == ReturnCode.RUNNER_INSTALLED);
            var content = ProtonPlus.Utils.Filesystem.get_file_content (
                Path.build_filename (location, "compatibilitytool.vdf")
            );
            assert (content.contains ("\"Proton-GE Latest\" // Internal name of this tool"));
            assert (content.contains ("\"display_name\" \"Proton-GE Latest\""));
            assert (!content.contains ("\"display_name\" \"Fixture Runner\""));
            assert (delete_directory (root));
        }
    }

    private void test_versioned_install_preserves_compatibility_manifest () {
        string root, cache, tools, location;
        prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (
            runner (tools), location,
            fixture_archive_named (root, "wrapped-manifest-runner.zip.base64")
        );

        assert (install (job) == ReturnCode.RUNNER_INSTALLED);
        var content = ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (location, "compatibilitytool.vdf")
        );
        assert (content.contains ("\"Fixture Runner\" // Internal name of this tool"));
        assert (content.contains ("\"display_name\" \"Fixture Runner\""));
        assert (!content.contains ("Proton-GE Latest"));
        assert (delete_directory (root));
    }

    private void test_latest_rejects_malformed_compatibility_manifest () {
        string root, cache, tools, location;
        prepare (out root, out cache, out tools, out location);
        var job = new FixtureJob (
            runner (tools), location,
            fixture_archive_named (root, "malformed-manifest-runner.zip.base64"), false, false,
            ProtonPlus.Services.InstallJob.Mode.LATEST
        );

        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*expected exactly one compat_tools entry*");
        assert (install (job) == ReturnCode.INVALID_DATA);
        Test.assert_expected_messages ();
        assert (job.error_message == "The compatibility tool manifest is invalid or incomplete");
        assert (!FileUtils.test (location, FileTest.EXISTS));
        no_entries (cache, ".protonplus-install-");
        no_entries (tools, ".protonplus-stage-");
        assert (delete_directory (root));
    }

    private void test_all_built_in_providers_use_latest_workflow () {
        var root = temporary_directory ();
        var cache = Path.build_filename (root, "cache");
        var tools = Path.build_filename (root, "tools");
        Globals.CACHE_PATH = cache;
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        assert (ProtonPlus.Utils.Filesystem.create_directory (tools));
        var wrapped_archive = fixture_archive_named (root, "wrapped-manifest-runner.zip.base64");
        var nested_archive = fixture_archive_named (root, "nested-wrapped-manifest-runner.zip.base64");

        foreach (var definition in new ProviderRegistry ().get_all ()) {
            var target_root = Path.build_filename (tools, definition.provider_id);
            var target = runner_for_definition (target_root, definition);
            var location = Path.build_filename (target_root, "Latest installation");
            var archive = definition.archive_install_requirement == ArchiveInstallRequirement.NESTED_ARCHIVE
                ? nested_archive : wrapped_archive;
            var job = new FixtureJob (
                target, location, archive, false, false,
                ProtonPlus.Services.InstallJob.Mode.LATEST
            );

            assert (install (job) == ReturnCode.RUNNER_INSTALLED);
            var content = ProtonPlus.Utils.Filesystem.get_file_content (
                Path.build_filename (location, "compatibilitytool.vdf")
            );
            assert (content.contains ("\"display_name\" \"%s Latest\"".printf (definition.title)));
            var metadata = ProtonPlus.Utils.Metadata.load (location);
            assert (metadata.provider_id == definition.provider_id);
            assert (metadata.tag == "fixture-tag");
        }

        no_entries (cache, ".protonplus-install-");
        assert (delete_directory (root));
    }
}
