namespace ProtonPlus.Widgets.Introduction {
    public class HelpDialog : Adw.Dialog, Utils.ControllerNavigationHost {
        Adw.NavigationView navigation;
        Gtk.Widget? first_topic;
        string? requested_preferences;

        public signal void preferences_requested (string page_name);

        public HelpDialog () {
            title = _("Help");
            content_width = 600;
            content_height = 560;
            navigation = new Adw.NavigationView ();
            child = navigation;
            closed.connect (() => {
                if (requested_preferences != null)
                    preferences_requested ((!) requested_preferences);
            });

            var index = new Adw.PreferencesPage ();
            var tasks = new Adw.PreferencesGroup () { title = _("Using ProtonPlus") };
            index.add (tasks);
            navigation.add (page (index, _("Help"), "topics"));

            add_topic (tasks, "install", _("Install a Compatibility Tool"),
                _("Choose a launcher and install a release"), "folder-download-symbolic", {
                    _("1. Choose a game launcher from the top-left menu"),
                    _("2. Open the Tools tab and select a tool to see its releases"),
                    _("3. Choose a release and select Install"),
                    _("Installing a tool makes it available to the selected launcher. Select it for a game before playing.")
                });
            add_topic (tasks, "select", _("Choose a Tool for a Game"),
                _("Use an installed tool with a game"), "applications-games-symbolic", {
                    _("1. Select the launcher where the tool is installed"),
                    _("2. Open the Games tab and choose the game’s compatibility tool, where supported"),
                    _("3. For other launchers, select the tool in the launcher’s game settings"),
                    _("Follow any Steam restart prompt to finish applying changes. Close running games before restarting Steam.")
                });
            add_topic (tasks, "updates", _("Update Tools"),
                _("Update manually or set a schedule"), "view-refresh-symbolic", {
                    _("Select Update Tools in the Tools tab to update eligible installed tools"),
                    _("Automatic updates check for and install updates. Configure scheduled updates or updates at startup in Preferences → Tools."),
                    _("Scheduled updates can run while ProtonPlus is closed. System-startup and app-startup updates are separate options.")
                }, _("Open Update Preferences"), "tools");
            add_topic (tasks, "controller", _("Use a Controller"),
                _("Navigation, buttons, and text input"), "input-gaming-symbolic", {
                    _("Use the D-pad or sticks to move between controls. Use the shoulder buttons to switch sections where available."),
                    _("Follow the on-screen button hints for Confirm, Back, Search, and Filter. Hints match the controller’s button labels."),
                    _("Choose the Confirm button and enable vibration in Preferences → General"),
                    _("On Steam Deck, focus a text field and press Steam + X. Other systems may require a physical or system keyboard.")
                }, _("Open Controller Preferences"), "general");

            var reference = new Adw.PreferencesGroup () { title = _("Learn More") };
            index.add (reference);
            add_topic (reference, "compatibility", _("Understand Wine and Proton"),
                _("Compatibility tools and community builds"), "dialog-information-symbolic", {
                    _("Wine lets Windows applications run on Linux. Launchers such as Lutris use Wine builds."),
                    _("Proton combines Wine with gaming components for Steam Play. Choose a Proton build for Steam games."),
                    _("Community builds such as GE-Proton include additional fixes and game-specific changes. A newer or different build is not always better for every game."),
                    _("Keep multiple versions installed when different games need different builds")
                });
            add_topic (reference, "troubleshooting", _("Troubleshooting"),
                _("Missing tools, game issues, and system information"), "dialog-question-symbolic", {
                    _("If a tool is missing, check that the selected launcher matches the installation used to run the game"),
                    _("If Steam has not picked up a change, follow the pending restart prompt"),
                    _("If a game stops working after changing tools, try the previously working version"),
                    _("For support, open Preferences → Advanced → System Information and copy the detected environment details")
                }, _("Open Advanced Preferences"), "advanced");
        }

        Adw.NavigationPage page (Gtk.Widget content, string title, string tag) {
            var toolbar = new Adw.ToolbarView ();
            toolbar.add_top_bar (new Adw.HeaderBar ());
            toolbar.content = content;
            return new Adw.NavigationPage.with_tag (toolbar, title, tag);
        }

        void add_topic (Adw.PreferencesGroup group, string tag, string title,
            string subtitle, string icon, string[] paragraphs,
            string? action_title = null, string? preferences_page = null) {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 18) {
                margin_top = 24, margin_bottom = 24,
                margin_start = 24, margin_end = 24
            };
            foreach (var paragraph in paragraphs) {
                var label = new Gtk.Label (paragraph) {
                    wrap = true, xalign = 0,
                    hexpand = true, halign = Gtk.Align.FILL
                };
                content.append (label);
            }
            if (action_title != null && preferences_page != null) {
                var button = new Gtk.Button.with_label (action_title) { halign = Gtk.Align.START };
                button.clicked.connect (() => {
                    requested_preferences = preferences_page;
                    close ();
                });
                content.append (button);
            }
            var clamp = new Adw.Clamp () { maximum_size = 560, child = content };
            var scroll = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                child = clamp,
                focusable = true
            };
            var topic = page (scroll, title, tag);
            var row = new Adw.ActionRow () { title = title, subtitle = subtitle, activatable = true };
            row.add_prefix (new Gtk.Image.from_icon_name (icon));
            row.add_suffix (new Gtk.Image.from_icon_name ("go-next-symbolic"));
            row.activated.connect (() => navigation.push (topic));
            topic.hidden.connect (() => row.grab_focus ());
            group.add (row);
            if (first_topic == null)
                first_topic = row;
        }

        public string get_controller_page_id () {
            return "help:%s".printf (navigation.visible_page.tag);
        }

        public Object? get_controller_page_root () { return navigation.visible_page; }
        public Object? get_controller_initial_focus () {
            if (!controller_can_navigate_back ())
                return first_topic;
            // Focus the scrollable article before its optional action button.
            return find_scroll (navigation.visible_page);
        }

        Gtk.Widget? find_scroll (Gtk.Widget root) {
            if (root is Gtk.ScrolledWindow)
                return root;
            for (var child = root.get_first_child (); child != null; child = child.get_next_sibling ()) {
                var scroll = find_scroll (child);
                if (scroll != null)
                    return scroll;
            }
            return null;
        }

        public bool controller_can_navigate_back () {
            return navigation.get_previous_page (navigation.visible_page) != null;
        }
        public bool controller_navigate_back () { return navigation.pop (); }
        public bool controller_can_switch_page () { return false; }
        public bool controller_switch_page (int delta) { return false; }
        public bool controller_prefers_initial_focus_after_switch () { return true; }
    }
}
