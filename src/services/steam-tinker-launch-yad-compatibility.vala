namespace ProtonPlus.Services {
    public class SteamTinkerLaunchYadCompatibility : Object {
        public enum Status {
            UNKNOWN,
            TOO_OLD,
            SUPPORTED,
            INCOMPATIBLE_15
        }

        public static Status classify_version_output (string output) {
            try {
                var regex = new Regex ("""(\d+)[.,](\d+)\s*\(GTK\+""");
                MatchInfo match_info;
                if (!regex.match (output, 0, out match_info))
                    return Status.UNKNOWN;

                var major = int.parse (match_info.fetch (1));
                var minor = int.parse (match_info.fetch (2));

                if (major == 15)
                    return Status.INCOMPATIBLE_15;
                if (major > 7 || (major == 7 && minor >= 2))
                    return Status.SUPPORTED;
                return Status.TOO_OLD;
            } catch (Error e) {
                warning ("Could not determine the installed YAD version: %s", e.message);
                return Status.UNKNOWN;
            }
        }
    }
}
