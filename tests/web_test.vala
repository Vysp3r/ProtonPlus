namespace AppTests.WebTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/web/api-session-isolation", test_api_isolation);
        foreach (var scenario in new string[] { "resume", "cancel", "changed", "ignored", "range", "416", "exhaustion", "window", "deadline", "redirect", "permanent", "permanent-after-retry" }) {
            var name = scenario;
            Test.add_data_func ("/web/persistent/" + name, () => { run_persistent_test (name); });
        }
        foreach (var scenario in new string[] { "valid", "stale", "malformed", "missing-body", "missing-metadata", "size", "identity", "weak", "encoding", "version", "symlink", "concurrent", "expiry", "clear", "count-limit", "byte-limit" }) {
            var name = scenario;
            Test.add_data_func ("/web/partial-cache/" + name, () => { run_cache_test (name); });
        }
        Test.add_func ("/web/download-retry-after-date", () => { run_recovery_test ("retry-after-date"); });
        Test.add_func ("/web/download-retry-after-long", () => { run_recovery_test ("retry-after-long"); });
        Test.add_func ("/web/download-retry-after", () => { run_recovery_test ("retry-after"); });
        Test.add_func ("/web/download-cancel-completion", () => { run_recovery_test ("cancel-completion"); });
        Test.add_func ("/web/download-cancel-read", () => { run_recovery_test ("cancel-read"); });
        Test.add_func ("/web/download-redirect", () => { run_recovery_test ("redirect"); });
        Test.add_func ("/web/download-stalled-body", () => { run_recovery_test ("stalled-body"); });
        Test.add_func ("/web/download-resume", () => { run_recovery_test ("resume"); });
        Test.add_func ("/web/download-repeated-drop", () => { run_recovery_test ("repeated-drop"); });
        Test.add_func ("/web/download-ignored-range", () => { run_recovery_test ("ignored-range"); });
        Test.add_func ("/web/download-changed-asset", () => { run_recovery_test ("changed-asset"); });
        Test.add_func ("/web/download-no-validator", () => { run_recovery_test ("no-validator"); });
        Test.add_func ("/web/download-weak-validator", () => { run_recovery_test ("weak-validator"); });
        Test.add_func ("/web/download-invalid-range", () => { run_recovery_test ("invalid-range"); });
        Test.add_func ("/web/download-changed-validator", () => { run_recovery_test ("changed-validator"); });
        Test.add_func ("/web/download-range-rejected", () => { run_recovery_test ("range-rejected"); });
        Test.add_func ("/web/download-cancel-backoff", () => { run_recovery_test ("cancel-backoff"); });
        Test.add_func ("/web/download-http-retry", () => { run_recovery_test ("http-retry"); });
        Test.add_func ("/web/download-http-permanent", () => { run_recovery_test ("http-permanent"); });
        Test.add_func ("/web/download-existing-file", () => { run_recovery_test ("existing-file"); });
        Test.add_func ("/web/download-unknown-size", () => { run_recovery_test ("unknown-size"); });
        Test.add_func ("/web/download-recovers-after-timeout", test_download_recovers_after_timeout);
        Test.add_func ("/web/download-exhausts-timeout-retries", test_download_exhausts_timeout_retries);
        Test.add_func ("/web/download-cancels-during-throttle", test_download_cancels_during_throttle);
        Test.add_func ("/web/download-respects-whole-download-speed-limit", test_download_respects_whole_download_speed_limit);
        Test.add_func ("/web/download-shares-global-speed-limit", test_download_shares_global_speed_limit);
        Test.add_func ("/web/download-throttle-credits-transfer-time", test_download_throttle_credits_transfer_time);
        Test.add_func ("/web/download-throttle-reacts-to-limit-change", test_download_throttle_reacts_to_limit_change);
    }

    private void run_recovery_test (string scenario) {
        if (scenario == "invalid-range" || scenario == "changed-validator")
            Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Invalid resumed download response*");
        if (scenario == "retry-after-long")
            Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*HTTP 503*");
        if (scenario == "existing-file")
            Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*exists*");
        var loop = new MainLoop ();
        recovery_test_async.begin (scenario, (obj, res) => {
            recovery_test_async.end (res);
            loop.quit ();
        });
        loop.run ();
        Test.assert_expected_messages ();
    }

    // Raw responses deliberately truncate the body; Soup.Server's normal response
    // helpers would repair framing and hide the interrupted-transfer regression.
    private async void send_test_response (IOStream connection, string response, bool keep_open = false) {
        try {
            size_t written;
            yield connection.output_stream.write_all_async (response.data, Priority.DEFAULT, null, out written);
            if (!keep_open)
                yield connection.close_async (Priority.DEFAULT, null);
        } catch (Error e) {
            Test.message ("Fixture response failed: %s", e.message);
            assert_not_reached ();
        }
    }

    private async void recovery_test_async (string scenario) {
        string payload = "complete archive";
        var server = new Soup.Server ("server-header", "ProtonPlus Test", null);
        int requests = 0;
        int64 first_request_at = 0;
        var cancellable = new Cancellable ();
        IOStream? stalled_connection = null;
        uint cancel_timer = 0;
        var session = ProtonPlus.Utils.Web.get_download_session ();
        var previous_timeout = session.timeout;
        if (scenario == "stalled-body")
            session.timeout = 1;
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        var previous_limit = manager.speed_limit_bps;
        bool check_rate = scenario == "resume" || scenario == "ignored-range" || scenario == "changed-asset";
        if (check_rate)
            manager.speed_limit_bps = 32;
        bool saw_rate = false;
        bool saw_resume_progress = false;
        bool waiting = false;
        int64 cancelled_at = 0;
        server.add_handler ("/redirect", (server, message, path, query) => {
            message.set_redirect (Soup.Status.FOUND, "/archive");
        });
        server.add_handler ("/archive", (server, message, path, query) => {
            requests++;
            if (requests == 1)
                first_request_at = get_monotonic_time ();
            if (requests == 2 && (scenario == "retry-after" || scenario == "retry-after-date"))
                assert (get_monotonic_time () - first_request_at >= 2000000);
            assert (message.get_request_headers ().get_one ("Accept-Encoding") == "identity");
            var range = message.get_request_headers ().get_one ("Range");
            var validator = message.get_request_headers ().get_one ("If-Range");
            string response;
            if ((scenario == "retry-after" || scenario == "retry-after-date" || scenario == "retry-after-long") && requests == 1) {
                response = "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nRetry-After: %s\r\n\r\n".printf (
                    scenario == "retry-after" ? "2" : scenario == "retry-after-date" ? new DateTime.now_utc ().add_seconds (3).format ("%a, %d %b %Y %H:%M:%S GMT") : "1200");
            } else if (scenario == "http-permanent") {
                response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n";
            } else if (scenario == "http-retry" && requests == 1) {
                response = "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\n\r\n";
            } else if (scenario == "existing-file") {
                response = "HTTP/1.1 200 OK\r\nContent-Length: 16\r\n\r\n" + payload;
            } else if (scenario == "unknown-size") {
                response = "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n" + payload;
            } else if (requests == 1) {
                assert (range == null);
                var etag = scenario == "no-validator" ? "" :
                    scenario == "weak-validator" ? "ETag: W/\"asset-v1\"\r\n" : "ETag: \"asset-v1\"\r\n";
                response = "HTTP/1.1 200 OK\r\nContent-Length: 16\r\n" + etag + "\r\n" + payload.substring (0, 5);
            } else if (scenario == "http-retry" || scenario == "retry-after" || scenario == "retry-after-date" || scenario == "no-validator" || scenario == "weak-validator" ||
                       (scenario == "range-rejected" && requests == 3)) {
                assert (range == null);
                assert (validator == null);
                response = "HTTP/1.1 200 OK\r\nContent-Length: 16\r\n\r\n" + payload;
            } else {
                int offset = requests == 3 ? 10 : 5;
                assert (range == "bytes=%d-".printf (offset));
                assert (validator == "\"asset-v1\"");
                if (scenario == "range-rejected") {
                    response = "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */16\r\nContent-Length: 0\r\n\r\n";
                } else if (scenario == "ignored-range" || scenario == "changed-asset") {
                    response = "HTTP/1.1 200 OK\r\nContent-Length: 16\r\nETag: \"asset-v2\"\r\n\r\n" +
                        (scenario == "changed-asset" ? "replaced archive" : payload);
                } else {
                    var body = scenario == "repeated-drop" && requests == 2 ? payload.substring (offset, 5) : payload.substring (offset);
                    response = "HTTP/1.1 206 Partial Content\r\nContent-Length: %d\r\nContent-Range: bytes %d-15/16\r\nETag: %s\r\n\r\n%s".printf (
                        16 - offset, scenario == "invalid-range" ? 0 : offset,
                        scenario == "changed-validator" ? "\"asset-v2\"" : "\"asset-v1\"", body);
                }
            }
            var connection = message.steal_connection ();
            bool stall = requests == 1 && (scenario == "stalled-body" || scenario == "cancel-read");
            if (stall) {
                stalled_connection = connection;
                if (scenario == "cancel-read") {
                    cancel_timer = Timeout.add (100, () => {
                        cancelled_at = get_monotonic_time ();
                        cancellable.cancel ();
                        cancel_timer = 0;
                        return Source.REMOVE;
                    });
                }
            }
            send_test_response.begin (connection, response, stall);
        });

        string root = "";
        try {
            server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY);
            root = DirUtils.make_tmp ("protonplus-resume-test-XXXXXX");
            if (scenario == "existing-file")
                FileUtils.set_contents (Path.build_filename (root, "archive"), "keep me");
        } catch (Error e) {
            assert_not_reached ();
        }
        var destination = Path.build_filename (root, "archive");
        string? error_message;
        var downloaded = yield ProtonPlus.Utils.Web.download (
            "%s%s".printf (server.get_uris ().data.to_string (), scenario == "redirect" ? "redirect" : "archive"), destination, cancellable,
            (percent, progress, speed, remaining) => {
                if (check_rate && percent && progress == 100) {
                    assert (speed * 1024 >= 24 && speed * 1024 <= 36);
                    assert (remaining != null && remaining == 0);
                    saw_rate = true;
                }
                if (scenario == "unknown-size") {
                    assert (!percent);
                    assert (remaining == null);
                }
                if (scenario == "cancel-completion" && percent && progress == 100) {
                    cancelled_at = get_monotonic_time ();
                    cancellable.cancel ();
                }
                if (percent && progress == 31)
                    saw_resume_progress = true;
                if (percent && progress > 0 && speed == 0 && remaining == null) {
                    waiting = true;
                    if (scenario == "cancel-backoff") {
                        if (cancel_timer == 0)
                            cancel_timer = Timeout.add (200, () => {
                                cancelled_at = get_monotonic_time ();
                                cancellable.cancel ();
                                cancel_timer = 0;
                                return Source.REMOVE;
                            });
                    }
                }
            }, out error_message
        );
        manager.speed_limit_bps = previous_limit;
        if (check_rate)
            assert (saw_rate);
        session.timeout = previous_timeout;
        server.disconnect ();
        if (cancel_timer != 0)
            Source.remove (cancel_timer);
        if (stalled_connection != null) {
            try {
                yield stalled_connection.close_async (Priority.DEFAULT, null);
            } catch (Error e) {
                assert_not_reached ();
            }
        }

        bool failed = scenario == "invalid-range" || scenario == "changed-validator" ||
            scenario == "cancel-backoff" || scenario == "cancel-read" || scenario == "cancel-completion" ||
            scenario == "http-permanent" || scenario == "retry-after-long" || scenario == "existing-file";
        assert (downloaded == !failed);
        if (scenario == "cancel-backoff" || scenario == "cancel-read" || scenario == "cancel-completion") {
            if (scenario == "cancel-backoff")
                assert (waiting);
            assert (requests == (scenario == "cancel-completion" ? 2 : 1));
            assert (error_message == null);
            assert (get_monotonic_time () - cancelled_at < 500000);
        } else if (failed) {
            assert (error_message != null);
            assert (requests == (scenario == "http-permanent" || scenario == "retry-after-long" || scenario == "existing-file" ? 1 : 2));
        } else {
            assert (error_message == null);
            assert (requests == (scenario == "unknown-size" ? 1 : scenario == "repeated-drop" || scenario == "range-rejected" ? 3 : 2));
        }
        if (scenario == "resume" || scenario == "repeated-drop")
            assert (saw_resume_progress);
        if (downloaded || scenario == "existing-file") {
            string contents;
            try {
                FileUtils.get_contents (destination, out contents);
                assert (contents == (scenario == "existing-file" ? "keep me" : scenario == "changed-asset" ? "replaced archive" : payload));
            } catch (Error e) {
                assert_not_reached ();
            }
            assert (FileUtils.remove (destination) == 0);
        } else {
            assert (!FileUtils.test (destination, FileTest.EXISTS));
        }
        assert (DirUtils.remove (root) == 0);
    }


    private void test_api_isolation () {
        var api = ProtonPlus.Utils.Web.get_session ();
        var download = ProtonPlus.Utils.Web.get_download_session ();
        assert (api != download);
        var default_timeout = new Soup.Session ().timeout;
        assert (api.timeout == default_timeout);
        assert (download.timeout == 30);
        assert (api.user_agent == download.user_agent);
        var old_settings = ProtonPlus.Globals.SETTINGS;
        string schema_root = "";
        try {
            schema_root = DirUtils.make_tmp ("protonplus-proxy-schema-XXXXXX");
            var schema_name = "com.vysp3r.ProtonPlus.gschema.xml";
            File.new_for_path ("../data/" + schema_name).copy (File.new_for_path (Path.build_filename (schema_root, schema_name)), FileCopyFlags.NONE);
            int status;
            Process.spawn_sync (null, { "glib-compile-schemas", schema_root }, null, SpawnFlags.SEARCH_PATH, null, null, null, out status);
            assert (status == 0);
            var source = new SettingsSchemaSource.from_directory (schema_root, null, false);
            ProtonPlus.Globals.SETTINGS = new Settings.full (source.lookup ("com.vysp3r.ProtonPlus.State", false), null, null);
        } catch (Error e) { assert_not_reached (); }
        var previous_mode = ProtonPlus.Globals.SETTINGS.get_enum ("proxy-mode");
        var previous_url = ProtonPlus.Globals.SETTINGS.get_string ("proxy-url");
        ProtonPlus.Globals.SETTINGS.set_string ("proxy-url", "http://127.0.0.1:12345");
        ProtonPlus.Globals.SETTINGS.set_enum ("proxy-mode", 1);
        download = ProtonPlus.Utils.Web.get_download_session ();
        assert (api.proxy_resolver == download.proxy_resolver);
        try {
            var proxies = api.proxy_resolver.lookup ("https://example.invalid");
            assert (proxies[0] == "http://127.0.0.1:12345");
        } catch (Error e) { assert_not_reached (); }
        download.timeout = 7;
        assert (api.timeout == default_timeout);
        download.timeout = 30;
        ProtonPlus.Globals.SETTINGS.set_enum ("proxy-mode", previous_mode);
        ProtonPlus.Globals.SETTINGS.set_string ("proxy-url", previous_url);
        ProtonPlus.Utils.Web.update_proxy_settings ();
        assert (ProtonPlus.Utils.Web.get_download_session ().proxy_resolver == api.proxy_resolver);
        ProtonPlus.Globals.SETTINGS = old_settings;
        ProtonPlus.Utils.Web.update_proxy_settings ();
        FileUtils.remove (Path.build_filename (schema_root, "gschemas.compiled"));
        FileUtils.remove (Path.build_filename (schema_root, "com.vysp3r.ProtonPlus.gschema.xml"));
        DirUtils.remove (schema_root);
    }

    private void run_persistent_test (string scenario) {
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*");
        var loop = new MainLoop ();
        persistent_test.begin (scenario, (obj, res) => {
            persistent_test.end (res);
            loop.quit ();
        });
        loop.run ();
        Test.assert_expected_messages ();
    }

    private async void persistent_test (string scenario) {
        var server = new Soup.Server ("server-header", "ProtonPlus Test", null);
        int requests = 0;
        IOStream? stalled = null;
        int redirects = 0;
        string metadata_during_transfer = "";
        server.add_handler ("/source", (server, message, path, query) => {
            redirects++;
            message.set_redirect (Soup.Status.FOUND, "/asset?token=%d".printf (redirects));
        });
        server.add_handler ("/asset", (server, message, path, query) => {
            requests++;
            assert (!FileUtils.test (metadata_during_transfer, FileTest.EXISTS));
            if (scenario == "redirect") {
                assert (query != null && query.lookup ("token") == requests.to_string ());
                assert (redirects == requests);
            }
            string response;
            if (requests == 1) {
                assert (message.get_request_headers ().get_one ("Range") == null);
                response = "HTTP/1.1 200 OK\r\nContent-Length: 16\r\nETag: \"v1\"\r\n\r\ncompl";
            } else {
                if (scenario != "416" || requests == 2) {
                    assert (message.get_request_headers ().get_one ("Range") == "bytes=5-");
                    assert (message.get_request_headers ().get_one ("If-Range") == "\"v1\"");
                }
                if (scenario == "permanent" || (scenario == "permanent-after-retry" && requests > 2))
                    response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n";
                else if (scenario == "cancel" || scenario == "exhaustion" || scenario == "window" || scenario == "permanent-after-retry" || (scenario == "deadline" && requests == 2))
                    response = "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\n\r\n";
                else if (scenario == "416" && requests == 2)
                    response = "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Length: 0\r\n\r\n";
                else if (scenario == "ignored" || scenario == "changed" || scenario == "416")
                    response = "HTTP/1.1 200 OK\r\nContent-Length: 16\r\nETag: \"v2\"\r\n\r\n" + (scenario == "changed" ? "replaced archive" : "complete archive");
                else
                    response = "HTTP/1.1 206 Partial Content\r\nContent-Length: 11\r\nContent-Range: bytes %d-15/16\r\nETag: \"v1\"\r\n\r\n%s".printf (scenario == "range" ? 0 : 5, scenario == "deadline" ? "" : "ete archive");
            }
            var connection = message.steal_connection ();
            if (scenario == "deadline" && requests > 2)
                stalled = connection;
            send_test_response.begin (connection, response, scenario == "deadline" && requests > 2);
        });
        string root = "";
        try {
            root = DirUtils.make_tmp ("protonplus-persistent-XXXXXX");
            server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY);
            var cache = Path.build_filename (root, "cache");
            var url = server.get_uris ().data.to_string () + (scenario == "redirect" ? "source" : "asset");
            var destination = Path.build_filename (root, "archive");
            var policy = new ProtonPlus.Utils.Web.DownloadPolicy () { max_attempts = 1 };
            ProtonPlus.Utils.PartialDownloadCache.Lease? lease = ProtonPlus.Utils.PartialDownloadCache.acquire (cache, url);
            var partial_path = lease.path;
            metadata_during_transfer = Path.build_filename (Path.get_dirname (partial_path), "metadata");
            string? error;
            assert (!yield ProtonPlus.Utils.Web.download_with_recovery (url, destination, null, null, null, lease, policy, out error));
            assert (error != null);
            assert (FileUtils.test (partial_path, FileTest.IS_REGULAR));
            if (lease != null) lease.release ();
            lease = null;
            // New owner, no in-memory HTTP state from the first operation.
            lease = ProtonPlus.Utils.PartialDownloadCache.acquire (cache, url);
            assert (lease.offset == 5);
            assert (lease.total == 16);
            assert (lease.etag == "\"v1\"");
            var cancel = new Cancellable ();
            bool waited = false;
            bool reconnected = false;
            bool rebaseline = false;
            policy.max_attempts = 3;
            policy.recovery_seconds = scenario == "window" ? 2 : scenario == "deadline" ? 2 : 600;
            if (scenario == "exhaustion" || scenario == "window")
                Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*HTTP 503*");
            if (scenario == "range")
                Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Invalid resumed download response*");
            int64 started = get_monotonic_time ();
            var result = yield ProtonPlus.Utils.Web.download_with_recovery (url, destination, cancel,
                (percent, progress, speed, remaining) => {
                    if (progress < 100 && speed == 0 && remaining == null) {
                        rebaseline = true;
                        assert (progress == ((scenario == "changed" || scenario == "ignored") ? 0 : 31) || (scenario == "416" && progress == 0));
                    }
                },
                (phase, attempt, delay) => {
                    if (phase == ProtonPlus.Utils.Web.DownloadPhase.RECONNECTING)
                        reconnected = true;
                    if (phase == ProtonPlus.Utils.Web.DownloadPhase.WAITING && !waited) {
                        waited = true;
                        if (scenario == "cancel")
                            Timeout.add (200, () => { cancel.cancel (); return Source.REMOVE; });
                    }
                }, lease, policy, out error);
            bool success = scenario == "resume" || scenario == "ignored" || scenario == "changed" || scenario == "416" || scenario == "redirect";
            assert (result == success);
            assert (reconnected);
            if (success) {
                assert (rebaseline);
                string contents;
                FileUtils.get_contents (destination, out contents);
                assert (contents == (scenario == "changed" ? "replaced archive" : "complete archive"));
                assert (!FileUtils.test (partial_path, FileTest.EXISTS));
            } else if (scenario == "cancel" || scenario == "range" || scenario == "permanent" || scenario == "permanent-after-retry") {
                assert (!FileUtils.test (partial_path, FileTest.EXISTS));
                if (scenario == "cancel") {
                    assert (waited);
                    assert (error == null);
                    assert (get_monotonic_time () - started >= 200000);
                    assert (get_monotonic_time () - started < 1000000);
                }
            } else {
                assert (FileUtils.test (partial_path, FileTest.IS_REGULAR));
                assert (error != null);
                if (scenario == "window") {
                    assert (requests == 3);
                    assert (get_monotonic_time () - started < 2500000);
                }
                if (scenario == "exhaustion")
                    assert (requests == 4);
            }
            if (lease != null) lease.release ();
            lease = null;
        } catch (Error e) {
            Test.message (e.message);
            assert_not_reached ();
        }
        server.disconnect ();
        if (stalled != null) {
            try { yield stalled.close_async (Priority.DEFAULT); } catch (Error e) { }
        }
        assert (yield ProtonPlus.Utils.Filesystem.delete_directory (root));
    }

    private void run_cache_test (string scenario) {
        var loop = new MainLoop ();
        cache_test.begin (scenario, (obj, res) => { cache_test.end (res); loop.quit (); });
        loop.run ();
    }

    private async void cache_test (string scenario) {
        string root = "";
        try {
            root = DirUtils.make_tmp ("protonplus-partial-cache-XXXXXX");
            var cache = Path.build_filename (root, "cache");
            ProtonPlus.Utils.PartialDownloadCache.Lease? lease = ProtonPlus.Utils.PartialDownloadCache.acquire (cache, "asset");
            var body = lease.path;
            var metadata_path = Path.build_filename (Path.get_dirname (body), "metadata");
            FileUtils.set_contents (body, "compl");
            lease.save (5, 16, "\"v1\"");
            if (scenario == "count-limit" || scenario == "byte-limit") {
                if (lease != null) lease.release ();
                lease = null;
                int limit = scenario == "count-limit" ? 35 : 3;
                int64 size = scenario == "byte-limit" ? 1024L * 1024 * 1024 : 5;
                for (int i = 0; i < limit; i++) {
                    var entry = ProtonPlus.Utils.PartialDownloadCache.acquire (cache, "asset-%d".printf (i));
                    FileUtils.set_contents (entry.path, "");
                    assert (Posix.truncate (entry.path, (Posix.off_t) size) == 0);
                    entry.save (size, size + 1, "\"v1\"");
                }
                yield ProtonPlus.Utils.PartialDownloadCache.prune (cache);
                int count = 0;
                int64 bytes = 0;
                var directory = File.new_for_path (Path.build_filename (cache, "partials"));
                var enumerator = directory.enumerate_children ("standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                FileInfo? info;
                while ((info = enumerator.next_file ()) != null) {
                    var file = directory.get_child (info.get_name ()).get_child ("body");
                    if (file.query_exists ()) {
                        count++;
                        bytes += file.query_info ("standard::size", FileQueryInfoFlags.NOFOLLOW_SYMLINKS).get_size ();
                    }
                }
                assert (count <= ProtonPlus.Utils.PartialDownloadCache.MAX_ENTRIES);
                assert (bytes <= ProtonPlus.Utils.PartialDownloadCache.MAX_BYTES);
                assert (count > 0);
            } else if (scenario == "concurrent" || scenario == "clear") {
                bool busy = false;
                try {
                    var other = ProtonPlus.Utils.PartialDownloadCache.acquire (cache, "asset");
                    assert (other == null);
                } catch (IOError.BUSY e) { busy = true; }
                assert (busy);
                yield ProtonPlus.Utils.PartialDownloadCache.prune (cache);
                assert (FileUtils.test (body, FileTest.EXISTS));
                if (scenario == "clear") {
                    var state_path = Path.build_filename (root, "steam-restart-state.json");
                    FileUtils.set_contents (state_path, "pending receipt fixture");
                    var old_cache = ProtonPlus.Globals.CACHE_PATH;
                    ProtonPlus.Globals.CACHE_PATH = cache;
                    bool done = false;
                    ProtonPlus.Utils.CacheManager.clear_cache.begin ((obj, res) => {
                        assert (ProtonPlus.Utils.CacheManager.clear_cache.end (res));
                        done = true;
                    });
                    var timer = new TimeoutSource (100);
                    timer.set_callback (() => { cache_test.callback (); return Source.REMOVE; });
                    timer.attach (MainContext.default ());
                    yield;
                    assert (!done);
                    assert (FileUtils.test (body, FileTest.EXISTS));
                    if (lease != null) lease.release ();
                    lease = null;
                    while (!done) {
                        var wait = new TimeoutSource (20);
                        wait.set_callback (() => { cache_test.callback (); return Source.REMOVE; });
                        wait.attach (MainContext.default ());
                        yield;
                    }
                    assert (!FileUtils.test (body, FileTest.EXISTS));
                    assert (FileUtils.test (state_path, FileTest.IS_REGULAR));
                    ProtonPlus.Globals.CACHE_PATH = old_cache;
                }
            } else {
                if (lease != null) lease.release ();
                lease = null;
                var metadata = new KeyFile ();
                metadata.load_from_file (metadata_path, KeyFileFlags.NONE);
                switch (scenario) {
                case "stale": case "expiry":
                    metadata.set_int64 ("download", "updated", 0); break;
                case "size": metadata.set_int64 ("download", "bytes", 4); break;
                case "identity": metadata.set_string ("download", "identity", "other"); break;
                case "weak": metadata.set_string ("download", "etag", "W/\"v1\""); break;
                case "encoding": metadata.set_string ("download", "encoding", "gzip"); break;
                case "version": metadata.set_integer ("download", "version", 2); break;
                }
                FileUtils.set_contents (metadata_path, metadata.to_data ());
                if (scenario == "malformed") FileUtils.set_contents (metadata_path, "broken");
                if (scenario == "missing-metadata") FileUtils.remove (metadata_path);
                if (scenario == "missing-body" || scenario == "symlink") FileUtils.remove (body);
                if (scenario == "symlink") {
                    var target = Path.build_filename (root, "target");
                    FileUtils.set_contents (target, "compl");
                    assert (Posix.symlink (target, body) == 0);
                }
                if (scenario == "expiry") {
                    yield ProtonPlus.Utils.PartialDownloadCache.prune (cache);
                    assert (!FileUtils.test (body, FileTest.EXISTS));
                }
                lease = ProtonPlus.Utils.PartialDownloadCache.acquire (cache, "asset");
                assert (lease.offset == (scenario == "valid" ? 5 : 0));
                if (scenario != "valid")
                    assert (!FileUtils.test (body, FileTest.EXISTS));
                if (scenario == "symlink")
                    assert (FileUtils.test (Path.build_filename (root, "target"), FileTest.IS_REGULAR));
            }
            if (lease != null) lease.release ();
            lease = null;
        } catch (Error e) {
            Test.message (e.message);
            assert_not_reached ();
        }
        assert (yield ProtonPlus.Utils.Filesystem.delete_directory (root));
    }

    private void test_download_recovers_after_timeout () {
        var loop = new MainLoop ();
        test_download_recovers_after_timeout_async.begin ((obj, res) => {
            test_download_recovers_after_timeout_async.end (res);
            loop.quit ();
        });
        loop.run ();
        Test.assert_expected_messages ();
    }

    private async void test_download_recovers_after_timeout_async () {
        var server = new Soup.Server ("server-header", "ProtonPlus Test", null);
        var request_count = 0;
        server.add_handler ("/archive", (server, message, path, query) => {
            request_count++;
            if (request_count == 1) {
                message.pause ();
                return;
            }

            uint8[] body = "complete archive".data;
            message.set_status (Soup.Status.OK, null);
            message.set_response ("application/octet-stream", Soup.MemoryUse.COPY, body);
        });

        try {
            server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY);
        } catch (Error e) {
            Test.message ("Could not start loopback server: %s", e.message);
            assert_not_reached ();
        }

        var uri = server.get_uris ().data;
        assert (uri != null);
        var root = "";
        try {
            root = DirUtils.make_tmp ("protonplus-web-test-XXXXXX");
        } catch (Error e) {
            assert_not_reached ();
        }
        var destination = Path.build_filename (root, "archive");
        var session = ProtonPlus.Utils.Web.get_download_session ();
        var previous_timeout = session.timeout;
        session.timeout = 1;

        string? error_message;
        var downloaded = yield ProtonPlus.Utils.Web.download (
            "%sarchive".printf (((!) uri).to_string ()), destination, null, null, out error_message
        );

        session.timeout = previous_timeout;
        server.disconnect ();

        string contents = "";
        assert (downloaded);
        assert (error_message == null);
        assert (request_count == 2);
        try {
            assert (FileUtils.get_contents (destination, out contents));
        } catch (Error e) {
            assert_not_reached ();
        }
        assert (contents == "complete archive");
        assert (FileUtils.remove (destination) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private void test_download_exhausts_timeout_retries () {
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Socket I/O timed out*");
        var loop = new MainLoop ();
        test_download_exhausts_timeout_retries_async.begin ((obj, res) => {
            test_download_exhausts_timeout_retries_async.end (res);
            loop.quit ();
        });
        loop.run ();
        Test.assert_expected_messages ();
    }

    private void test_download_cancels_during_throttle () {
        var loop = new MainLoop ();
        test_download_cancels_during_throttle_async.begin ((obj, res) => {
            test_download_cancels_during_throttle_async.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private void test_download_respects_whole_download_speed_limit () {
        var loop = new MainLoop ();
        test_download_respects_whole_download_speed_limit_async.begin ((obj, res) => {
            test_download_respects_whole_download_speed_limit_async.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private void test_download_shares_global_speed_limit () {
        var loop = new MainLoop ();
        test_download_shares_global_speed_limit_async.begin ((obj, res) => {
            test_download_shares_global_speed_limit_async.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private void test_download_throttle_credits_transfer_time () {
        var loop = new MainLoop ();
        test_download_throttle_credits_transfer_time_async.begin ((obj, res) => {
            test_download_throttle_credits_transfer_time_async.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private void test_download_throttle_reacts_to_limit_change () {
        var loop = new MainLoop ();
        test_download_throttle_reacts_to_limit_change_async.begin ((obj, res) => {
            test_download_throttle_reacts_to_limit_change_async.end (res);
            loop.quit ();
        });
        loop.run ();
    }

    private async void test_download_exhausts_timeout_retries_async () {
        var server = new Soup.Server ("server-header", "ProtonPlus Test", null);
        var request_count = 0;
        server.add_handler ("/archive", (server, message, path, query) => {
            request_count++;
            message.pause ();
        });

        try {
            server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY);
        } catch (Error e) {
            Test.message ("Could not start loopback server: %s", e.message);
            assert_not_reached ();
        }

        var uri = server.get_uris ().data;
        assert (uri != null);
        var root = "";
        try {
            root = DirUtils.make_tmp ("protonplus-web-test-XXXXXX");
        } catch (Error e) {
            assert_not_reached ();
        }
        var destination = Path.build_filename (root, "archive");
        var session = ProtonPlus.Utils.Web.get_download_session ();
        var previous_timeout = session.timeout;
        session.timeout = 1;

        string? error_message;
        var downloaded = yield ProtonPlus.Utils.Web.download_with_recovery (
            "%sarchive".printf (((!) uri).to_string ()), destination, null, null, null, null,
            new ProtonPlus.Utils.Web.DownloadPolicy () { max_attempts = 4 }, out error_message
        );

        session.timeout = previous_timeout;
        server.disconnect ();

        assert (!downloaded);
        assert (request_count == 4);
        assert (error_message == "The download timed out. Check your connection and try again.");
        assert (!FileUtils.test (destination, FileTest.EXISTS));
        assert (DirUtils.remove (root) == 0);
    }

    private async void test_download_cancels_during_throttle_async () {
        var server = new Soup.Server ("server-header", "ProtonPlus Test", null);
        server.add_handler ("/archive", (server, message, path, query) => {
            uint8[] body = "chunk".data;
            message.set_status (Soup.Status.OK, null);
            message.set_response ("application/octet-stream", Soup.MemoryUse.COPY, body);
        });

        try {
            server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY);
        } catch (Error e) {
            Test.message ("Could not start loopback server: %s", e.message);
            assert_not_reached ();
        }

        var uri = server.get_uris ().data;
        assert (uri != null);
        var root = "";
        try {
            root = DirUtils.make_tmp ("protonplus-web-test-XXXXXX");
        } catch (Error e) {
            assert_not_reached ();
        }

        var destination = Path.build_filename (root, "archive");
        var cancel_source = new TimeoutSource (20);
        var cancellable = new Cancellable ();
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        var previous_limit = manager.speed_limit_bps;
        manager.speed_limit_bps = 1;

        cancel_source.set_callback (() => {
            cancellable.cancel ();
            return Source.REMOVE;
        });
        cancel_source.attach (MainContext.default ());

        var start_time = get_monotonic_time ();
        string? error_message = null;
        var downloaded = yield ProtonPlus.Utils.Web.download (
            "%sarchive".printf (((!) uri).to_string ()), destination, cancellable, null, out error_message
        );
        var elapsed_ms = (get_monotonic_time () - start_time) / 1000;

        manager.speed_limit_bps = previous_limit;
        server.disconnect ();

        assert (!downloaded);
        assert (elapsed_ms < 500);
        assert (error_message == null);
        assert (!FileUtils.test (destination, FileTest.EXISTS));
        assert (DirUtils.remove (root) == 0);
    }

    private async void test_download_respects_whole_download_speed_limit_async () {
        var server = new Soup.Server ("server-header", "ProtonPlus Test", null);
        server.add_handler ("/archive", (server, message, path, query) => {
            uint8[] body = new uint8[8192];
            for (var i = 0; i < body.length; i++) {
                body[i] = (uint8) (i % 251);
            }
            message.set_status (Soup.Status.OK, null);
            message.set_response ("application/octet-stream", Soup.MemoryUse.COPY, body);
        });

        try {
            server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY);
        } catch (Error e) {
            Test.message ("Could not start loopback server: %s", e.message);
            assert_not_reached ();
        }

        var uri = server.get_uris ().data;
        assert (uri != null);
        var root = "";
        try {
            root = DirUtils.make_tmp ("protonplus-web-test-XXXXXX");
        } catch (Error e) {
            assert_not_reached ();
        }

        var destination = Path.build_filename (root, "archive");
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        var previous_limit = manager.speed_limit_bps;
        manager.speed_limit_bps = 32768;

        var start_time = get_monotonic_time ();
        string? error_message = null;
        var downloaded = yield ProtonPlus.Utils.Web.download (
            "%sarchive".printf (((!) uri).to_string ()), destination, null, null, out error_message
        );
        var elapsed_ms = (get_monotonic_time () - start_time) / 1000;

        manager.speed_limit_bps = previous_limit;
        server.disconnect ();

        assert (downloaded);
        assert (error_message == null);
        assert (elapsed_ms >= 150);
        if (FileUtils.test (destination, FileTest.EXISTS))
            assert (FileUtils.remove (destination) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private async void test_download_shares_global_speed_limit_async () {
        var server = new Soup.Server ("server-header", "ProtonPlus Test", null);
        server.add_handler ("/archive", (server, message, path, query) => {
            uint8[] body = new uint8[8192];
            for (var i = 0; i < body.length; i++) {
                body[i] = (uint8) (255 - (i % 251));
            }
            message.set_status (Soup.Status.OK, null);
            message.set_response ("application/octet-stream", Soup.MemoryUse.COPY, body);
        });

        try {
            server.listen_local (0, Soup.ServerListenOptions.IPV4_ONLY);
        } catch (Error e) {
            Test.message ("Could not start loopback server: %s", e.message);
            assert_not_reached ();
        }

        var uri = server.get_uris ().data;
        assert (uri != null);
        var root = "";
        try {
            root = DirUtils.make_tmp ("protonplus-web-test-XXXXXX");
        } catch (Error e) {
            assert_not_reached ();
        }

        var destination1 = Path.build_filename (root, "archive-1");
        var destination2 = Path.build_filename (root, "archive-2");
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        var previous_limit = manager.speed_limit_bps;
        manager.speed_limit_bps = 32768;

        bool done1 = false;
        bool done2 = false;
        bool downloaded1 = false;
        bool downloaded2 = false;
        string? error_message1 = null;
        string? error_message2 = null;
        var wait_loop = new MainLoop ();

        var start_time = get_monotonic_time ();

        ProtonPlus.Utils.Web.download.begin (
            "%sarchive".printf (((!) uri).to_string ()), destination1, null, null,
            (obj, res) => {
                downloaded1 = ProtonPlus.Utils.Web.download.end (res, out error_message1);
                done1 = true;
                if (done2)
                    wait_loop.quit ();
            }
        );

        ProtonPlus.Utils.Web.download.begin (
            "%sarchive".printf (((!) uri).to_string ()), destination2, null, null,
            (obj, res) => {
                downloaded2 = ProtonPlus.Utils.Web.download.end (res, out error_message2);
                done2 = true;
                if (done1)
                    wait_loop.quit ();
            }
        );

        wait_loop.run ();
        var elapsed_ms = (get_monotonic_time () - start_time) / 1000;

        manager.speed_limit_bps = previous_limit;
        server.disconnect ();

        assert (downloaded1);
        assert (downloaded2);
        assert (error_message1 == null);
        assert (error_message2 == null);
        assert (elapsed_ms >= 450);

        if (FileUtils.test (destination1, FileTest.EXISTS))
            assert (FileUtils.remove (destination1) == 0);
        if (FileUtils.test (destination2, FileTest.EXISTS))
            assert (FileUtils.remove (destination2) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private async void test_download_throttle_credits_transfer_time_async () {
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        var previous_limit = manager.speed_limit_bps;
        manager.speed_limit_bps = 1000;

        var generation = manager.throttle_generation;
        var transfer_started_us = get_monotonic_time () - 200000;
        var wait_started_us = get_monotonic_time ();

        yield manager.throttle_global_download_bytes (
            100,
            transfer_started_us,
            generation,
            null
        );

        var elapsed_ms = (get_monotonic_time () - wait_started_us) / 1000;
        assert (elapsed_ms < 75);

        // Leave the shared deadline idle, then verify a later transfer starts a
        // fresh budget instead of inheriting a stale deadline.
        Thread.usleep (100000);
        transfer_started_us = get_monotonic_time ();
        Thread.usleep (20000);
        wait_started_us = get_monotonic_time ();

        yield manager.throttle_global_download_bytes (
            100,
            transfer_started_us,
            generation,
            null
        );

        elapsed_ms = (get_monotonic_time () - wait_started_us) / 1000;
        manager.speed_limit_bps = previous_limit;

        assert (elapsed_ms >= 50);
        assert (elapsed_ms < 150);
    }

    private async void test_download_throttle_reacts_to_limit_change_async () {
        var manager = ProtonPlus.Utils.DownloadManager.instance;
        var previous_limit = manager.speed_limit_bps;
        manager.speed_limit_bps = 1;

        var generation = manager.throttle_generation;
        var change_source = new TimeoutSource (20);
        change_source.set_callback (() => {
            manager.speed_limit_bps = 0;
            return Source.REMOVE;
        });
        change_source.attach (MainContext.default ());

        var wait_started_us = get_monotonic_time ();
        yield manager.throttle_global_download_bytes (
            5,
            wait_started_us,
            generation,
            null
        );
        var elapsed_ms = (get_monotonic_time () - wait_started_us) / 1000;

        change_source.destroy ();
        manager.speed_limit_bps = previous_limit;

        assert (elapsed_ms < 500);
    }
}
