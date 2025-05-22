namespace ProtonPlus.Models {
    public struct AwacyGame {
        int appid;
        string name;
        string status;
    }

    public class Game : Object {
        public int appid { get; set; }
        public string name { get; set; }
        public string installdir { get; set; }
        public int library_folder_id { get; set; }
        public string library_folder_path { get; set; }
        public string awacy_name { get; set; }
        public string awacy_status { get; set; }
        public string compat_tool { get; set; }

        public Game(int appid, string name, string installdir, int library_folder_id, string library_folder_path) {
            this.appid = appid;
            this.name = name;
            this.installdir = installdir;
            this.library_folder_id = library_folder_id;
            this.library_folder_path = library_folder_path;
        }
    }
}