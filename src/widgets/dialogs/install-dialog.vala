namespace ProtonPlus.Widgets.Dialogs {
    public class InstallDialog : Dialog {
        public Gtk.Button cancel_button { get; set; }
        public string progress_text { get; set; }

        construct {
            cancel_button = new Gtk.Button.with_label (_("Cancel"));

            content_box.append (cancel_button);

            notify["progress-text"].connect (progress_text_changed);
        }

        public override void reset () {
            base.reset ();

            cancel_button.set_visible (true);

            close_buttton.set_visible (false);
        }

        public override void done (bool success) {
            cancel_button.set_visible (false);

            close_buttton.set_visible (true);

            base.done (success);
        }

        void progress_text_changed () {
            var current_text = label.get_text ();
            if (!current_text.contains (progress_text))
                label.set_text ("%s\n%s".printf (current_text, progress_text));
        }
    }
}