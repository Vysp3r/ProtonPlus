namespace ProtonPlus.Utils {
    // Request routing only: catalog assets and their persisted identities stay canonical.
    public class GitHubDownloadMirror {
        public const string SETTINGS_KEY = "github-download-mirror";

        public static string normalize (string prefix) throws Error {
            var value = prefix.strip ();
            if (value == "")
                return "";
            var uri = Uri.parse (value, UriFlags.NONE);
            if (uri.get_scheme () != "https" || uri.get_host () == null || uri.get_host () == "" ||
                uri.get_userinfo () != null || uri.get_query () != null || uri.get_fragment () != null ||
                value.contains ("\\") || value.contains (" ") || value.contains ("\n") || value.contains ("\r") || value.contains ("\t"))
                throw new IOError.INVALID_ARGUMENT (_("Enter an HTTPS mirror URL without credentials, a query, or a fragment."));
            return value.has_suffix ("/") ? value : value + "/";
        }

        public static string resolve (string url, string prefix) throws Error {
            var uri = Uri.parse (url, UriFlags.NONE);
            if (uri.get_scheme () != "https" || uri.get_host () != "github.com" ||
                uri.get_userinfo () != null || (uri.get_port () != -1 && uri.get_port () != 443))
                return url;
            var parts = uri.get_path ().split ("/");
            if (parts.length < 7 || parts[1] == "" || parts[2] == "" ||
                parts[3] != "releases" || parts[4] != "download" || parts[5] == "" || parts[6] == "")
                return url;
            return normalize (prefix) + url;
        }
    }
}
