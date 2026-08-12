namespace AppTests.CompatibilityProcessGuardTest {
    using GLib;
    using ProtonPlus;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;
    using ProtonPlus.Services;

    private class FixtureBackend : Object, CompatibilityProcessQueryBackend {
        private CompatibilityProcessInspectionResult result;

        public FixtureBackend (CompatibilityProcessInspectionResult result) {
            this.result = result;
        }

        public async CompatibilityProcessInspectionResult inspect_processes () {
            return result;
        }
    }

    private class FixtureFlatpakHostQuery : Object, FlatpakHostProcessQuery {
        private ProtonPlus.Utils.CommandResult result;

        public FixtureFlatpakHostQuery (ProtonPlus.Utils.CommandResult result) {
            this.result = result;
        }

        public async ProtonPlus.Utils.CommandResult run () {
            return result;
        }
    }

    private class FailingDownloadJob : InstallJob {
        public int download_calls { get; private set; default = 0; }

        public FailingDownloadJob (
            Release release,
            Models.Tools.ProviderTool tool,
            string installation_location
        ) {
            base (release, tool, Mode.VERSIONED, installation_location);
        }

        public override async bool download_archive (
            string url,
            string path,
            out string? error_message
        ) {
            download_calls++;
            error_message = "fixture download stopped";
            return false;
        }
    }

    public void register_tests () {
        Test.add_func ("/compatibility-process-guard/decodes-raw-nul-command-line", test_decodes_raw_nul_command_line);
        Test.add_func ("/compatibility-process-guard/preserves-spaces-quotes-and-empty-arguments", test_preserves_spaces_quotes_and_empty_arguments);
        Test.add_func ("/compatibility-process-guard/detects-supported-runner-tokens", test_detects_supported_runner_tokens);
        Test.add_func ("/compatibility-process-guard/detects-runner-token-after-argv-zero", test_detects_runner_token_after_argv_zero);
        Test.add_func ("/compatibility-process-guard/ignores-lookalikes-and-text", test_ignores_lookalikes_and_text);
        Test.add_func ("/compatibility-process-guard/recognizes-case-preloaders-and-wineserver", test_recognizes_case_preloaders_and_wineserver);
        Test.add_func ("/compatibility-process-guard/target-aware-association", test_target_aware_association);
        Test.add_func ("/compatibility-process-guard/path-prefix-boundary", test_path_prefix_boundary);
        Test.add_func ("/compatibility-process-guard/shared-physical-target", test_shared_physical_target);
        Test.add_func ("/compatibility-process-guard/returns-blocker-details", test_returns_blocker_details);
        Test.add_func ("/compatibility-process-guard/flatpak-host-query-success", test_flatpak_host_query_success);
        Test.add_func ("/compatibility-process-guard/flatpak-completed-empty-scan", test_flatpak_completed_empty_scan);
        Test.add_func ("/compatibility-process-guard/flatpak-empty-output-is-unknown", test_flatpak_empty_output_is_unknown);
        Test.add_func ("/compatibility-process-guard/flatpak-failed-relevant-read", test_flatpak_failed_relevant_read);
        Test.add_func ("/compatibility-process-guard/flatpak-host-query-launch-failure", test_flatpak_host_query_launch_failure);
        Test.add_func ("/compatibility-process-guard/flatpak-host-query-nonzero-exit", test_flatpak_host_query_nonzero_exit);
        Test.add_func ("/compatibility-process-guard/native-top-level-proc-failure", test_native_top_level_proc_failure);
        Test.add_func ("/compatibility-process-guard/native-disappearing-process", test_native_disappearing_process);
        Test.add_func ("/compatibility-process-guard/native-empty-cmdline", test_native_empty_cmdline);
        Test.add_func ("/compatibility-process-guard/native-executable-read-failure", test_native_executable_read_failure);
        Test.add_func ("/compatibility-process-guard/native-cmdline-read-failure", test_native_cmdline_read_failure);
        Test.add_func ("/compatibility-process-guard/tool-a-blocks-only-tool-a-mutations", test_tool_a_blocks_only_tool_a_mutations);
        Test.add_func ("/compatibility-process-guard/unknown-blocks-mutations-but-allows-new-destination", test_unknown_blocks_mutations_but_allows_new_destination);
    }

    private uint8[] encode_cmdline (string[] argv) {
        var length = 0;
        foreach (var argument in argv)
            length += argument.length + 1;
        var bytes = new uint8[length];
        var offset = 0;
        foreach (var argument in argv) {
            for (var index = 0; index < argument.length; index++)
                bytes[offset++] = argument.data[index];
            bytes[offset++] = 0;
        }
        return bytes;
    }

    private CompatibilityProcessRecord record_for (
        string executable,
        string[] argv,
        int pid = 42
    ) {
        return new CompatibilityProcessRecord.from_cmdline_bytes (
            pid, executable, encode_cmdline (argv)
        );
    }

    private CompatibilityProcessInspectionResult inspect_records (
        CompatibilityProcessRecord record,
        string target = "/tmp/target",
        bool mutates_existing_destination = true
    ) {
        var records = new Gee.ArrayList<CompatibilityProcessRecord> ();
        records.add (record);
        return CompatibilityProcessGuard.inspect_records (
            records,
            operation_context (target, mutates_existing_destination)
        );
    }

    private CompatibilityProcessOperationContext operation_context (
        string target,
        bool mutates_existing_destination = true,
        string tool_target_id = "steam-system",
        string launcher_instance_id = "steam-system",
        string launcher_family_id = "steam"
    ) {
        return new CompatibilityProcessOperationContext (
            CompatibilityProcessOperationKind.REPLACEMENT,
            target,
            launcher_family_id,
            launcher_instance_id,
            "steam",
            tool_target_id,
            mutates_existing_destination
        );
    }

    private CompatibilityProcessInspectionResult inspect_guard (
        CompatibilityProcessGuard guard,
        string target = "/opt/Proton"
    ) {
        var loop = new MainLoop ();
        CompatibilityProcessInspectionResult? result = null;
        guard.inspect.begin (operation_context (target), (obj, response) => {
            result = guard.inspect.end (response);
            loop.quit ();
        });
        loop.run ();
        assert (result != null);
        return (!) result;
    }

    private string flatpak_record_output (
        int pid,
        string executable,
        string[] argv
    ) {
        return "R\t%d\t%s\t%s\nS\tOK\n".printf (
            pid,
            Base64.encode (executable.data),
            Base64.encode (encode_cmdline (argv))
        );
    }

    private CompatibilityProcessInspectionResult inspect_native (string proc_root) {
        return inspect_guard (new CompatibilityProcessGuard (
            new NativeCompatibilityProcessQueryBackend (proc_root)
        ));
    }

    private void write_cmdline (string process_root, string[] argv) {
        try {
            FileUtils.set_data (Path.build_filename (process_root, "cmdline"), encode_cmdline (argv));
        } catch (FileError e) {
            critical ("Could not write process cmdline fixture: %s", e.message);
            assert_not_reached ();
        }
    }

    private CompatibilityProcessInspectionResult inspect_flatpak (
        ProtonPlus.Utils.CommandResult command
    ) {
        var backend = new FlatpakCompatibilityProcessQueryBackend (
            new FixtureFlatpakHostQuery (command)
        );
        return inspect_guard (new CompatibilityProcessGuard (backend));
    }

    private string temporary_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-process-guard-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create process guard fixture: %s", e.message);
            assert_not_reached ();
        }
    }

    private bool delete_directory (string path) {
        var loop = new MainLoop ();
        var deleted = false;
        ProtonPlus.Utils.Filesystem.delete_directory.begin (path, (obj, response) => {
            deleted = ProtonPlus.Utils.Filesystem.delete_directory.end (response);
            loop.quit ();
        });
        loop.run ();
        return deleted;
    }

    private Models.Tools.ProviderTool fixture_runner (string tools) {
        assert (ProtonPlus.Utils.Filesystem.create_directory (tools));
        var launcher = new Launcher (
            "Process guard fixture", Launcher.InstallationTypes.SYSTEM, "", { tools }
        );
        var group = new Group ("Proton", "", "", launcher);
        var definition = new ProviderRegistry ().get_by_id ("proton-ge");
        assert (definition != null);
        var tool = ProviderCatalog.create_tool ((!) definition, group);
        assert (tool != null);
        return (!) tool;
    }

    private Release fixture_release () {
        var asset = new Models.Assets.Asset (
            "fixture.zip", "https://fixtures.invalid/fixture.zip"
        );
        var release = new Release (
            "Fixture", "", "", asset, "", 0, "fixture-release", "fixture-tag"
        );
        release.variants.add (new ProtonPlus.Models.Variant (
            "x86", "x86", "", true, asset.download_url, null, asset
        ));
        return release;
    }

    private ReturnCode install_job (FailingDownloadJob job, bool replacement) {
        var loop = new MainLoop ();
        var code = ReturnCode.FILESYSTEM_ERROR;
        if (replacement) {
            job.install_replacement.begin ((obj, response) => {
                code = job.install_replacement.end (response);
                loop.quit ();
            });
        } else {
            job.install.begin ((obj, response) => {
                code = job.install.end (response);
                loop.quit ();
            });
        }
        loop.run ();
        return code;
    }

    private ReturnCode remove_job (FailingDownloadJob job) {
        var loop = new MainLoop ();
        var code = ReturnCode.FILESYSTEM_ERROR;
        job.remove.begin (false, (obj, response) => {
            code = job.remove.end (response);
            loop.quit ();
        });
        loop.run ();
        return code;
    }

    private void test_decodes_raw_nul_command_line () {
        var record = record_for (
            "/usr/bin/env", { "/usr/bin/env", "ONE=1", "/opt/umu-run", "game" }
        );
        assert (record.argv.size == 4);
        assert (record.argv[0] == "/usr/bin/env");
        assert (record.argv[1] == "ONE=1");
        assert (record.argv[2] == "/opt/umu-run");
        assert (record.argv[3] == "game");
    }

    private void test_preserves_spaces_quotes_and_empty_arguments () {
        var record = record_for (
            "/usr/bin/tool",
            { "/usr/bin/tool", "editor notes.exe", "", "a quoted \"value\"", "two words" }
        );
        assert (record.argv.size == 5);
        assert (record.argv[1] == "editor notes.exe");
        assert (record.argv[2] == "");
        assert (record.argv[3] == "a quoted \"value\"");
        assert (record.argv[4] == "two words");
    }

    private void test_detects_supported_runner_tokens () {
        string[] executables = {
            "/tmp/Proton/proton", "/tmp/Proton/umu", "/tmp/Proton/umu-run",
            "/tmp/Proton/wine", "/tmp/Proton/wine64"
        };
        foreach (var executable in executables) {
            assert (CompatibilityProcessGuard.is_compatibility_process (
                record_for (executable, { executable })
            ));
        }
    }

    private void test_detects_runner_token_after_argv_zero () {
        var process = record_for (
            "/usr/bin/env", { "/usr/bin/env", "WINEDEBUG=-all", "/opt/Proton/proton", "run" }
        );
        assert (CompatibilityProcessGuard.is_compatibility_process (process));
        var result = inspect_records (process, "/opt/Proton");
        assert (result.status == CompatibilityProcessInspectionStatus.ACTIVE);
    }

    private void test_ignores_lookalikes_and_text () {
        assert (!CompatibilityProcessGuard.is_compatibility_process (record_for (
            "/tmp/protonplus-tests", { "/tmp/protonplus-tests" }
        )));
        assert (!CompatibilityProcessGuard.is_compatibility_process (record_for (
            "/usr/lib/protonmail/bridge/proton-bridge", { "/usr/bin/protonmail-bridge" }
        )));
        assert (!CompatibilityProcessGuard.is_compatibility_process (record_for (
            "/tmp/proton-custom", { "/tmp/proton-custom" }
        )));
        assert (!CompatibilityProcessGuard.is_compatibility_process (record_for (
            "/tmp/wine-helper", { "/tmp/wine-helper" }
        )));
        assert (!CompatibilityProcessGuard.is_compatibility_process (record_for (
            "/tmp/unrelated-winery", { "/tmp/unrelated-winery" }
        )));
        assert (!CompatibilityProcessGuard.is_compatibility_process (record_for (
            "/usr/bin/editor", { "/usr/bin/editor", "editor notes.EXE" }
        )));
        assert (inspect_records (record_for (
            "/usr/bin/editor", { "/usr/bin/editor", "/tmp/target/notes.EXE" }
        )).status == CompatibilityProcessInspectionStatus.CLEAR);
        assert (!CompatibilityProcessGuard.is_compatibility_process (record_for (
            "/usr/bin/echo", { "echo", "Proton is mentioned in this text argument" }
        )));
    }

    private void test_recognizes_case_preloaders_and_wineserver () {
        string[] executables = {
            "/tmp/target/PROTON", "/tmp/target/UMU-RUN",
            "/tmp/target/WINE-PRELOADER", "/tmp/target/WINE64-PRELOADER",
            "/tmp/target/WINESERVER"
        };
        foreach (var executable in executables) {
            assert (CompatibilityProcessGuard.is_compatibility_process (
                record_for (executable, { executable, "/games/GAME.EXE" })
            ));
            assert (inspect_records (record_for (
                executable, { executable, "/games/GAME.EXE" }
            )).status == CompatibilityProcessInspectionStatus.ACTIVE);
        }
        var uppercase_exe = inspect_records (record_for (
            "/usr/bin/WINE64", { "/usr/bin/WINE64", "/tmp/target/GAME.EXE" }
        ));
        assert (uppercase_exe.status == CompatibilityProcessInspectionStatus.ACTIVE);
        assert (uppercase_exe.blocker_reason ==
            CompatibilityProcessMatchReason.ARGUMENT_PATH_IN_TARGET);
    }

    private void test_target_aware_association () {
        var process = record_for (
            "/tools/Tool A/files/bin/wine64-preloader",
            { "/tools/Tool A/files/bin/wine64-preloader", "/games/GAME.EXE" }
        );
        assert (inspect_records (process, "/tools/Tool A").status ==
            CompatibilityProcessInspectionStatus.ACTIVE);
        assert (inspect_records (process, "/tools/Tool B").status ==
            CompatibilityProcessInspectionStatus.CLEAR);
        assert (inspect_records (process, "/tools/Tool B", false).status ==
            CompatibilityProcessInspectionStatus.CLEAR);
    }

    private void test_path_prefix_boundary () {
        var process = record_for (
            "/tools/Tool-Other/proton", { "/tools/Tool-Other/proton", "run" }
        );
        assert (inspect_records (process, "/tools/Tool").status ==
            CompatibilityProcessInspectionStatus.CLEAR);
    }

    private void test_shared_physical_target () {
        var process = record_for (
            "/shared/compatibilitytools.d/Tool/proton",
            { "/shared/compatibilitytools.d/Tool/proton", "run" }
        );
        var records = new Gee.ArrayList<CompatibilityProcessRecord> ();
        records.add (process);
        var first = operation_context (
            "/shared/compatibilitytools.d/Tool", true, "steam-system", "steam-system"
        );
        var second = operation_context (
            "/shared/compatibilitytools.d/Tool", true, "steam-system", "faugus-system", "faugus"
        );
        assert (first.launcher_family_id != second.launcher_family_id);
        assert (first.launcher_instance_id != second.launcher_instance_id);
        assert (first.tool_target_id == second.tool_target_id);
        assert (CompatibilityProcessGuard.inspect_records (records, second).status ==
            CompatibilityProcessInspectionStatus.ACTIVE);
    }

    private void test_returns_blocker_details () {
        var result = inspect_records (record_for (
            "/usr/bin/env", { "/usr/bin/env", "/opt/Proton/umu-run" }, 8675
        ), "/opt/Proton");
        assert (result.status == CompatibilityProcessInspectionStatus.ACTIVE);
        assert (result.blocker != null);
        assert (((!) result.blocker).pid == 8675);
        assert (((!) result.blocker).executable_path == "/usr/bin/env");
        assert (((!) result.blocker).argv[1] == "/opt/Proton/umu-run");
        assert (result.blocker_reason == CompatibilityProcessMatchReason.ARGUMENT_PATH_IN_TARGET);
        assert (result.inspection_error == null);
    }

    private void test_flatpak_host_query_success () {
        var output = flatpak_record_output (
            501, "/usr/bin/env", { "/usr/bin/env", "/opt/Proton/proton", "run" }
        );
        var result = inspect_flatpak (new ProtonPlus.Utils.CommandResult (output, "", 0));
        assert (result.status == CompatibilityProcessInspectionStatus.ACTIVE);
        assert (result.blocker != null && ((!) result.blocker).pid == 501);
        assert (((!) result.blocker).argv[1] == "/opt/Proton/proton");
    }

    private void test_flatpak_completed_empty_scan () {
        var result = inspect_flatpak (new ProtonPlus.Utils.CommandResult ("S\tOK\n", "", 0));
        assert (result.status == CompatibilityProcessInspectionStatus.CLEAR);
    }

    private void test_flatpak_empty_output_is_unknown () {
        var result = inspect_flatpak (new ProtonPlus.Utils.CommandResult ("", "", 0));
        assert (result.status == CompatibilityProcessInspectionStatus.UNKNOWN);
        assert (result.inspection_error != null &&
            ((!) result.inspection_error).contains ("did not report a completed scan"));
    }

    private void test_flatpak_failed_relevant_read () {
        var partial = "R\t501\t%s\t%s\nS\tFAILED\n".printf (
            Base64.encode ("/usr/bin/env".data),
            Base64.encode (encode_cmdline ({ "/usr/bin/env", "/opt/Proton/proton" }))
        );
        var result = inspect_flatpak (new ProtonPlus.Utils.CommandResult (partial, "", 71));
        assert (result.status == CompatibilityProcessInspectionStatus.UNKNOWN);
        assert (result.inspection_error != null &&
            ((!) result.inspection_error).contains ("status 71"));
    }

    private void test_flatpak_host_query_launch_failure () {
        var result = inspect_flatpak (new ProtonPlus.Utils.CommandResult (
            "", "flatpak-spawn was not found", -1
        ));
        assert (result.status == CompatibilityProcessInspectionStatus.UNKNOWN);
        assert (result.inspection_error != null &&
            ((!) result.inspection_error).contains ("Unable to launch"));
    }

    private void test_flatpak_host_query_nonzero_exit () {
        var result = inspect_flatpak (new ProtonPlus.Utils.CommandResult (
            "", "host query denied", 126
        ));
        assert (result.status == CompatibilityProcessInspectionStatus.UNKNOWN);
        assert (result.inspection_error != null &&
            ((!) result.inspection_error).contains ("status 126"));
    }

    private void test_native_top_level_proc_failure () {
        var backend = new NativeCompatibilityProcessQueryBackend (
            "/path/that/does/not/exist/protonplus-proc"
        );
        var result = inspect_guard (new CompatibilityProcessGuard (backend));
        assert (result.status == CompatibilityProcessInspectionStatus.UNKNOWN);
        assert (result.inspection_error != null);
    }

    private void test_native_disappearing_process () {
        var root = temporary_directory ();
        try {
            /* A dangling proc entry models a PID that vanished after the
             * directory enumeration snapshot but before cmdline was read. */
            assert (FileUtils.symlink ("missing-process", Path.build_filename (root, "4101")) == 0);
            assert (inspect_native (root).status == CompatibilityProcessInspectionStatus.CLEAR);
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_native_empty_cmdline () {
        var root = temporary_directory ();
        var process_root = Path.build_filename (root, "4102");
        try {
            assert (ProtonPlus.Utils.Filesystem.create_directory (process_root));
            write_cmdline (process_root, {});
            assert (inspect_native (root).status == CompatibilityProcessInspectionStatus.CLEAR);
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_native_executable_read_failure () {
        var root = temporary_directory ();
        var process_root = Path.build_filename (root, "4103");
        try {
            assert (ProtonPlus.Utils.Filesystem.create_directory (process_root));
            write_cmdline (process_root, { "/opt/Proton/proton", "run" });
            ProtonPlus.Utils.Filesystem.create_file (
                Path.build_filename (process_root, "exe"), "not a symlink"
            );
            var result = inspect_native (root);
            assert (result.status == CompatibilityProcessInspectionStatus.UNKNOWN);
            assert (result.inspection_error != null &&
                ((!) result.inspection_error).contains ("executable"));
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_native_cmdline_read_failure () {
        var root = temporary_directory ();
        var process_root = Path.build_filename (root, "4104");
        try {
            assert (ProtonPlus.Utils.Filesystem.create_directory (process_root));
            var result = inspect_native (root);
            assert (result.status == CompatibilityProcessInspectionStatus.UNKNOWN);
            assert (result.inspection_error != null &&
                ((!) result.inspection_error).contains ("command line"));
        } finally {
            assert (delete_directory (root));
        }
    }

    private void test_unknown_blocks_mutations_but_allows_new_destination () {
        var root = temporary_directory ();
        var tools = Path.build_filename (root, "tools");
        var cache = Path.build_filename (root, "cache");
        var existing = Path.build_filename (tools, "Existing Runner");
        var fresh = Path.build_filename (tools, "Fresh Runner");
        var previous_cache = Globals.CACHE_PATH;
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CACHE_PATH = cache;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (
            CpuArchitecture.X86_64, X86_64Level.BASELINE
        );
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        var runner = fixture_runner (tools);
        assert (ProtonPlus.Utils.Filesystem.create_directory (existing));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (existing, "marker"), "preserved"
        );

        var unknown = CompatibilityProcessInspectionResult.unknown (
            "fixture process inspection failure"
        );
        InstallationService.instance.configure_compatibility_process_guard (
            new CompatibilityProcessGuard (new FixtureBackend (unknown))
        );

        var replacement = new FailingDownloadJob (
            fixture_release (), runner, existing
        );
        assert (install_job (replacement, true) == ReturnCode.PROCESS_INSPECTION_FAILED);
        assert (replacement.download_calls == 0);
        assert (ProtonPlus.Utils.Filesystem.get_file_content (
            Path.build_filename (existing, "marker")
        ) == "preserved");

        assert (remove_job (replacement) == ReturnCode.PROCESS_INSPECTION_FAILED);
        assert (FileUtils.test (existing, FileTest.IS_DIR));

        var new_install = new FailingDownloadJob (
            fixture_release (), runner, fresh
        );
        assert (install_job (new_install, false) == ReturnCode.DOWNLOAD_FAILED);
        assert (new_install.download_calls == 1);
        assert (!FileUtils.test (fresh, FileTest.EXISTS));

        InstallationService.reset_lifecycle_configuration_for_tests ();
        Globals.CACHE_PATH = previous_cache;
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }

    private void test_tool_a_blocks_only_tool_a_mutations () {
        var root = temporary_directory ();
        var tools = Path.build_filename (root, "tools");
        var cache = Path.build_filename (root, "cache");
        var tool_a = Path.build_filename (tools, "Tool A");
        var tool_b = Path.build_filename (tools, "Tool B");
        var previous_cache = Globals.CACHE_PATH;
        var previous_capabilities = Globals.CPU_CAPABILITIES;
        Globals.CACHE_PATH = cache;
        Globals.CPU_CAPABILITIES = new CpuCapabilities (
            CpuArchitecture.X86_64, X86_64Level.BASELINE
        );
        assert (ProtonPlus.Utils.Filesystem.create_directory (cache));
        var runner = fixture_runner (tools);
        assert (ProtonPlus.Utils.Filesystem.create_directory (tool_a));
        ProtonPlus.Utils.Filesystem.create_file (
            Path.build_filename (tool_a, "marker"), "preserved"
        );

        var records = new Gee.ArrayList<CompatibilityProcessRecord> ();
        records.add (record_for (
            Path.build_filename (tool_a, "files", "bin", "wine64-preloader"),
            { Path.build_filename (tool_a, "files", "bin", "wine64-preloader"), "/games/game.exe" }
        ));
        InstallationService.instance.configure_compatibility_process_guard (
            new CompatibilityProcessGuard (
                new FixtureBackend (CompatibilityProcessInspectionResult.clear (records))
            )
        );

        var installed = new FailingDownloadJob (fixture_release (), runner, tool_a);
        assert (install_job (installed, true) == ReturnCode.RUNNERS_IN_USE);
        assert (installed.download_calls == 0);
        assert (remove_job (installed) == ReturnCode.RUNNERS_IN_USE);
        assert (FileUtils.test (tool_a, FileTest.IS_DIR));

        var fresh = new FailingDownloadJob (fixture_release (), runner, tool_b);
        assert (install_job (fresh, false) == ReturnCode.DOWNLOAD_FAILED);
        assert (fresh.download_calls == 1);
        assert (!FileUtils.test (tool_b, FileTest.EXISTS));

        InstallationService.reset_lifecycle_configuration_for_tests ();
        Globals.CACHE_PATH = previous_cache;
        Globals.CPU_CAPABILITIES = previous_capabilities;
        assert (delete_directory (root));
    }
}
