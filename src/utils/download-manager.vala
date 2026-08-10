namespace ProtonPlus.Utils {
    /// Manages active downloads and download history persistence.
    public class DownloadManager : GLib.Object {
        private const string SPEED_LIMIT_SETTINGS_KEY = "download-speed-limit-bps";
        private static DownloadManager? _instance = null;
        private ulong speed_limit_settings_changed_handler = 0;
        private int64 global_throttle_next_allowed_time_us = 0;
        private uint64 _throttle_generation = 0;
        private int64 _speed_limit_bps = 0;
        public static DownloadManager instance {
            get {
                if (_instance == null) {
                    _instance = new DownloadManager ();
                }
                return _instance;
            }
        }

        public Gee.LinkedList<Services.InstallJob> active_downloads { get; private set; }

        public int64 speed_limit_bps {
            get {
                return _speed_limit_bps;
            }
            set {
                var normalized_limit = value > 0 ? value : 0;
                if (_speed_limit_bps == normalized_limit)
                    return;

                _speed_limit_bps = normalized_limit;
                invalidate_throttle_schedule ();

                if (Globals.SETTINGS != null) {
                    var persisted = Globals.SETTINGS.get_int64 (SPEED_LIMIT_SETTINGS_KEY);
                    if (persisted != _speed_limit_bps)
                        Globals.SETTINGS.set_int64 (SPEED_LIMIT_SETTINGS_KEY, _speed_limit_bps);
                }

                speed_limit_changed (_speed_limit_bps);
            }
        }

        public uint64 throttle_generation {
            get {
                return _throttle_generation;
            }
        }

        /// Checks whether this target-bound operation is currently active.
        public bool is_downloading (Services.InstallJob job) {
            return get_active_download (job) != null;
        }

        /// Stable target identity prevents collisions between equal titles.
        public Services.InstallJob? get_active_download (Services.InstallJob job) {
            foreach (var active_download in active_downloads) {
                if (active_download.operation_id == job.operation_id) {
                    return active_download;
                }
            }
            return null;
        }

        public bool has_active_installation_at (string install_location) {
            foreach (var active_download in active_downloads) {
                if (active_download.install_location == install_location)
                    return true;
            }
            return false;
        }

        /// Signals emitted when download state changes.
        public signal void download_added (Services.InstallJob job);
        public signal void download_removed (Services.InstallJob job);
        public signal void download_finished (Services.InstallJob job, bool success);
        public signal void progress_updated (Services.InstallJob job);
        public signal void tool_updated (Services.InstallJob job, bool updated);
        public signal void tool_removed (Services.InstallJob job);
        public signal void speed_limit_changed (int64 new_limit);

        private DownloadManager () {
            active_downloads = new Gee.LinkedList<Services.InstallJob> ();
            sync_speed_limit_from_settings ();
        }

        public void sync_speed_limit_from_settings () {
            if (Globals.SETTINGS == null)
                return;

            if (speed_limit_settings_changed_handler == 0) {
                speed_limit_settings_changed_handler = Globals.SETTINGS.changed[SPEED_LIMIT_SETTINGS_KEY].connect (() => {
                    var next_limit = Globals.SETTINGS.get_int64 (SPEED_LIMIT_SETTINGS_KEY);
                    if (next_limit < 0)
                        next_limit = 0;
                    if (speed_limit_bps != next_limit)
                        speed_limit_bps = next_limit;
                });
            }

            var configured_limit = Globals.SETTINGS.get_int64 (SPEED_LIMIT_SETTINGS_KEY);
            if (configured_limit < 0) {
                configured_limit = 0;
                Globals.SETTINGS.set_int64 (SPEED_LIMIT_SETTINGS_KEY, configured_limit);
            }
            if (speed_limit_bps != configured_limit)
                speed_limit_bps = configured_limit;
        }

        private void invalidate_throttle_schedule () {
            global_throttle_next_allowed_time_us = 0;
            _throttle_generation++;
        }

        public void add_download (Services.InstallJob job) {
            if (!is_downloading (job)) {
                active_downloads.add (job);
                download_added (job);
            }
        }

        public void remove_download (Services.InstallJob job) {
            if (active_downloads.contains (job)) {
                active_downloads.remove (job);
                download_removed (job);
            }
        }

        public void add_to_history (Services.InstallJob job, bool success) {
            download_finished (job, success);
        }

        private async void wait_for_throttle_deadline (
            int64 deadline_us,
            uint64 expected_generation,
            Cancellable? cancellable
        ) {
            while (true) {
                if (cancellable != null && cancellable.is_cancelled ())
                    return;
                if (_throttle_generation != expected_generation)
                    return;

                int64 now_us = get_monotonic_time ();
                if (now_us >= deadline_us)
                    return;

                uint remaining_ms = (uint) ((deadline_us - now_us + 999) / 1000);
                if (remaining_ms > 25)
                    remaining_ms = 25;

                var source = new TimeoutSource (remaining_ms);
                source.set_callback (() => {
                    wait_for_throttle_deadline.callback ();
                    return Source.REMOVE;
                });

                source.attach (MainContext.default ());
                yield;
            }
        }

        /// Applies a shared throttle budget across all active downloads.
        public async void throttle_global_download_bytes (
            int64 bytes_written,
            int64 transfer_started_us,
            uint64 expected_generation,
            Cancellable? cancellable = null
        ) {
            if (bytes_written <= 0)
                return;
            if (_throttle_generation != expected_generation)
                return;

            int64 speed_limit = speed_limit_bps;
            if (speed_limit <= 0)
                return;

            int64 now_us = get_monotonic_time ();
            int64 schedule_base_us = global_throttle_next_allowed_time_us;
            if (transfer_started_us > schedule_base_us && transfer_started_us < now_us)
                schedule_base_us = transfer_started_us;
            if (schedule_base_us == 0)
                schedule_base_us = now_us;

            int64 chunk_budget_us = (bytes_written * 1000000) / speed_limit;
            global_throttle_next_allowed_time_us = schedule_base_us + chunk_budget_us;

            if (global_throttle_next_allowed_time_us < now_us)
                global_throttle_next_allowed_time_us = now_us;

            int64 delay_us = global_throttle_next_allowed_time_us - now_us;
            if (delay_us > 0)
                yield wait_for_throttle_deadline (
                    global_throttle_next_allowed_time_us,
                    expected_generation,
                    cancellable
                );
        }

    }
}
