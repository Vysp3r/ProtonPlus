namespace ProtonPlus.Widgets.Main {
    using ProtonPlus.Models;

    /* Presents the manual recovery steps for a Steam-reported "fully
     * installed, buildid 0" compatibility tool or runtime. ProtonPlus does
     * not perform any of these steps itself: they mutate Steam's own
     * download/depot state, which stays outside tool management here.
     *
     * Steps are shown one at a time in a carousel (the same pattern
     * Introduction uses), each gated by an explicit "I've done this"
     * checkbox before the user can advance, since skipping ahead in a
     * multi-step manual recovery is how people end up editing the wrong
     * appmanifest. Commands are deliberately left untranslated, the same way
     * ErrorDialog leaves its technical-details text untranslated: they are
     * literal shell transcripts, not UI copy. */
    public class SteamRepairGuideDialog : Adw.Dialog {
        private class StepPage : Gtk.Box {
            public Gtk.CheckButton? confirm_check = null;

            public StepPage (string heading, string body, string? code, Gtk.Widget? extra, bool needs_confirmation) {
                Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12);
                margin_top = 12;
                margin_bottom = 12;
                margin_start = 12;
                margin_end = 12;

                var heading_label = new Gtk.Label (heading) { xalign = 0, wrap = true };
                heading_label.add_css_class ("title-4");
                append (heading_label);

                append (new Gtk.Label (body) { xalign = 0, wrap = true });

                if (code != null) {
                    var code_label = new Gtk.Label (code) {
                        xalign = 0,
                        selectable = true,
                        margin_top = 6,
                        margin_bottom = 6,
                        margin_start = 8,
                        margin_end = 8,
                    };
                    code_label.add_css_class ("monospace");

                    var scrolled = new Gtk.ScrolledWindow () {
                        hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                        vscrollbar_policy = Gtk.PolicyType.NEVER,
                        child = code_label,
                    };
                    scrolled.add_css_class ("card");
                    append (scrolled);

                    var copy_button = new Gtk.Button.with_label (_ ("Copy")) { halign = Gtk.Align.END };
                    copy_button.clicked.connect (() => {
                        code_label.get_clipboard ().set_text (code);
                    });
                    append (copy_button);
                }

                if (extra != null)
                    append (extra);

                append (new Gtk.Box (Gtk.Orientation.VERTICAL, 0) { vexpand = true });

                if (needs_confirmation) {
                    confirm_check = new Gtk.CheckButton () { label = _ ("I’ve done this") };
                    append (confirm_check);
                }
            }
        }

        private Adw.Carousel car;
        private Gtk.Button prev_button;
        private Gtk.Button next_button;
        private Gee.ArrayList<Gtk.Widget> pages = new Gee.ArrayList<Gtk.Widget> ();
        private Gee.ArrayList<Gtk.CheckButton?> page_confirmations = new Gee.ArrayList<Gtk.CheckButton?> ();

        public SteamRepairGuideDialog (Gee.List<SteamRuntimeRepairCandidate> candidates) {
            var title_text = candidates.size == 1
                ? _ ("Fix “%s”").printf (candidates[0].display_title)
                : _ ("Fix broken Steam compatibility tools");
            Object (title: title_text);

            var header_bar = new Adw.HeaderBar () {
                title_widget = new Adw.WindowTitle (title_text, "")
            };

            foreach (var candidate in candidates)
                add_candidate_pages (candidate);

            car = new Adw.Carousel () { hexpand = true, vexpand = true };
            foreach (var page in pages)
                car.append (page);

            prev_button = new Gtk.Button.from_icon_name ("go-previous-symbolic") { valign = Gtk.Align.CENTER };
            prev_button.add_css_class ("circular");
            prev_button.set_tooltip_text (_ ("Previous Step"));
            prev_button.clicked.connect (on_prev_clicked);

            next_button = new Gtk.Button.from_icon_name ("go-next-symbolic") { valign = Gtk.Align.CENTER };
            next_button.add_css_class ("circular");
            next_button.set_tooltip_text (_ ("Next Step"));
            next_button.clicked.connect (on_next_clicked);

            var carousel_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) { hexpand = true, vexpand = true };
            carousel_row.append (prev_button);
            carousel_row.append (car);
            carousel_row.append (next_button);

            var dots = new Adw.CarouselIndicatorDots ();
            dots.set_carousel (car);
            dots.set_halign (Gtk.Align.CENTER);

            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                vexpand = true,
                margin_top = 6,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
            };
            content_box.append (carousel_row);
            content_box.append (dots);

            car.notify["position"].connect (update_buttons_visibility);
            foreach (var check in page_confirmations) {
                if (check != null)
                    check.notify["active"].connect (update_buttons_visibility);
            }

            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content_box);

            set_content_width (750);
            set_content_height (620);
            set_can_close (true);
            set_child (toolbar_view);

            update_buttons_visibility ();
        }

        // Depot and build IDs are looked up live on purpose: Valve changes
        // them between updates, so baking in a fixed pair here would go
        // stale and could point at content that no longer matches the app.
        private void add_candidate_pages (SteamRuntimeRepairCandidate candidate) {
            add_page (new StepPage (
                "“%s” (Steam app %u)".printf (candidate.display_title, candidate.appid),
                _ ("Steam’s own install record for this item reports a fully completed download with build ID 0 — a state a real install should never reach. Recovering it means running a few commands in Steam’s own console; ProtonPlus does not write any of these files for you.\n\nExpected install path:\n%s").printf (candidate.install_path),
                null, null, false
            ));

            var console_button = new Gtk.Button.with_label (_ ("Open Steam Console")) { halign = Gtk.Align.START };
            console_button.add_css_class ("suggested-action");
            console_button.clicked.connect (() => {
                Utils.System.open_uri ("steam://open/console");
            });
            add_page (new StepPage (
                _ ("Step 1 — Open Steam’s console"),
                _ ("Launch Steam with `steam -console`, or use the button below while Steam is already running."),
                null, console_button, true
            ));

            var depot_id_note = candidate.appid == 4183110
                ? _ ("\n\nReference: for Steam Linux Runtime 4.0, users have confirmed depot 4183111 and buildid 22818298 fixed this exact corruption. Confirm with app_info_print first — Valve updates these over time.")
                : "";
            add_page (new StepPage (
                _ ("Step 2 — Look up this app’s real depot and build IDs"),
                _ ("Do not reuse numbers you find elsewhere: Valve changes them between updates. Look under “depots” for the depot ID that belongs to this app, and under its “public” branch for the current “buildid”.%s").printf (depot_id_note),
                "app_info_print %u".printf (candidate.appid),
                null, true
            ));

            add_page (new StepPage (
                _ ("Step 3 — Download that depot directly"),
                _ ("This bypasses the broken update pipeline. Replace <depotid> with the value from the previous step."),
                "download_depot %u <depotid>".printf (candidate.appid),
                null, true
            ));

            add_page (new StepPage (
                _ ("Step 4 — Move the downloaded files into place"),
                _ ("Back up anything already at the destination first."),
                "mkdir -p \"%s\"\ncp -r ~/.local/share/Steam/ubuntu12_32/steamapps/content/app_%u/depot_<depotid>/* \"%s/\"".printf (
                    candidate.install_path, candidate.appid, candidate.install_path
                ),
                null, true
            ));

            add_page (new StepPage (
                _ ("Step 5 — Update Steam’s manifest"),
                _ ("`download_depot` does not update Steam’s own bookkeeping, so its manifest still needs to change by hand. Compute the real installed size below, then back up steamapps/appmanifest_%u.acf and edit its buildid and SizeOnDisk fields to the values from steps 2 and 5 — not copied numbers, since they change on every update.").printf (candidate.appid),
                "du -sb \"%s\"".printf (candidate.install_path),
                null, true
            ));

            add_page (new StepPage (
                _ ("Step 6 — Restart Steam and confirm the fix"),
                _ ("It should report a command prefix for this tool instead of “unsupported version 0”."),
                "grep %u ~/.local/share/Steam/logs/compat_log.txt | tail -5".printf (candidate.appid),
                null, true
            ));
        }

        private void add_page (StepPage page) {
            pages.add (page);
            page_confirmations.add (page.confirm_check);
        }

        private void on_prev_clicked () {
            uint current_page = (uint) Math.round (car.position);
            if (current_page > 0)
                car.scroll_to (pages.get ((int) current_page - 1), true);
        }

        private void on_next_clicked () {
            uint current_page = (uint) Math.round (car.position);
            if (current_page < pages.size - 1 && is_confirmed (current_page))
                car.scroll_to (pages.get ((int) current_page + 1), true);
        }

        private bool is_confirmed (uint page_index) {
            var check = page_confirmations.get ((int) page_index);
            return check == null || check.active;
        }

        private void update_buttons_visibility () {
            uint current_page = (uint) Math.round (car.position);
            bool can_go_previous = current_page > 0;
            bool has_next_page = current_page < pages.size - 1;

            prev_button.sensitive = can_go_previous;
            prev_button.set_opacity (can_go_previous ? 1.0 : 0.0);
            next_button.set_opacity (has_next_page ? 1.0 : 0.0);
            next_button.sensitive = has_next_page && is_confirmed (current_page);
        }
    }
}
