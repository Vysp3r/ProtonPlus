namespace Models {
    public class Release : Object {
        public Models.Tool Tool;
        public string Title;
        public string DownloadURL;
        public string ChecksumURL;
        public string PageURL;
        public string ReleaseDate;
        public int64 DownloadSize;
        public string FileExtension;
        public bool Installed;
        public string Directory;
        public int64 Size;
        public bool InstallCancelled;

        public Release (Models.Tool tool, string title, string download_url = "", string page_url = "", string release_date = "", string checksum_url = "", int64 download_size = 0, string file_extension = ".tar.gz") {
            Tool = tool;
            Title = title;
            DownloadURL = download_url;
            PageURL = page_url;
            FileExtension = file_extension;
            ReleaseDate = release_date;
            DownloadSize = download_size;
            ChecksumURL = checksum_url;
            Directory = Tool.Launcher.FullPath + "/" + GetDirectoryName ();
            Installed = FileUtils.test (Directory, FileTest.IS_DIR);
            Size = 0;

            SetSize();
        }

        public void SetSize () {
            if (Installed) {
                var dirUtil = new Utils.DirUtil (Directory);
                Size = (int64) dirUtil.get_total_size ();
            }
        }

        public string GetFormattedDownloadSize () {
            return Utils.File.BytesToString (DownloadSize);
        }

        public string GetFormattedSize () {
            return Utils.File.BytesToString (Size);
        }

        public string GetDirectoryName () {
            switch (Tool.TitleType) {
            case Models.Tool.TitleTypes.WINE_LUTRIS_BOTTLES:
                return Title.down ().replace ("-wine", "");
            case Models.Tool.TitleTypes.WINE_GE_BOTTLES:
                return "wine-" + Title.down ();
            case Models.Tool.TitleTypes.BOTTLES:
                return Title.down ().replace (" ", "-");
            case Models.Tool.TitleTypes.PROTON_HGL:
                return @"Proton-$Title";
            case Models.Tool.TitleTypes.WINE_HGL:
                return @"Wine-$Title";
            case Models.Tool.TitleTypes.TOOL_NAME:
                return Tool.Title + @" $Title";
            default:
                return Title;
            }
        }

        public void Delete () {
            new Thread<void> ("deleteThread", () => {
                var dir = new Utils.DirUtil (Tool.Launcher.FullPath);
                dir.remove_dir (Title);
                Tool.Launcher.uninstall (this);
                Installed = false;
            });
        }

        public void Install () {
            new Thread<void> ("deleteThread", () => {
            });
        }
    }
}
