namespace ProtonPlus.Models.Runners {
    public abstract class Basic : Runner {
        internal int asset_position { get; set; }
        internal string endpoint { get; set; }
        internal int page { get; set; }

        construct {
            page = 1;
        }

        public abstract string get_directory_name (string release_name);
    }
}