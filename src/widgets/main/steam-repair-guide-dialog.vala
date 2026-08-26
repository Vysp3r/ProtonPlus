namespace ProtonPlus.Widgets.Main {
    using ProtonPlus.Models;

    /* Presents the manual recovery steps for a Steam-reported "fully
     * installed, buildid 0" compatibility tool or runtime. ProtonPlus does
     * not perform any of these steps itself: they mutate Steam's own
     * download/depot state, which stays outside tool management here.
     *
     * The step-by-step block is deliberately not translated, the same way
     * ErrorDialog leaves its technical-details text untranslated: it is a
     * literal shell transcript, not UI copy. */
    public class SteamRepairGuideDialog : Adw.AlertDialog {
        public SteamRepairGuideDialog (Gee.List<SteamRuntimeRepairCandidate> candidates) {
            set_heading (candidates.size == 1
                ? _ ("Fix “%s”").printf (candidates[0].display_title)
                : _ ("Fix broken Steam compatibility tools"));
            set_body (_ ("Steam’s own install record for the item(s) below reports a fully completed download with build ID 0 — a state a real install should never reach. Recovering it means running a few commands in Steam’s own console; ProtonPlus does not write any of these files for you."));

            var text_view = new Gtk.TextView () {
                editable = false,
                cursor_visible = false,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                margin_top = 12,
                margin_bottom = 12,
                margin_start = 12,
                margin_end = 12,
            };
            text_view.add_css_class ("monospace");
            text_view.buffer.text = build_steps (candidates);

            var scrolled = new Gtk.ScrolledWindow () {
                min_content_height = 220,
                max_content_height = 420,
                vexpand = true,
                child = text_view,
            };
            scrolled.add_css_class ("card");

            set_extra_child (scrolled);

            add_response ("console", _ ("Open Steam Console"));
            add_response ("close", _ ("Close"));
            set_response_appearance ("console", Adw.ResponseAppearance.SUGGESTED);
            set_default_response ("close");
            set_close_response ("close");

            response.connect ((response_id) => {
                if (response_id == "console")
                    Utils.System.open_uri ("steam://open/console");
            });
        }

        private string build_steps (Gee.List<SteamRuntimeRepairCandidate> candidates) {
            var builder = new StringBuilder ();
            for (var index = 0; index < candidates.size; index++) {
                if (index > 0)
                    builder.append ("\n\n----------------------------------------\n\n");
                builder.append (build_steps_for (candidates[index]));
            }
            return builder.str;
        }

        // Depot and build IDs are looked up live on purpose: Valve changes
        // them between updates, so baking in a fixed pair here would go
        // stale and could point at content that no longer matches the app.
        private string build_steps_for (SteamRuntimeRepairCandidate candidate) {
            var builder = new StringBuilder ();
            builder.append_printf ("“%s” (Steam app %u)\n", candidate.display_title, candidate.appid);
            builder.append_printf ("Expected install path: %s\n\n", candidate.install_path);

            builder.append ("1. Open Steam's console: launch Steam with `steam -console`, or use the\n");
            builder.append ("   \"Open Steam Console\" button below while Steam is already running.\n\n");

            builder.append ("2. Ask Steam for this app's real depot and build IDs. Do not reuse numbers\n");
            builder.append ("   you find elsewhere - Valve changes them between updates:\n");
            builder.append_printf ("       app_info_print %u\n", candidate.appid);
            builder.append ("   Look under \"depots\" for the depot ID that belongs to this app, and under\n");
            builder.append ("   its \"public\" branch for the current \"buildid\".\n\n");

            builder.append ("3. Download that depot directly, bypassing the broken update pipeline:\n");
            builder.append_printf ("       download_depot %u <depotid>\n\n", candidate.appid);

            builder.append ("4. Move the downloaded files into place. Back up anything already at the\n");
            builder.append ("   destination first:\n");
            builder.append_printf ("       mkdir -p \"%s\"\n", candidate.install_path);
            builder.append_printf (
                "       cp -r ~/.local/share/Steam/ubuntu12_32/steamapps/content/app_%u/depot_<depotid>/* \"%s/\"\n\n",
                candidate.appid, candidate.install_path
            );

            builder.append ("5. `download_depot` does not update Steam's own bookkeeping, so its manifest\n");
            builder.append ("   still needs to change. Compute the real installed size first:\n");
            builder.append_printf ("       du -sb \"%s\"\n", candidate.install_path);
            builder.append_printf (
                "   Then back up steamapps/appmanifest_%u.acf and edit its buildid and\n" +
                "   SizeOnDisk fields to the values from steps 2 and 5 - not copied numbers,\n" +
                "   since they change on every update.\n\n",
                candidate.appid
            );

            builder.append ("6. Restart Steam and confirm the fix worked:\n");
            builder.append_printf ("       grep %u ~/.local/share/Steam/logs/compat_log.txt | tail -5\n", candidate.appid);
            builder.append ("   It should report a command prefix for this tool instead of\n");
            builder.append ("   \"unsupported version 0\".");

            if (candidate.appid == 4183110) {
                builder.append ("\n\nReference: for Steam Linux Runtime 4.0, users have confirmed depot\n");
                builder.append ("4183111 and buildid 22818298 fixed this exact corruption. Confirm with\n");
                builder.append ("app_info_print first - Valve updates these over time.");
            }

            return builder.str;
        }
    }
}
