namespace ProtonPlus.Models {
    public class SimpleRunner : Object {
        public string display_title { get; set; }
        public string title { get; set; }

        public SimpleRunner (string display_title, bool format) {
            this.display_title = display_title;

            if (display_title == "SteamTinkerLaunch") {
                message("bob");
                this.display_title = "Steam Tinker Launch";
                title = "Proton-stl";
            } else
                this.title = format ? display_title.down ().split (".", 2)[0].replace (" ", "_") : display_title;
        }
    }
}