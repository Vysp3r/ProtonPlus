namespace ProtonPlus.Widgets.Dialogs {
    public class InstallDialog : Dialog {
        public Gtk.Button cancel_button { get; set; }

        construct {
            cancel_button = new Gtk.Button.with_label (_("Cancel"));

            content_box.append (cancel_button);
        }
    }
}