namespace ProtonPlus.Utils {
    public class ArchiveHelper : Object {
        private static string[] get_supported_extensions (bool allow_plain_tar = false) {
            if (allow_plain_tar) {
                return {
                    ".tar.gz",
                    ".tgz",
                    ".tar.xz",
                    ".tar.bz2",
                    ".tbz2",
                    ".tar.zst",
                    ".tzst",
                    ".zip",
                    ".7z",
                    ".rar",
                    ".tar"
                };
            }

            return {
                ".tar.gz",
                ".tgz",
                ".tar.xz",
                ".tar.bz2",
                ".tbz2",
                ".tar.zst",
                ".tzst",
                ".zip",
                ".7z",
                ".rar"
            };
        }

        public static string? get_archive_extension (string value, bool allow_plain_tar = false) {
            var lowered_value = value.ascii_down ();

            foreach (var extension in get_supported_extensions (allow_plain_tar)) {
                if (lowered_value.has_suffix (extension))
                    return extension;
            }

            return null;
        }

        public static bool is_archive_name (string value, bool allow_plain_tar = false) {
            return get_archive_extension (value, allow_plain_tar) != null;
        }

        public static string strip_archive_extension (string value, bool allow_plain_tar = false) {
            var extension = get_archive_extension (value, allow_plain_tar);
            if (extension == null)
                return value;

            return value.substring (0, value.length - extension.length);
        }
    }
}
