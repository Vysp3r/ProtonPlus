namespace ProtonPlus.Widgets.MangoHud {
    public class Box : Gtk.Box {
        public signal void saved ();

        private Models.MangoHudConfig config;
        private PresetsPage presets_page;
        private VisualPage visual_page;
        private PerformancePage performance_page;
        private MetricsPage metrics_page;
        private ExtrasPage extras_page;
        private Adw.ViewStack stack;

        public Box () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            set_vexpand (true);

            config = new Models.MangoHudConfig ();
            config.load ();

            stack = new Adw.ViewStack () {
                vexpand = true
            };

            var switcher = new Adw.ViewSwitcher () {
                stack = stack,
                policy = Adw.ViewSwitcherPolicy.WIDE
            };

            presets_page = new PresetsPage (config);
            visual_page = new VisualPage (config);
            performance_page = new PerformancePage (config);
            metrics_page = new MetricsPage (config);
            extras_page = new ExtrasPage (config);

            stack.add_titled_with_icon (create_scrolled_window (presets_page), "presets", _ ("Presets"), "list-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (visual_page), "visual", _ ("Visual"), "eye-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (performance_page), "performance", _ ("Performance"), "gauge-high-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (metrics_page), "metrics", _ ("Metrics"), "chart-area-symbolic");
            stack.add_titled_with_icon (create_scrolled_window (extras_page), "extras", _ ("Extras"), "plus-symbolic");

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
            save_button.set_tooltip_text (_ ("Save the current configuration"));
            save_button.clicked.connect (() => {
                config.save ();
                saved ();
            });
            action_bar.pack_end (save_button);

            var advanced_switch = new Gtk.Switch () {
                valign = Gtk.Align.CENTER,
                active = false
            };
            var advanced_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
                valign = Gtk.Align.CENTER
            };
            advanced_box.append (new Gtk.Label (_ ("Advanced")));
            advanced_box.append (advanced_switch);
            advanced_switch.bind_property ("active", switcher, "visible", BindingFlags.SYNC_CREATE);
            action_bar.pack_end (advanced_box);

            var cube_button_content = new Adw.ButtonContent ();
            cube_button_content.set_label (_ ("Preview"));
            cube_button_content.set_icon_name ("cube-symbolic");
            var cube_button = new Gtk.Button() {
                valign = Gtk.Align.CENTER,
                child = cube_button_content,
            };
            cube_button.set_tooltip_text (_ ("Show vkcube"));
            cube_button.clicked.connect (cube_button_clicked);
            action_bar.pack_start (cube_button);
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

        private void cube_button_clicked () {
            try {
                string command = "env MANGOHUD=1 vkcube";
                if (ProtonPlus.Globals.IS_FLATPAK) {
                    command = "flatpak-spawn --host " + command;
                }
                string[] argv;
                GLib.Shell.parse_argv (command, out argv);
                GLib.Process.spawn_async (null, argv, null, GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD, null, null);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        }

        public void show_presets_page () {
            stack.set_visible_child_name ("presets");
        }
    }
}
