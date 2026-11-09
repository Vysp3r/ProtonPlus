namespace ProtonPlus.Widgets.Introduction {
    public class Introduction : Adw.Dialog {
        bool show_help = false;

        public signal void help_requested ();

        public Introduction () {
            title = _("Welcome");
            content_width = 520;
            content_height = 480;

            var toolbar = new Adw.ToolbarView ();
            toolbar.add_top_bar (new Adw.HeaderBar ());
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                margin_start = 24, margin_end = 24,
                margin_top = 24, margin_bottom = 24,
                valign = Gtk.Align.CENTER, vexpand = true
            };
            var introduction = new Application () {
                margin_top = 0, margin_bottom = 0,
                margin_start = 0, margin_end = 0,
                vexpand = false
            };
            var icon = introduction.get_first_child () as Gtk.Image;
            if (icon != null)
                icon.pixel_size = 64;
            content.append (introduction);
            var first_step = new Gtk.Label (_("Choose a launcher from the top-left menu, then select a tool to install")) {
                wrap = true, justify = Gtk.Justification.CENTER, max_width_chars = 45
            };
            content.append (first_step);

            var actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                halign = Gtk.Align.CENTER, margin_top = 6, margin_bottom = 18
            };
            var start = new Gtk.Button.with_label (_("Get Started"));
            start.add_css_class ("suggested-action");
            start.clicked.connect (() => close ());
            var learn_more = new Gtk.Button.with_label (_("Learn More"));
            learn_more.add_css_class ("flat");
            learn_more.clicked.connect (() => {
                show_help = true;
                close ();
            });
            actions.append (learn_more);
            actions.append (start);
            toolbar.add_bottom_bar (actions);
            closed.connect (() => {
                if (show_help)
                    help_requested ();
            });
            toolbar.content = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                child = new Adw.Clamp () { maximum_size = 520, child = content }
            };
            child = toolbar;
            default_widget = start;
            set_focus (start);
        }
    }
}
