namespace ProtonPlus.Widgets.Loading {
    public class Box : Gtk.Box {
        public signal void loaded (Gee.LinkedList<Models.Launcher> launchers);

        public bool loading { get; set; }

        Adw.StatusPage status_page { get; set; }
        Adw.Spinner spinner { get; set; }
        Gtk.Box bug_box { get; set; }
        Gtk.Box welcome_box { get; set; }

        public Box () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            spinner = new Adw.Spinner ();
            spinner.set_size_request (32, 32);
            spinner.set_halign (Gtk.Align.CENTER);
            spinner.set_valign (Gtk.Align.CENTER);

            bind_property ("loading", spinner, "visible", GLib.BindingFlags.DEFAULT);

            bug_box = create_bug_box ();

            welcome_box = create_welcome_box ();

            var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            content_box.set_halign (Gtk.Align.CENTER);
            content_box.append (spinner);
            content_box.append (bug_box);
            content_box.append (welcome_box);

            status_page = new Adw.StatusPage ();
            status_page.add_css_class ("loading-status-page");
            status_page.set_vexpand (true);
            status_page.set_hexpand (true);
            status_page.set_child (content_box);

            append (status_page);
        }

        public async void load (bool disable_update_check = false) {
            if (loading)
            return;

            loading = true;

            bug_box.hide ();
            welcome_box.hide ();

            status_page.set_icon_name ("com.vysp3r.ProtonPlus");
            status_page.set_title (_ ("Loading"));
            status_page.set_description (_ ("Please wait while we're loading your launchers."));

            Timeout.add_seconds (15, () => {
                if (loading) {
                    status_page.set_description (_ ("Taking longer than normal?\nPlease report this issue on GitHub."));
                }

                return false;
            });

            Gee.LinkedList<Models.Launcher> launchers;

            var success = yield Models.Launcher.get_all (out launchers);

            loading = false;

            if (!success) {
                status_page.set_icon_name ("bug-symbolic");
                status_page.set_title (_ ("An unexpected error occurred"));
                status_page.set_description (_ ("We encountered a problem while loading your application.\nPlease try again or report the problem."));
                bug_box.show ();
                return;
            }

            if (launchers.size > 0) {
                loaded (launchers);
            } else {
                status_page.set_title (_ ("Welcome to %s").printf (Config.APP_NAME));
                status_page.set_description (null);
                welcome_box.show ();
            }
        }

        Gtk.Button create_icon_button (string label, string icon_name, bool suggested = false) {
            var button_content = new Adw.ButtonContent () {
                icon_name = icon_name,
                label = label,
            };

            return create_button (button_content, suggested);
        }

        Gtk.Button create_image_button (string label, string filename, bool suggested = false) {
            var button_image = new Gtk.Image.from_resource ("%s/%s".printf (Config.RESOURCE_BASE, filename));

            var button_label = new Gtk.Label (label);

            var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            button_box.append (button_image);
            button_box.append (button_label);

            return create_button (button_box, suggested);
        }

        Gtk.Button create_button (Gtk.Widget child, bool suggested) {
            var button = new Gtk.Button ();
            button.set_child (child);
            button.set_halign (Gtk.Align.CENTER);
            button.add_css_class ("pill");
            if (suggested)
            button.add_css_class ("suggested-action");

            return button;
        }

        Gtk.Box create_bug_box () {
            var retry_button = create_icon_button (_ ("Retry loading"), "arrow-rotate-symbolic", true);
            retry_button.clicked.connect (() => {
                load.begin ();
            });

            var report_button = create_icon_button (_ ("Report issue"), "github-symbolic");
            report_button.clicked.connect (() => {
                activate_action ("app.report", null);
            });

            var bug_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            bug_box.append (retry_button);
            bug_box.append (report_button);

            return bug_box;
        }

        Gtk.Box create_welcome_box () {
            var first_label = new Gtk.Label ("You need a game launcher to use ProtonPlus.");

            var second_label = new Gtk.Label ("Install one of these to get started:");

            var steam_button = create_image_button ("Steam", "steam.svg");
            steam_button.clicked.connect (() => {
                Utils.System.open_uri ("https://store.steampowered.com/about/");
            });

            var lutris_button = create_image_button ("Lutris", "lutris.svg");
            lutris_button.clicked.connect (() => {
                Utils.System.open_uri ("https://lutris.net/");
            });

            var hgl_button = create_image_button ("Heroic Games Launcher", "hgl.svg");
            hgl_button.clicked.connect (() => {
                Utils.System.open_uri ("https://heroicgameslauncher.com/");
            });

            var bottles_button = create_image_button ("Bottles", "bottles.svg");
            bottles_button.clicked.connect (() => {
                Utils.System.open_uri ("https://usebottles.com/");
            });

            var winezgui_button = create_image_button ("WineZGUI", "winezgui.svg");
            winezgui_button.clicked.connect (() => {
                Utils.System.open_uri ("https://github.com/fastrizwaan/WineZGUI");
            });

            var launchers_box = new Gtk.FlowBox ();
            launchers_box.set_selection_mode (Gtk.SelectionMode.NONE);
            launchers_box.append (steam_button);
            launchers_box.append (lutris_button);
            launchers_box.append (hgl_button);
            launchers_box.append (bottles_button);
            launchers_box.append (winezgui_button);

            var third_label = new Gtk.Label ("Important: Run the launcher once to initialize it properly.");

            var check_button = create_icon_button (_ ("Check again"), "arrow-rotate-symbolic", true);
            check_button.clicked.connect (() => {
                load.begin ();
            });

            var welcome_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            welcome_box.append (first_label);
            welcome_box.append (second_label);
            welcome_box.append (launchers_box);
            welcome_box.append (third_label);
            welcome_box.append (check_button);

            return welcome_box;
        }
    }
}
