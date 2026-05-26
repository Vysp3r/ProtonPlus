namespace ProtonPlus.Widgets.Components {
using Adw;

    class LaunchOptionEntryField : EntryRow {
        public Gtk.Button apply_button { get; private set; }
        public signal void value_applied ();
        string committed_text;

        public LaunchOptionEntryField (string title, string subtitle, string placeholder) {
            Object (title: title);
        //			description = subtitle;
        //			placeholder_text = placeholder;

            committed_text = "";

            apply_button = new Gtk.Button.from_icon_name ("check-symbolic");
            apply_button.set_valign (Gtk.Align.CENTER);
            apply_button.add_css_class ("flat");
            apply_button.clicked.connect (apply_pending_text);
            add_suffix (apply_button);

            this.activate.connect (apply_pending_text);
            this.changed.connect (refresh_apply_state);
            refresh_apply_state ();
        }

        public string get_text () {
            return committed_text;
        }

        public void set_text (string text) {
            committed_text = text.strip ();
            this.text = committed_text;
            refresh_apply_state ();
        }

        public void focus_entry () {
            grab_focus ();
        }

        void apply_pending_text () {
            var pending_text = text.strip ();
            if (pending_text == committed_text)
            return;

            committed_text = pending_text;
            this.text = committed_text;
            refresh_apply_state ();
            value_applied ();
        }

        void refresh_apply_state () {
            apply_button.set_sensitive (text.strip () != committed_text);
        }
    }

}