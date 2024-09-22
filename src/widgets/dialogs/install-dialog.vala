namespace ProtonPlus.Widgets.Dialogs {
    public class InstallDialog : Dialog {
        public Gtk.Button cancel_button { get; set; }

        construct {
            cancel_button = new Gtk.Button.with_label (_("Cancel"));

            cancel_button.clicked.connect (() => release.canceled = true);

            content_box.append (cancel_button);
        }

        public override void initialize (Models.Release release) {
            base.initialize (release);

            release.notify["progress"].connect (release_progress_changed);
        }

        public override void reset () {
            base.reset ();

            cancel_button.set_visible (true);

            close_button.set_visible (false);
        }

        public override void done (bool success) {
            cancel_button.set_visible (false);

            close_button.set_visible (true);

            base.done (success);
        }

        void release_progress_changed () {
            var current_text = label.get_text ();
            if (!current_text.contains (release.progress))
                label.set_text ("%s\n%s".printf (current_text, release.progress));
        }
    }
}