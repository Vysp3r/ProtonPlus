namespace ProtonPlus.Widgets.ReleaseRows {
    public class InstalledRow : ReleaseRow {
        Models.Releases.Basic release { get; set; }
        public signal void remove_from_parent (InstalledRow row);

        public InstalledRow (Models.Releases.Basic release) {
            this.release = release;

            set_title(release.title);

            install_button.set_visible (false);
            info_button.set_visible (false);
        }

        protected override void install_button_clicked () { }

        protected override void remove_button_clicked () {
            var remove_dialog = new RemoveDialog (release);
            remove_dialog.done.connect((result) => {
                if (result)
                    remove_from_parent(this);
            });
            remove_dialog.present (Application.window);
        }

        protected override void info_button_clicked () { }
    }
}