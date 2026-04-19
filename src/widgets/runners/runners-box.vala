using Gee;

namespace ProtonPlus.Widgets {
    public class RunnersBox : Gtk.Box {
        private bool _installed_only;
        public bool installed_only {
            get { return _installed_only; }
            set {
                if (_installed_only == value) return;
                _installed_only = value;
                foreach (var runner_group in runner_groups) {
                    runner_group.load (value);
                }
            }
        }

        private Models.Launcher _launcher;
        public Models.Launcher launcher {
            get { return _launcher; }
            set {
                if (_launcher == value) return;
                _launcher = value;
                update_launcher ();
            }
        }

        private FiltersBox filters_box;
        private Gtk.Box content;
        private Adw.Clamp clamp;
        private Gtk.ScrolledWindow scrolled_window;
        private ArrayList<RunnerGroup> runner_groups = new ArrayList<RunnerGroup>();
        private Gtk.Label empty_label;

        public RunnersBox() {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            set_vexpand (true);

            filters_box = new FiltersBox();
            filters_box.bind_property ("installed-only", this, "installed-only", BindingFlags.BIDIRECTIONAL);

            content = new Gtk.Box(Gtk.Orientation.VERTICAL, 15);
            content.set_hexpand (true);

            empty_label = new Gtk.Label(_ ("No runners found."));
            empty_label.add_css_class ("title-2");
            empty_label.vexpand = true;
            empty_label.set_margin_top (7);
            empty_label.set_margin_start (15);
            empty_label.set_margin_end (15);
            empty_label.set_margin_bottom (15);
            empty_label.hide ();

            clamp = new Adw.Clamp();
            clamp.maximum_size = 975;
            clamp.child = content;
            clamp.set_margin_top (7);
            clamp.set_margin_start (15);
            clamp.set_margin_end (15);
            clamp.set_margin_bottom (15);

            scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.child = clamp;
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.vexpand = true;

            append (scrolled_window);
            append (empty_label);
            append (filters_box);
        }

        private void update_launcher () {
        // Remove all current runner groups from content box
            while (true) {
                var child = content.get_first_child ();
                if (child == null) break;
                content.remove (child);
            }

            runner_groups.clear ();

            if (_launcher == null || _launcher.groups == null || _launcher.groups.length == 0) {
                scrolled_window.hide ();
                empty_label.show ();
                return;
            }

            scrolled_window.show ();
            empty_label.hide ();

            foreach (var group in _launcher.groups) {
                var runner_group = new RunnerGroup(group, installed_only);
                runner_groups.add (runner_group);
                content.append (runner_group);
            }

            filters_box.apply_filters ();
        }

        public void set_selected_launcher (Models.Launcher launcher) {
            this.launcher = launcher;
        }
    }
}