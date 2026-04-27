namespace ProtonPlus.Widgets.Tools {
    public class ReleasesBox : Gtk.Box {
        Gtk.Box tool_box { get; set; }
        Gtk.Label title_label { get; set; }
        Gtk.Label desc_label { get; set; }
        Gtk.Box header_box { get; set; }
        Gtk.ListBox list_box { get; set; }
        Gtk.Stack content_stack { get; set; }

        public ReleasesBox () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            var icon = new Gtk.Image.from_icon_name ("layer-group-symbolic");

            title_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "title-4" }
            };

            desc_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                css_classes = { "caption" },
                wrap = true,
                xalign = 0
            };

            var title_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            title_box.append (title_label);
            title_box.append (desc_label);

            header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.append (icon);
            header_box.append (title_box);

            list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE
            };
            list_box.add_css_class ("boxed-list");
            list_box.add_css_class ("tools-releases-card");

            var scrolled = new Gtk.ScrolledWindow () {
                child = list_box,
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC
            };

            var spinner = new Adw.Spinner () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                hexpand = true,
                vexpand = true
            };
            spinner.set_size_request (32, 32);

            var spinner_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                vexpand = true,
                hexpand = true,
            };
            spinner_box.add_css_class ("card");
            spinner_box.add_css_class ("tools-spinner-box");
            spinner_box.append (spinner);

            content_stack = new Gtk.Stack () {
                vexpand = true
            };
            content_stack.add_named (scrolled, "list");
            content_stack.add_named (spinner_box, "spinner");

            tool_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            tool_box.add_css_class ("card");
            tool_box.add_css_class ("tools-group-card");
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

        public async void set_selected_tool (Models.Tool tool) {
            content_stack.set_visible_child_name ("spinner");

            list_box.remove_all ();

            title_label.set_label (tool.title);
            desc_label.set_label (tool.description);

            ReturnCode code;
            Gee.LinkedList<Models.Release> releases = yield tool.get_releases_async (out code);
            if (code != ReturnCode.RELEASES_LOADED) {
                Adw.AlertDialog dialog;

                switch (code) {
                    case ReturnCode.API_LIMIT_REACHED:
                        dialog = new Main.WarningDialog (_ ("API limit reached"), _ ("Try again in a few minutes."));
                        break;
                    case ReturnCode.CONNECTION_ISSUE:
                        dialog = new Main.WarningDialog (_ ("Unable to reach the API"), _ ("Make sure you're connected to the internet."));
                        break;
                    case ReturnCode.CONNECTION_REFUSED:
                        dialog = new Main.WarningDialog (_ ("Unable to reach the API"), _ ("Make sure your DNS is not blocking this."));
                        break;
                    case ReturnCode.CONNECTION_UNKNOWN:
                        dialog = new Main.WarningDialog (_ ("Unable to reach the API"), _ ("The requested website does not seem to be valid."));
                        break;
                    case ReturnCode.INVALID_ACCESS_TOKEN:
                        dialog = new Main.WarningDialog (_ ("Invalid access token"), _ ("Make sure the access token you provided is valid."));
                        break;
                    default:
                        dialog = new Main.ErrorDialog (_ ("Unknown error"), _ ("Please report this issue on GitHub."));
                        break;
                }

                content_stack.set_visible_child_name ("list");

                dialog.present ((Gtk.Window) this.get_root ());

                return;
            }

            foreach (var release in releases) {
                if (release is Models.Releases.SteamTinkerLaunch)
                list_box.append (new STLReleaseRow (release));
                else
                list_box.append (new ReleaseRow (release));
            }

            content_stack.set_visible_child_name ("list");
        }
    }
}