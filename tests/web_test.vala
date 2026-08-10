namespace AppTests.WebTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/web/download-retries-timeout-once", test_download_retries_timeout_once);
        Test.add_func ("/web/download-stops-after-timeout-retry", test_download_stops_after_timeout_retry);
        Test.add_func ("/web/download-cancels-during-throttle", test_download_cancels_during_throttle);
        Test.add_func ("/web/download-respects-whole-download-speed-limit", test_download_respects_whole_download_speed_limit);
        Test.add_func ("/web/download-shares-global-speed-limit", test_download_shares_global_speed_limit);
        Test.add_func ("/web/download-throttle-credits-transfer-time", test_download_throttle_credits_transfer_time);
        Test.add_func ("/web/download-throttle-reacts-to-limit-change", test_download_throttle_reacts_to_limit_change);
    }

    private void test_download_retries_timeout_once () {
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Download timed out; retrying once*");
        var loop = new MainLoop ();
        test_download_retries_timeout_once_async.begin ((obj, res) => {
            test_download_retries_timeout_once_async.end (res);
            loop.quit ();
        });
        loop.run ();
        Test.assert_expected_messages ();
    }

    private async void test_download_retries_timeout_once_async () {
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
        var session = ProtonPlus.Utils.Web.get_session ();
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

    private void test_download_stops_after_timeout_retry () {
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Download timed out; retrying once*");
        Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Socket I/O timed out*");
        var loop = new MainLoop ();
        test_download_stops_after_timeout_retry_async.begin ((obj, res) => {
            test_download_stops_after_timeout_retry_async.end (res);
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

    private async void test_download_stops_after_timeout_retry_async () {
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
        var session = ProtonPlus.Utils.Web.get_session ();
        var previous_timeout = session.timeout;
        session.timeout = 1;

        string? error_message;
        var downloaded = yield ProtonPlus.Utils.Web.download (
            "%sarchive".printf (((!) uri).to_string ()), destination, null, null, out error_message
        );

        session.timeout = previous_timeout;
        server.disconnect ();

        assert (!downloaded);
        assert (request_count == 2);
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
