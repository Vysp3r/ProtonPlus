namespace ProtonPlus.Widgets.Dialogs {
    public class InstallDialog : BusyDialog {
        public InstallDialog (Models.Release release) {
            initialize (release);

            window_title.set_title (_("Installing"));

            release.notify["progress"].connect (release_progress_changed);

            closed.connect (install_dialog_on_close);
        }

        void install_dialog_on_close () {
            dialog_on_close ();

            release.canceled = true;
        }

        void release_progress_changed () {
            progress_label.set_text (release.progress);
            if (progress_label.get_parent () == null)
                container.append (progress_label);

            progress_bar.set_fraction (double.parse (release.progress) / 100);

            pulse = progress_bar.get_fraction () == 1;

            header_bar.set_show_end_title_buttons (!pulse);
        }
    }
}