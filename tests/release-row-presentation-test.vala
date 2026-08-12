namespace AppTests.ReleaseRowPresentationTest {
    using ProtonPlus.Models;
    using ProtonPlus.Services;
    using ProtonPlus.Widgets.Tools;

    private class FixtureSignalTarget : Object, ReleaseRowJobSignalTarget {
        public int callbacks { get; private set; default = 0; }

        public void release_row_job_state_changed () { callbacks++; }
        public void release_row_job_step_changed () { callbacks++; }
        public void release_row_job_progress_changed () { callbacks++; }
        public void release_row_job_canceled_changed () { callbacks++; }
        public void release_row_job_variant_changed () { callbacks++; }
        public void release_row_job_release_changed () { callbacks++; }
    }

    private ReleaseRowPresentation presentation (
        InstallJob.State state,
        InstallJob.Step step = InstallJob.Step.NOTHING,
        bool rolling = false,
        bool has_directory = false,
        bool canceled = false,
        bool recommended = false,
        bool in_use = false,
        bool available = true,
        ReleaseRowRetryAction retry = ReleaseRowRetryAction.NONE
    ) {
        return ReleaseRowPresentation.evaluate (
            state, step, rolling, has_directory, canceled,
            recommended, in_use, available, retry
        );
    }

    private void test_recommended () {
        var current = presentation (
            InstallJob.State.NOT_INSTALLED, InstallJob.Step.NOTHING,
            false, false, false, true
        );
        assert (current.recommended);
        assert (current.primary_action == ReleaseRowPrimaryAction.INSTALL);
    }

    private void test_not_installed () {
        var current = presentation (InstallJob.State.NOT_INSTALLED);
        assert (current.primary_action == ReleaseRowPrimaryAction.INSTALL);
        assert (!current.installed && !current.busy);
        assert (!current.show_menu);

        assert (!current.show_update_action);
    }

    private void test_installed_current () {
        var current = presentation (
            InstallJob.State.UP_TO_DATE, InstallJob.Step.NOTHING,
            false, true
        );
        assert (current.primary_action == ReleaseRowPrimaryAction.NONE);
        assert (current.installed && current.show_menu);
        assert (current.show_open_folder && current.show_delete);
        assert (!current.show_update_action);
        assert (!current.in_use);
    }

    private void test_installed_and_in_use () {
        var current = presentation (
            InstallJob.State.UP_TO_DATE, InstallJob.Step.NOTHING,
            false, true, false, false, true
        );
        assert (current.installed && current.in_use);
        assert (!current.update_available);
    }

    private void test_update_available () {
        var current = presentation (
            InstallJob.State.UPDATE_AVAILABLE, InstallJob.Step.NOTHING,
            true, true
        );
        assert (current.primary_action == ReleaseRowPrimaryAction.NONE);
        assert (current.show_menu && current.show_update_action);
        assert (current.show_open_folder && current.show_delete);
    }

    private void test_rolling_update_check () {
        var current = presentation (
            InstallJob.State.UP_TO_DATE, InstallJob.Step.NOTHING,
            true, true
        );
        assert (current.show_update_action);
        assert (current.show_menu);
    }

    private void test_downloading () {
        var current = presentation (
            InstallJob.State.BUSY_INSTALLING,
            InstallJob.Step.DOWNLOADING, true, true
        );
        assert (current.primary_action == ReleaseRowPrimaryAction.PROGRESS);
        assert (current.busy && !current.progress_indeterminate);
        assert (current.show_cancel && current.cancel_enabled);
        assert (!current.show_menu && !current.show_delete);
    }

    private void test_extracting_and_moving () {
        InstallJob.Step[] steps = {
            InstallJob.Step.EXTRACTING,
            InstallJob.Step.MOVING
        };
        foreach (var step in steps) {
            var current = presentation (
                InstallJob.State.BUSY_UPDATING, step, true, true
            );
            assert (current.primary_action == ReleaseRowPrimaryAction.PROGRESS);
            assert (current.progress_indeterminate);
            assert (current.show_cancel && !current.show_menu);
        }
    }

    private void test_removing () {
        var current = presentation (
            InstallJob.State.BUSY_REMOVING,
            InstallJob.Step.REMOVING, true, true
        );
        assert (current.primary_action == ReleaseRowPrimaryAction.PROGRESS);
        assert (current.progress_indeterminate);
        assert (!current.show_cancel && !current.show_menu);
    }

    private void test_cancellation () {
        var current = presentation (
            InstallJob.State.BUSY_INSTALLING,
            InstallJob.Step.DOWNLOADING, false, false, true
        );
        assert (current.show_cancel && !current.cancel_enabled);
        assert (!current.show_menu);
    }

    private void test_failed_operations_restore_actual_state () {
        var failed_install = presentation (
            InstallJob.State.NOT_INSTALLED, InstallJob.Step.NOTHING,
            false, false, false, false, false, true,
            ReleaseRowRetryAction.INSTALL
        );
        assert (failed_install.primary_action == ReleaseRowPrimaryAction.RETRY);
        assert (!failed_install.show_delete);

        var failed_update = presentation (
            InstallJob.State.UPDATE_AVAILABLE, InstallJob.Step.NOTHING,
            true, true, false, false, false, true,
            ReleaseRowRetryAction.UPDATE
        );
        assert (failed_update.primary_action == ReleaseRowPrimaryAction.NONE);
        assert (failed_update.show_update_action);
        assert (failed_update.show_delete);

        var failed_removal = presentation (
            InstallJob.State.UP_TO_DATE, InstallJob.Step.NOTHING,
            false, true
        );
        assert (failed_removal.primary_action == ReleaseRowPrimaryAction.NONE);
        assert (failed_removal.show_open_folder && failed_removal.show_delete);
    }

    private void test_unavailable_action () {
        var unavailable = presentation (
            InstallJob.State.NOT_INSTALLED, InstallJob.Step.NOTHING,
            false, false, false, false, false, false
        );
        assert (unavailable.unavailable);
        assert (unavailable.primary_action == ReleaseRowPrimaryAction.NONE);
        assert (!unavailable.show_menu);

        var installed = presentation (
            InstallJob.State.UP_TO_DATE, InstallJob.Step.NOTHING,
            true, true, false, false, false, false
        );
        assert (installed.primary_action == ReleaseRowPrimaryAction.NONE);
        assert (!installed.show_update_action);
        assert (installed.show_open_folder && installed.show_delete);
    }

    private void test_readable_timestamp () {
        const string raw = "2026-08-11T18:55:19-04:00";
        var formatted = ProtonPlus.Utils.format_timestamp (raw);
        assert (formatted != raw);
        assert (!formatted.contains ("T"));
        assert (formatted.contains ("2026"));
        assert (formatted.contains ("·"));
        assert (ProtonPlus.Utils.format_timestamp ("not-a-date") == "not-a-date");
    }

    private void test_latest_row_has_distinct_title () {
        var launcher = new Launcher (
            "Fixture", Launcher.InstallationTypes.SYSTEM, "", {}, "fixture"
        );
        var group = new Group ("Fixture", "", "", launcher, "fixture");
        var tool = new ProtonPlus.Models.Tools.SteamTinkerLaunch (group);
        var release = new Release (
            "Fixture release", "", "",
            new ProtonPlus.Models.Assets.Asset (
                "fixture.zip", "https://example.test/fixture.zip"
            ),
            "https://example.test/release", 0, "fixture", "fixture"
        );
        var latest = new InstallJob (release, tool, InstallJob.Mode.LATEST);
        var versioned = new InstallJob (release, tool, InstallJob.Mode.VERSIONED);

        var latest_title = ReleaseRow.release_display_title (latest);
        var versioned_title = ReleaseRow.release_display_title (versioned);
        assert (latest_title != versioned_title);
        assert (!latest_title.contains ("Fixture release"));
        assert (versioned_title == "Fixture release");
    }

    private void test_disposal_during_active_job_disconnects_callbacks () {
        var launcher = new Launcher (
            "Fixture", Launcher.InstallationTypes.SYSTEM, "", {}, "fixture"
        );
        var group = new Group ("Fixture", "", "", launcher, "fixture");
        var tool = new ProtonPlus.Models.Tools.SteamTinkerLaunch (group);
        var release = new Release (
            "Fixture release", "", "",
            new ProtonPlus.Models.Assets.Asset (
                "fixture.zip", "https://example.test/fixture.zip"
            ),
            "https://example.test/release", 0, "fixture", "fixture"
        );
        var job = new InstallJob (release, tool);
        FixtureSignalTarget? target = new FixtureSignalTarget ();
        var target_ref = WeakRef (target);
        var binding = new ReleaseRowJobSignalBinding (job, (!) target);

        job.notify_property ("state");
        job.notify_property ("step");
        job.progress_updated ();
        assert (((!) target).callbacks == 3);
        binding.disconnect_handlers ();
        assert (!binding.connected);

        job.notify_property ("state");
        job.notify_property ("step");
        job.progress_updated ();
        assert (((!) target).callbacks == 3);
        target = null;
        assert (target_ref.get () == null);
    }

    public void register_tests () {
        Test.add_func ("/release-row-presentation/not-installed", test_not_installed);
        Test.add_func ("/release-row-presentation/recommended", test_recommended);
        Test.add_func ("/release-row-presentation/installed-current", test_installed_current);
        Test.add_func ("/release-row-presentation/installed-in-use", test_installed_and_in_use);
        Test.add_func ("/release-row-presentation/update-available", test_update_available);
        Test.add_func ("/release-row-presentation/rolling-update-check", test_rolling_update_check);
        Test.add_func ("/release-row-presentation/downloading", test_downloading);
        Test.add_func ("/release-row-presentation/extracting-moving", test_extracting_and_moving);
        Test.add_func ("/release-row-presentation/removing", test_removing);
        Test.add_func ("/release-row-presentation/cancellation", test_cancellation);
        Test.add_func ("/release-row-presentation/failed-operations", test_failed_operations_restore_actual_state);
        Test.add_func ("/release-row-presentation/unavailable-action", test_unavailable_action);
        Test.add_func ("/release-row-presentation/readable-timestamp", test_readable_timestamp);
        Test.add_func (
            "/release-row-presentation/distinct-latest-title",
            test_latest_row_has_distinct_title
        );
        Test.add_func (
            "/release-row-presentation/dispose-active-job",
            test_disposal_during_active_job_disconnects_callbacks
        );
    }
}
