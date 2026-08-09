namespace AppTests.WebTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/web/download-retries-timeout-once", test_download_retries_timeout_once);
        Test.add_func ("/web/download-stops-after-timeout-retry", test_download_stops_after_timeout_retry);
        Test.add_func ("/web/download-cancels-during-throttle", test_download_cancels_during_throttle);
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
}
