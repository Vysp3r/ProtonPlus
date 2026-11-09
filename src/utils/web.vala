namespace ProtonPlus.Utils {
    public class Web {
        const int PROXY_MODE_SYSTEM = 0;
        const int PROXY_MODE_MANUAL = 1;
        public enum DownloadPhase { DOWNLOADING, WAITING, RECONNECTING }
        public delegate void recovery_callback (DownloadPhase phase, int attempt, int delay_seconds);

        public class DownloadPolicy : Object {
            public int max_attempts { get; set; default = 32; }
            public int recovery_seconds { get; set; default = 600; }
            public int backoff_cap_seconds { get; set; default = 30; }
        }

        private static Soup.Session? download_session;
        public static Soup.Session get_download_session () {
            var api = current_session;
            if (download_session == null) {
                download_session = new Soup.Session ();
                download_session.timeout = 30;
                download_session.user_agent = api.user_agent;
            }
            download_session.set_proxy_resolver (api.proxy_resolver);
            return download_session;
        }

        public static bool is_strong_etag (string? value) {
            if (value == null || value.length < 2 || !value.has_prefix ("\"") || !value.has_suffix ("\""))
                return false;
            for (int i = 1; i < value.length - 1; i++) {
                if (value[i] == '"' || value[i] < 0x21 || value[i] == 0x7f)
                    return false;
            }
            return true;
        }


        public enum GetRequestType {
            OTHER,
            GITHUB,
            GITLAB,
            FORGEJO,
            STEAMTINKERLAUNCH,
        }

        public class Response : Object {
            public ReturnCode code { get; set; default = ReturnCode.REQUEST_FAILED; }
            public int status_code { get; set; default = 0; }
            public string? body { get; set; default = null; }
            public string? error_message { get; set; default = null; }

            public bool is_successful {
                get {
                    return status_code >= 200 && status_code < 300;
                }
            }
        }

        static Soup.Session? _session = null;
        static int applied_proxy_mode = -1;
        static string? applied_proxy_url = null;

        static Soup.Session current_session {
            get {
                if (_session == null) {
                    _session = new Soup.Session ();
                    _session.user_agent = Config.APP_NAME + "/" + Config.APP_VERSION;
                }
                update_proxy_settings ();
                return _session;
            }
        }

        public static Soup.Session get_session () {
            return current_session;
        }

        public static void update_proxy_settings () {
            if (_session == null)
                return;

            var proxy_mode = PROXY_MODE_SYSTEM;
            var proxy_url = "";

            if (Globals.SETTINGS != null) {
                proxy_mode = Globals.SETTINGS.get_enum ("proxy-mode");
                proxy_url = Globals.SETTINGS.get_string ("proxy-url").strip ();
            }

            if (applied_proxy_mode == proxy_mode && applied_proxy_url == proxy_url)
                return;

            if (proxy_mode == PROXY_MODE_MANUAL) {
                if (is_valid_proxy_url (proxy_url)) {
                    _session.set_proxy_resolver (new SimpleProxyResolver (proxy_url, null));
                } else {
                    if (proxy_url.length > 0)
                        warning ("Invalid proxy URL. Falling back to the system proxy.");
                    _session.set_proxy_resolver (ProxyResolver.get_default ());
                }
            } else {
                _session.set_proxy_resolver (ProxyResolver.get_default ());
            }

            applied_proxy_mode = proxy_mode;
            applied_proxy_url = proxy_url;
        }

        static bool is_valid_proxy_url (string proxy_url) {
            var supported_schemes = new string[] { "http://", "https://", "socks://", "socks4://", "socks5://" };

            if (proxy_url.length == 0)
                return false;

            foreach (var scheme in supported_schemes) {
                if (proxy_url.has_prefix (scheme) && proxy_url.length > scheme.length)
                    return true;
            }

            return false;
        }

        public static async Response get_request (
            string uri,
            GetRequestType get_request_type = GetRequestType.OTHER,
            Cancellable? cancellable = null
        ) {
            var message = new Soup.Message ("GET", uri);

            if (Globals.SETTINGS != null) {
                if (get_request_type == GetRequestType.GITHUB || get_request_type == GetRequestType.STEAMTINKERLAUNCH) {
                    var key = Globals.SETTINGS.get_string ("github-api-key");
                    if (key.length > 0)
                        message.request_headers.append ("Authorization", "token %s".printf (key));
                }

                if (get_request_type == GetRequestType.GITLAB) {
                    var key = Globals.SETTINGS.get_string ("gitlab-api-key");
                    if (key.length > 0)
                        message.request_headers.append ("Authorization", "Bearer %s".printf (key));
                }

                if (get_request_type == GetRequestType.STEAMTINKERLAUNCH) {
                    message.request_headers.append ("Accept", "application/vnd.github+json");
                    message.request_headers.append ("X-GitHub-Api-Version", "2022-11-28");
                }
            }

            Response? response = yield send_request (message, cancellable);
            if (response == null)
                return new Response ();

            if (((!) response).is_successful)
                return (!) response;

            if (((!) response).status_code == 403 || ((!) response).status_code == 429) {
                ((!) response).code = ReturnCode.API_LIMIT_REACHED;
            } else if (((!) response).status_code == 401 &&
                       (get_request_type == GetRequestType.GITHUB ||
                        get_request_type == GetRequestType.GITLAB ||
                        get_request_type == GetRequestType.FORGEJO ||
                        get_request_type == GetRequestType.STEAMTINKERLAUNCH)) {
                ((!) response).code = ReturnCode.INVALID_ACCESS_TOKEN;
            }

            return (!) response;
        }

        private static async Response send_request (Soup.Message message, Cancellable? cancellable) {
            var response = new Response ();

            try {
                Bytes bytes = yield current_session.send_and_read_async (message, Priority.DEFAULT, cancellable);

                response.status_code = (int) message.status_code;
                response.error_message = message.reason_phrase;

                if (!response.is_successful)
                    return response;

                response.body = Parser.data_to_string (bytes.get_data ());
                response.code = ReturnCode.VALID_REQUEST;
                return response;
            } catch (Error e) {
                if (e is Soup.SessionError.PARSING || e.domain == TlsError.quark ()) {
                    response.code = ReturnCode.TLS_HANDSHAKE_ERROR;
                } else if (e is IOError.HOST_UNREACHABLE || e is IOError.NETWORK_UNREACHABLE) {
                    response.code = ReturnCode.CONNECTION_ISSUE;
                } else if (e is IOError.CONNECTION_REFUSED) {
                    response.code = ReturnCode.CONNECTION_REFUSED;
                } else if (e is IOError.HOST_NOT_FOUND) {
                    response.code = ReturnCode.CONNECTION_UNKNOWN;
                } else if (!(e is IOError.CANCELLED)) {
                    warning (e.message);
                }

                response.error_message = e.message;
                return response;
            }
        }

        public delegate void progress_callback (bool is_percent, int64 progress_percentage, double speed_kbps, double? remaining_seconds);

        private static void report_download_progress (progress_callback callback, DownloadState state) {
            var now = get_monotonic_time ();
            var elapsed = (now - state.started) / 1000000.0;
            if (elapsed >= 0.1 && state.transferred > 0) {
                var sample = state.transferred / elapsed;
                var weight = 1.0 - Math.exp (-elapsed / 3.0);
                state.rate = state.rate == 0 ? sample : state.rate + weight * (sample - state.rate);
                state.transferred = 0;
                state.started = now;
            }
            bool percent = state.total > 0;
            double? remaining = percent && state.rate > 0 ? (double?) ((state.total - state.offset) / state.rate) : null;
            callback (percent, percent ? (int64) (100.0 * state.offset / state.total) : state.offset,
                      state.rate / 1024.0, remaining);
        }

        private static async void cleanup_partial_download (File file) {
            try {
                if (file.query_exists ())
                    yield file.delete_async (Priority.DEFAULT, null);
            } catch (Error e) {
                warning ("Could not remove partial download: %s".printf (e.message));
            }
        }

        // This state belongs to one active download, never to the completed archive cache.
        private class DownloadState : Object {
            public double rate = 0;
            public int64 offset = 0;
            public int64 total = -1;
            public int64 transferred = 0;
            public int64 started = get_monotonic_time ();
            public string? etag = null;
            public bool owns_file = false;
            public bool retryable = false;
            public int retry_after = 0;
        }

        private static bool is_transient_network_error (Error error) {
            return error is IOError.TIMED_OUT || error is IOError.CONNECTION_CLOSED ||
                error is IOError.PARTIAL_INPUT || error is IOError.HOST_UNREACHABLE ||
                error is IOError.NETWORK_UNREACHABLE || error is IOError.CONNECTION_REFUSED ||
                error is IOError.HOST_NOT_FOUND || error is ResolverError.TEMPORARY_FAILURE;
        }

        private static int retry_after_seconds (Soup.MessageHeaders headers) {
            var value = headers.get_one ("Retry-After");
            if (value == null)
                return 0;
            value = value.strip ();
            bool numeric = value.length > 0;
            foreach (var character in value.data)
                numeric = numeric && character >= '0' && character <= '9';
            uint64 seconds;
            if (numeric)
                return !uint64.try_parse (value, out seconds) || seconds > int.MAX ? int.MAX : (int) seconds;
            var date = Soup.date_time_new_from_http_string (value);
            if (date == null)
                return 0;
            var remaining = date.to_unix () - new DateTime.now_utc ().to_unix ();
            // Fail normally rather than retrying earlier than the server permits.
            return (int) int64.min (int.MAX, int64.max (0, remaining));
        }

        private static async void wait_for_download_retry (int delay_seconds, Cancellable? cancellable, recovery_callback? recovery, int attempt) throws Error {
            var deadline = get_monotonic_time () + 1000000L * delay_seconds;
            int previous_remaining = delay_seconds;
            var source = new TimeoutSource (100);
            source.set_callback (() => {
                int remaining = (int) int64.max (0, (deadline - get_monotonic_time () + 999999) / 1000000);
                if (remaining != previous_remaining && remaining > 0 && recovery != null) {
                    previous_remaining = remaining;
                    recovery (DownloadPhase.WAITING, attempt, remaining);
                }
                if ((cancellable == null || !cancellable.is_cancelled ()) && get_monotonic_time () < deadline)
                    return Source.CONTINUE;
                wait_for_download_retry.callback ();
                return Source.REMOVE;
            });
            source.attach (MainContext.get_thread_default ());
            yield;
            source.destroy ();
            if (cancellable != null)
                cancellable.set_error_if_cancelled ();
        }

        private static string get_download_error_message (Error error) {
            if (error is IOError.TIMED_OUT)
                return _("The download timed out. Check your connection and try again.");
            return error.message;
        }

        private static async bool download_once (
            string url,
            File file,
            DownloadState state,
            Cancellable? cancellable,
            progress_callback? progress_callback,
            recovery_callback? recovery,
            int attempt,
            out string? error_message
        ) throws Error {
            error_message = null;
            FileOutputStream? output_stream = null;
            InputStream? input_stream = null;
            state.retryable = false;
            state.retry_after = 0;

            try {
                if (cancellable != null)
                    cancellable.set_error_if_cancelled ();
                var soup_message = new Soup.Message ("GET", url);
                // Byte offsets must refer to the actual on-disk representation.
                soup_message.request_headers.replace ("Accept-Encoding", "identity");
                soup_message.disable_feature (typeof (Soup.ContentDecoder));
                bool resuming = state.offset > 0 && state.etag != null;
                if (resuming) {
                    soup_message.request_headers.set_range (state.offset, -1);
                    soup_message.request_headers.replace ("If-Range", state.etag);
                }

                try {
                    input_stream = yield get_download_session ().send_async (soup_message, Priority.DEFAULT, cancellable);
                } catch (Error e) {
                    state.retryable = is_transient_network_error (e);
                    throw e;
                }

                var status = soup_message.status_code;
                var headers = soup_message.get_response_headers ();
                if (status == 408 || status == 429 || status == 500 || status == 502 || status == 503 || status == 504) {
                    state.retry_after = retry_after_seconds (headers);
                    state.retryable = true;
                    throw new IOError.FAILED (_("HTTP %u: %s"), status, soup_message.reason_phrase);
                }
                if (resuming && status == 416) {
                    // Never infer completion from a rejected range. Fetch and validate a fresh body.
                    state.etag = null;
                    state.retryable = true;
                    throw new IOError.FAILED (_("Server rejected the download range"));
                }
                if (status != 200 && !(resuming && status == 206)) {
                    error_message = soup_message.reason_phrase;
                    return false;
                }
                var encoding = headers.get_one ("Content-Encoding");
                if (encoding != null && encoding.ascii_casecmp ("identity") != 0)
                    throw new IOError.INVALID_DATA (_("Unexpected download content encoding"));

                int64 response_size = headers.get_one ("Content-Length") != null ? headers.get_content_length () : -1;
                var etag = headers.get_one ("ETag");
                if (status == 206) {
                    int64 start, end, total;
                    if (!headers.get_content_range (out start, out end, out total) ||
                        start != state.offset || end < start || total <= end ||
                        end != total - 1 || (state.total >= 0 && total != state.total) ||
                        (response_size >= 0 && response_size != end - start + 1) ||
                        (etag != state.etag))
                        throw new IOError.INVALID_DATA (_("Invalid resumed download response"));
                    state.total = total;
                    output_stream = yield file.append_to_async (FileCreateFlags.NONE, Priority.DEFAULT, cancellable);
                } else {
                    // A server may ignore Range, or If-Range may detect a changed asset.
                    if (state.owns_file)
                        output_stream = yield file.replace_async (null, false, FileCreateFlags.REPLACE_DESTINATION, Priority.DEFAULT, cancellable);
                    else
                        output_stream = yield file.create_async (FileCreateFlags.NONE, Priority.DEFAULT, cancellable);
                    state.owns_file = true;
                    state.offset = 0;
                    state.total = response_size;
                    state.etag = is_strong_etag (etag) ? etag : null;
                }

                state.rate = 0;
                state.transferred = 0;
                state.started = get_monotonic_time ();
                if (recovery != null)
                    recovery (DownloadPhase.DOWNLOADING, attempt, 0);

                const size_t max_chunk_size = 64 * 1024;
                const int64 progress_report_interval_us = 100 * 1000;

                if (progress_callback != null)
                    report_download_progress (progress_callback, state);

                var is_canceled = false;

                int64 last_progress_report_time = get_monotonic_time ();

                while (true) {
                    if (cancellable != null && cancellable.is_cancelled ()) {
                        is_canceled = true;
                        break;
                    }

                    var download_manager = DownloadManager.instance;
                    var speed_limit_bps_before_read = download_manager.speed_limit_bps;
                    var throttle_generation_before_read = download_manager.throttle_generation;
                    size_t chunk_size = max_chunk_size;
                    if (speed_limit_bps_before_read > 0) {
                        // Keep small limits responsive and avoid huge burst writes.
                        int64 suggested_chunk = speed_limit_bps_before_read / 8;
                        if (suggested_chunk < 1024)
                            suggested_chunk = 1024;
                        if (suggested_chunk < (int64) max_chunk_size)
                            chunk_size = (size_t) suggested_chunk;
                    }

                    int64 transfer_started_us = get_monotonic_time ();
                    Bytes chunk;
                    try {
                        chunk = yield input_stream.read_bytes_async (chunk_size, Priority.DEFAULT, cancellable);
                    } catch (Error e) {
                        state.retryable = is_transient_network_error (e);
                        throw e;
                    }

                    if (chunk.get_size () == 0)
                        break;

                    if (state.total >= 0 && chunk.get_size () > state.total - state.offset)
                        throw new IOError.INVALID_DATA (_("The download exceeded its expected size."));

                    size_t bytes_written;
                    yield output_stream.write_all_async (chunk.get_data (), Priority.DEFAULT, cancellable, out bytes_written);

                    state.offset += bytes_written;
                    state.transferred += bytes_written;

                    yield download_manager.throttle_global_download_bytes (
                        (int64) bytes_written,
                        transfer_started_us,
                        throttle_generation_before_read,
                        cancellable
                    );

                    if (cancellable != null && cancellable.is_cancelled ()) {
                        is_canceled = true;
                        break;
                    }

                    int64 now = get_monotonic_time ();
                    if (progress_callback != null && now - last_progress_report_time >= progress_report_interval_us) {
                        report_download_progress (progress_callback, state);
                        last_progress_report_time = now;
                    }
                }

                if (!is_canceled && state.total >= 0 && state.offset != state.total) {
                    state.retryable = state.offset < state.total;
                    throw new IOError.PARTIAL_INPUT (_("Incomplete download response"));
                }

                if (!is_canceled && progress_callback != null)
                    report_download_progress (progress_callback, state);

                yield output_stream.close_async ();
                output_stream = null;
                if (cancellable != null)
                    cancellable.set_error_if_cancelled ();

                return !is_canceled;
            } finally {
                // Close every attempt before retrying; filesystem failures are never retried.
                if (output_stream != null) {
                    try {
                        yield output_stream.close_async (Priority.DEFAULT, null);
                    } catch (Error e) {
                        state.retryable = false;
                        warning ("Could not close partial download: %s", e.message);
                    }
                }
                if (input_stream != null) {
                    try {
                        yield input_stream.close_async (Priority.DEFAULT, null);
                    } catch (Error e) {
                        debug ("Could not close download response: %s", e.message);
                    }
                }
            }
        }

        public static async bool download (
            string url, string path, Cancellable? cancellable = null,
            progress_callback? progress_callback = null, out string? error_message = null
        ) {
            return yield download_with_recovery (url, path, cancellable, progress_callback, null, null, null, out error_message);
        }

        public static async bool download_with_recovery (
            string url,
            string path,
            Cancellable? cancellable = null,
            progress_callback? progress_callback = null,
            recovery_callback? recovery,
            PartialDownloadCache.Lease? partial,
            DownloadPolicy? policy,
            out string? error_message
        ) {
            error_message = null;
            var limits = policy ?? new DownloadPolicy ();
            var file = File.new_for_path (partial != null ? partial.path : path);
            var state = new DownloadState ();
            if (partial != null && partial.offset > 0) {
                state.offset = partial.offset;
                state.total = partial.total;
                state.etag = partial.etag;
                state.owns_file = true;
            }
            bool succeeded = false;
            bool retain = false;
            var transfer_cancel = new Cancellable ();
            ulong cancel_handler = 0;
            if (cancellable != null) {
                cancel_handler = cancellable.cancelled.connect (() => { transfer_cancel.cancel (); });
                if (cancellable.is_cancelled ())
                    transfer_cancel.cancel ();
            }
            uint window_timer = 0;
            int64 deadline = 0;
            bool expired = false;
            try {
                if (partial != null)
                    partial.invalidate_checkpoint ();
                for (var attempt = 1; attempt <= limits.max_attempts; attempt++) {
                    if (recovery != null)
                        recovery (attempt == 1 && state.offset == 0 ? DownloadPhase.DOWNLOADING : DownloadPhase.RECONNECTING, attempt, 0);
                    retain = false;
                    try {
                        succeeded = yield download_once (url, file, state, transfer_cancel, progress_callback,
                                                        recovery, attempt, out error_message);
                        if (succeeded && partial != null) {
                            // The workflow still validates size/digest and extraction before publication.
                            yield file.move_async (File.new_for_path (path), FileCopyFlags.NONE, Priority.DEFAULT, transfer_cancel, null);
                            partial.discard ();
                        }
                        return succeeded;
                    } catch (Error e) {
                        succeeded = false;
                        if (cancellable != null && cancellable.is_cancelled ())
                            return false;
                        retain = state.retryable || expired;
                        if (expired) {
                            error_message = _("Download recovery time limit reached. Retry to continue.");
                            return false;
                        }
                        if (state.retryable && deadline == 0) {
                            deadline = get_monotonic_time () + limits.recovery_seconds * 1000000L;
                            window_timer = Timeout.add ((uint) int.max (1, limits.recovery_seconds) * 1000, () => {
                                expired = true;
                                transfer_cancel.cancel ();
                                window_timer = 0;
                                return Source.REMOVE;
                            });
                        }
                        int delay = int.max (int.min (1 << int.min (attempt - 1, 20), limits.backoff_cap_seconds), state.retry_after);
                        if (state.retryable && attempt < limits.max_attempts &&
                            get_monotonic_time () + delay * 1000000L < deadline) {
                            if (progress_callback != null)
                                progress_callback (state.total > 0, state.total > 0 ? (int64) (100.0 * state.offset / state.total) : state.offset, 0, null);
                            if (recovery != null)
                                recovery (DownloadPhase.WAITING, attempt + 1, delay);
                            yield wait_for_download_retry (delay, transfer_cancel, recovery, attempt + 1);
                            continue;
                        }
                        warning (e.message);
                        error_message = get_download_error_message (e);
                        return false;
                    }
                }
            } catch (Error e) {
                if (expired)
                    error_message = _("Download recovery time limit reached. Retry to continue.");
                else if (!(e is IOError.CANCELLED))
                    error_message = e.message;
            } finally {
                if (window_timer != 0)
                    Source.remove (window_timer);
                if (cancellable != null && cancel_handler != 0)
                    cancellable.disconnect (cancel_handler);
                if (!succeeded) {
                    if (partial != null) {
                        if (retain && (cancellable == null || !cancellable.is_cancelled ())) {
                            try {
                                partial.save (state.offset, state.total, state.etag);
                            } catch (Error e) {
                                partial.discard ();
                                error_message = e.message;
                            }
                        } else {
                            partial.discard ();
                        }
                    } else if (state.owns_file) {
                        yield cleanup_partial_download (file);
                    }
                }
            }
            return false;
        }
    }
}
