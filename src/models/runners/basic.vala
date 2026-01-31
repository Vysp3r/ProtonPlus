namespace ProtonPlus.Models.Runners {
    public abstract class Basic : Runner {
        internal int asset_position { get; set; }
        internal string asset_position_time_condition { get; set; }
        internal string endpoint { get; set; }
        internal int page { get; set; }
        internal string directory_name_format { get; set; }

        construct {
            page = 1;
        }

        public virtual string get_directory_name (string release_name) {
            if (release_name == "Proton-Sarek (Async) Latest")
                return release_name;

            var directory_name = new StringBuilder(directory_name_format);

            directory_name.replace ("$release_name", release_name);
            directory_name.replace ("$title", title);

            if (directory_name.len > 0 && directory_name.str[0] == '_') {
                directory_name.replace ("_", "", 1);
                directory_name.str = directory_name.str.ascii_down ();
            }

            if (directory_name.len > 0 && directory_name.str[0] == '!') {
                directory_name.replace ("!", "", 1);
                var split = directory_name.str.split (":");
                directory_name.str = split[0].replace (split[1], split[2]);
            }

            if (directory_name.len > 0 && directory_name.str[0] == '&') {
                directory_name.replace ("&", "", 1);
                var split = directory_name.str.split (":");
                directory_name.str = split[0].contains(split[1]) ? split[2] : split[3];
            }

            return directory_name.str;
        }
    }
}