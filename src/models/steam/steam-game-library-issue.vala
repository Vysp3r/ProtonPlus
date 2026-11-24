namespace ProtonPlus.Models {
    public enum SteamGameLibraryProblem {
        UNKNOWN,
        MISSING,
        UNREADABLE,
        INVALID,
        NO_LOCAL_PROFILES
    }

    public class SteamGameLibraryIssue : Object {
        public SteamGameLibraryProblem problem { get; private set; }
        public string file_name { get; private set; }

        internal SteamGameLibraryIssue (SteamGameLibraryProblem problem, string file_name = "") {
            this.problem = problem;
            this.file_name = file_name;
        }

        public string describe () {
            switch (problem) {
            case SteamGameLibraryProblem.MISSING:
                return _("%s is missing. Open this Steam installation and finish setting it up, then try again.")
                    .printf (file_name);
            case SteamGameLibraryProblem.UNREADABLE:
                return _("ProtonPlus couldn’t read %s. Check that ProtonPlus has access to this Steam installation, then try again.")
                    .printf (file_name);
            case SteamGameLibraryProblem.INVALID:
                return _("%s is incomplete or invalid. Open and close this Steam installation to refresh its data, then try again.")
                    .printf (file_name);
            case SteamGameLibraryProblem.NO_LOCAL_PROFILES:
                return _("No Steam accounts with local profile data were found. Sign in to this Steam installation, then try again.");
            default:
                return _("Steam’s game library couldn’t be read. Open this Steam installation and finish setting it up, then try again.");
            }
        }

        internal static SteamGameLibraryProblem read_problem (Error error) {
            return (error is IOError.NOT_FOUND)
                ? SteamGameLibraryProblem.MISSING : SteamGameLibraryProblem.UNREADABLE;
        }

        internal static async Utils.VDF.VdfEntry? read_section (string path,
            string file_name, string section_name, out SteamGameLibraryIssue? issue) {
            issue = null;
            try {
                var file = File.new_for_path (path);
                var info = yield file.query_info_async (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                if (info.get_file_type () != FileType.REGULAR) {
                    issue = new SteamGameLibraryIssue (SteamGameLibraryProblem.UNREADABLE, file_name);
                    return null;
                }
                uint8[] contents;
                yield file.load_contents_async (null, out contents, null);
                var document = Utils.VDF.VdfParser.parse_document (Utils.bytes_to_string (contents));
                var section = document != null ? document.root.get_child (section_name) : null;
                if (section != null && section.value == null)
                    return section;
                issue = new SteamGameLibraryIssue (SteamGameLibraryProblem.INVALID, file_name);
            } catch (Error error) {
                issue = new SteamGameLibraryIssue (read_problem (error), file_name);
            }
            return null;
        }
    }
}
