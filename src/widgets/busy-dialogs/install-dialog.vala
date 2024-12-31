namespace ProtonPlus.Widgets.Dialogs {
    public class InstallDialog : BusyDialog {
        public override void initialize (Models.Release release) {
            base.initialize (release);

            header_bar.set_show_end_title_buttons (true);

            window_title.set_title  (_("Installing"));

            release.notify["progress"].connect (release_progress_changed);
        }

        public override bool close_request () {
            release.canceled = true;

            return base.close_request ();
        }

        void release_progress_changed () {
            progress_label.set_text (release.progress);
            if (progress_label.get_parent () == null)
                list.append (progress_label);
        }
    }
}