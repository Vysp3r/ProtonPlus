namespace ProtonPlus.Widgets {
    public class MangoHudBox : Gtk.Box {
        public signal void saved ();

        private Models.MangoHudConfig config;
        private MangoHudPresetsPage presets_page;
        private MangoHudVisualPage visual_page;
        private MangoHudPerformancePage performance_page;
        private MangoHudMetricsPage metrics_page;
        private MangoHudExtrasPage extras_page;

        public MangoHudBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            set_vexpand (true);

            config = new Models.MangoHudConfig ();
            config.load ();

            var stack = new Adw.ViewStack () {
                vexpand = true
            };

            var switcher = new Adw.ViewSwitcher () {
                stack = stack,
                policy = Adw.ViewSwitcherPolicy.WIDE
            };

            presets_page = new MangoHudPresetsPage (config);
            visual_page = new MangoHudVisualPage (config);
            performance_page = new MangoHudPerformancePage (config);
            metrics_page = new MangoHudMetricsPage (config);
            extras_page = new MangoHudExtrasPage (config);

            stack.add_titled_with_icon (create_scrolled_window (presets_page), "presets", _ ("Presets"), "view-list-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (visual_page), "visual", _ ("Visual"), "video-display-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (performance_page), "performance", _ ("Performance"), "speedometer-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (metrics_page), "metrics", _ ("Metrics"), "utilities-system-monitor-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (extras_page), "extras", _ ("Extras"), "view-more-symbolic");

            presets_page.changed.connect (refresh_all);
            visual_page.changed.connect (refresh_all);
            performance_page.changed.connect (refresh_all);
            metrics_page.changed.connect (refresh_all);
            extras_page.changed.connect (refresh_all);

            append (stack);

            var action_bar = new Gtk.ActionBar ();
            action_bar.set_center_widget (switcher);
            var save_button = new Gtk.Button.from_icon_name ("floppy-disk-symbolic") {
                valign = Gtk.Align.CENTER
            };
            save_button.add_css_class ("suggested-action");
            save_button.clicked.connect (() => {
                config.save ();
                saved ();
            });
            action_bar.pack_end (save_button);
            append (action_bar);
        }

        private void refresh_all () {
            presets_page.refresh ();
            visual_page.refresh ();
            performance_page.refresh ();
            metrics_page.refresh ();
            extras_page.refresh ();
        }

        private Gtk.ScrolledWindow create_scrolled_window (Gtk.Widget child) {
            var scrolled = new Gtk.ScrolledWindow () {
                child = new Adw.Clamp () { child = child, maximum_size = 975, margin_top = 0, margin_bottom = 15, margin_start = 0, margin_end = 0 },
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vexpand = true
            };
            return scrolled;
        }
    }
}
