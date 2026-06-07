namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
    class LaunchOptionResolutionChoice : Object {
        public string label { get; set; }
        public int width { get; set; }
        public int height { get; set; }
        public bool is_auto { get; set; }
        public bool is_custom { get; set; }

        public LaunchOptionResolutionChoice (string label, int width = 0, int height = 0, bool is_auto = false, bool is_custom = false) {
            this.label = label;
            this.width = width;
            this.height = height;
            this.is_auto = is_auto;
            this.is_custom = is_custom;
        }
    }
}