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

            SetSize ();
        }

        public void SetSize () {
            if (Installed) Size = (int64) Utils.Filesystem.GetDirectorySize (Directory);
        }

        public string GetFormattedDownloadSize () {
            if (DownloadSize < 0) return "Not available";
            return Utils.Filesystem.ConvertBytesToString (DownloadSize);
        }

        public string GetFormattedSize () {
            return Utils.Filesystem.ConvertBytesToString (Size);
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
            case Models.Tool.TitleTypes.PROTON_TKG:
                return @"Proton-Tkg-$Title";
            case Models.Tool.TitleTypes.LUTRIS_DXVK:
                return @"dxvk-" + Title.replace ("v", "");
            case Models.Tool.TitleTypes.LUTRIS_DXVK_ASYNC_SPORIF:
                return @"dxvk-async-$Title";
            case Models.Tool.TitleTypes.LUTRIS_DXVK_ASYNC_GNUSENPAI:
                return @"dxvk-sc-async-" + Title.replace ("v", "").replace ("-sc-async", "");
            case Models.Tool.TitleTypes.LUTRIS_WINE_GE:
                return @"lutris-$Title-x86_64";
            case Models.Tool.TitleTypes.LUTRIS_WINE:
                return Title.replace ("-wine", "") + "-x86_64";
            case Models.Tool.TitleTypes.LUTRIS_KRON4EK_VANILLA:
                return @"wine-$Title-amd64";
            case Models.Tool.TitleTypes.LUTRIS_KRON4EK_TKG:
                return @"wine-$Title-staging-tkg-amd64";
            default:
                return Title;
            }
        }

        public void Delete (bool joinThread = false) {
            var thread = new Thread<void> ("deleteThread", () => {
                Utils.Filesystem.DeleteDirectory (Tool.Launcher.FullPath + "/" + GetDirectoryName ());
                Tool.Launcher.uninstall (this);
                Installed = false;
            });
            if (joinThread) thread.join ();
        }
    }
}
