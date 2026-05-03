namespace ProtonPlus.Widgets.Tools {
    public class ReleaseBox : Gtk.Box {
        public Adw.ViewSwitcher stack_switcher { get; set; }
        Gtk.Box tool_box { get; set; }
        Gtk.Label title_label { get; set; }
        Gtk.Label desc_label { get; set; }
        Gtk.TextView desc_text { get; set; }
        Gtk.Box header_box { get; set; }
        Gtk.ListBox list_box { get; set; }
        Adw.ViewStack content_stack { get; set; }

        public ReleaseBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            var icon = new Gtk.Image.from_icon_name ("box-open-symbolic");

            title_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            desc_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "subtitle" }
            };

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true
            };
            title_box.append (title_label);
            title_box.append (desc_label);

            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (icon);
            header_box.append (title_box);

            content_stack = new Adw.ViewStack () {
                vexpand = true,
                overflow = Gtk.Overflow.HIDDEN
            };

            stack_switcher = new Adw.ViewSwitcher () {
                stack = content_stack,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            stack_switcher.set_policy (Adw.ViewSwitcherPolicy.WIDE);

            desc_text = new Gtk.TextView () {
                editable = false,
                cursor_visible = false,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                left_margin = 12,
                right_margin = 12,
                top_margin = 12,
                bottom_margin = 12
            };

            var scrolled_desc = new Gtk.ScrolledWindow () {
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = desc_text,
                overflow = Gtk.Overflow.HIDDEN
            };

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("list-content");

            var scrolled_games = new Gtk.ScrolledWindow () {
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = list_box,
                overflow = Gtk.Overflow.HIDDEN
            };

            var name_label = new Gtk.Label(_ ("Name"));
            name_label.set_xalign (0);
            name_label.set_hexpand (true);

            var list_header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            list_header_box.add_css_class ("list-header");
            list_header_box.set_hexpand (true);
            list_header_box.set_overflow (Gtk.Overflow.HIDDEN);
            list_header_box.append (name_label);

            var headered_list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            headered_list_box.set_hexpand (true);
            headered_list_box.add_css_class ("card");
            headered_list_box.add_css_class ("transparent-card");
            headered_list_box.set_overflow (Gtk.Overflow.HIDDEN);
            headered_list_box.append (list_header_box);
            headered_list_box.append (scrolled_games);

            content_stack.add_titled_with_icon (scrolled_desc, "changelog", _ ("Changelog"), "book-open-symbolic");
            content_stack.add_titled_with_icon (headered_list_box, "games", _ ("Used by"), "gamepad-symbolic");
            content_stack.add_css_class ("card");

            tool_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            tool_box.append (header_box);
            tool_box.append (content_stack);

            var clamp = new Adw.Clamp () {
                maximum_size = 975,
                margin_top = 5,
                margin_bottom = 12,
                child = tool_box,
            };

            append (clamp);
        }

        public void set_selected_release (Models.Release release) {
            title_label.set_label (release.title ?? "");
            desc_text.buffer.text = release.description ?? "";
            desc_label.set_label (release.release_date ?? "");

            content_stack.set_visible_child_name ("changelog");

            list_box.remove_all ();

            var tool_name = (release.runner is Models.Tools.SteamTinkerLaunch) ? "Proton-stl" : release.title;
            var launcher = release.runner.group.launcher;

            string default_tool = "";
            var steam_launcher = launcher as Models.Launchers.Steam;
            if (steam_launcher != null) {
                default_tool = steam_launcher.default_compatibility_tool;
            }
            bool is_default_tool = tool_name == default_tool;

            if (launcher.games != null) {
                foreach (var game in launcher.games) {
                    if (!game.is_native && (game.compatibility_tool == tool_name || (is_default_tool && game.compatibility_tool == "Default"))) {
                        list_box.append (create_game_row (game));
                    }
                }
            }

            if (steam_launcher != null) {
                if (steam_launcher.profiles != null) {
                    foreach (var profile in steam_launcher.profiles) {
                        if (profile.non_steam_games != null) {
                            foreach (var game in profile.non_steam_games) {
                                if (!game.is_native && (game.compatibility_tool == tool_name || (is_default_tool && game.compatibility_tool == "Default"))) {
                                    list_box.append (create_game_row (game));
                                }
                            }
                        }
                    }
                }
            }
        }

        Adw.ActionRow create_game_row (Models.Game game) {
            return new Adw.ActionRow () {
                title = game.name,
            };
        }
    }
}
