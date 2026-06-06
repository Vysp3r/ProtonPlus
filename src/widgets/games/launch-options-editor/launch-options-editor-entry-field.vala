namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;

    class LaunchOptionEntryField : EntryRow {
        public Gtk.Button apply_button { get; private set; }
        public signal void value_applied ();

        string committed_text;
        Gtk.EventControllerKey key_controller;

        public LaunchOptionEntryField (string title, string subtitle, string placeholder) {
            Object ();
            this.title = title;

            committed_text = "";

            apply_button = new Gtk.Button.from_icon_name ("object-select-symbolic");
            apply_button.set_valign (Gtk.Align.CENTER);
            apply_button.add_css_class ("flat");
            apply_button.clicked.connect (apply_pending_text);
            add_suffix (apply_button);

            this.activates_default = false;

            key_controller = new Gtk.EventControllerKey ();
            key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                    apply_pending_text ();
                    return true;
                }
                return false;
            });

            this.add_controller (key_controller);


            this.activate.connect (() => {
                apply_pending_text ();
            });
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