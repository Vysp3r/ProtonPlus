namespace ProtonPlus.Widgets.Header {
    public class Presentation : Object {
        public Gtk.Widget title_widget { get; private set; }
        public bool can_navigate_back { get; private set; }
        public Gee.ArrayList<Gtk.Widget> end_actions { get; private set; }
        public weak Gtk.Widget? back_widget { get; private set; }

        public signal void back_requested ();
        public signal void back_widget_changed (Gtk.Widget? widget);

        public Presentation (Gtk.Widget title_widget, bool can_navigate_back = true) {
            this.title_widget = title_widget;
            this.can_navigate_back = can_navigate_back;
            end_actions = new Gee.ArrayList<Gtk.Widget> ();
        }

        public void add_end_action (Gtk.Widget action) {
            end_actions.add (action);
        }

        public void request_back () {
            if (can_navigate_back)
                back_requested ();
        }

        public void attach_back_widget (Gtk.Widget? widget) {
            if (back_widget == widget)
                return;
            back_widget = widget;
            back_widget_changed (widget);
        }
    }
}
