namespace ProtonPlus.Runners {
    public abstract class Basic : Models.Runner {
        internal int asset_position { get; set; } // TODO Describe this
        internal string endpoint { get; set; } // TODO Describe this
        internal int page { get; set; } // TODO Describe this

        construct {
            page = 1;
        }

        public abstract string get_directory_name (string release_name);

        public abstract string get_directory_name_reverse (string release_name);
    }
}