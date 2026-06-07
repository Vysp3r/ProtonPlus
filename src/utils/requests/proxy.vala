namespace ProtonPlus.Utils.Requests {
    public class Proxy : Object {
        const int MODE_SYSTEM = 0;
        const int MODE_MANUAL = 1;

        static Soup.Session? _session = null;
        static int applied_proxy_mode = -1;
        static string? applied_proxy_url = null;

        public static Soup.Session session {
            get {
                if (_session == null) {
                    _session = new Soup.Session ();
                    _session.user_agent = Config.APP_NAME + "/" + Config.APP_VERSION;
                }
                update_proxy_settings ();
                return _session;
            }
        }

        public static Soup.Session? get_session_instance () {
            return _session;
        }

        public static void update_proxy_settings () {
            if (_session == null)
                return;

            var proxy_mode = MODE_SYSTEM;
            var proxy_url = "";

            if (Globals.SETTINGS != null) {
                proxy_mode = Globals.SETTINGS.get_enum ("proxy-mode");
                proxy_url = Globals.SETTINGS.get_string ("proxy-url").strip ();
            }

            if (applied_proxy_mode == proxy_mode && applied_proxy_url == proxy_url)
                return;

            if (proxy_mode == MODE_MANUAL) {
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
    }
}