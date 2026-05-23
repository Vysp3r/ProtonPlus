namespace ProtonPlus.Widgets.Tools {
    public class ReleaseChangelog : Gtk.Box {
        private Gtk.Label label;

        public ReleaseChangelog () {
            Object (
                    orientation: Gtk.Orientation.VERTICAL,
                    vexpand: true
            );

            label = new Gtk.Label ("") {
                use_markup = true,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                selectable = true,
                xalign = 0,
                yalign = 0,
                margin_start = 12,
                margin_end = 12,
                margin_top = 12,
                margin_bottom = 12,
                halign = Gtk.Align.START,
                valign = Gtk.Align.START
            };

            var scrolled = new Gtk.ScrolledWindow () {
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = label
            };

            append (scrolled);
        }

        public void set_markdown (string? markdown) {
            if (markdown == null || markdown == "") {
                label.set_markup ("");
                return;
            }

            label.set_markup (markdown_to_markup (markdown));
        }

        private string markdown_to_markup (string markdown) {
            string text = Markup.escape_text (markdown);

            try {
            // Code blocks: ```code``` -> <tt>code</tt>
                var code_block = new Regex ("```(?:[a-zA-Z0-9]*\n)?([\\s\\S]*?)```", RegexCompileFlags.MULTILINE);
                text = code_block.replace (text, -1, 0, "<tt>\\1</tt>");

            // Inline code: `code` -> <tt>code</tt>
                var code = new Regex ("`(.*?)`", RegexCompileFlags.MULTILINE);
                text = code.replace (text, -1, 0, "<tt>\\1</tt>");

            // Headers: # Title -> <b><span size="x-large">Title</span></b>
                var header1 = new Regex ("^# (.*)$", RegexCompileFlags.MULTILINE);
                text = header1.replace (text, -1, 0, "\n<b><span size=\"x-large\">\\1</span></b>");

            // Headers: ## Title -> <b><span size="large">Title</span></b>
                var header2 = new Regex ("^## (.*)$", RegexCompileFlags.MULTILINE);
                text = header2.replace (text, -1, 0, "\n<b><span size=\"large\">\\1</span></b>");

            // Headers: ### Title -> <b>Title</b>
                var header3 = new Regex ("^### (.*)$", RegexCompileFlags.MULTILINE);
                text = header3.replace (text, -1, 0, "\n<b>\\1</b>");

            // Headers: #### Title -> <b>Title</b>
                var header4 = new Regex ("^#### (.*)$", RegexCompileFlags.MULTILINE);
                text = header4.replace (text, -1, 0, "\n<b>\\1</b>");

            // Headers: ##### Title -> <b>Title</b>
                var header5 = new Regex ("^##### (.*)$", RegexCompileFlags.MULTILINE);
                text = header5.replace (text, -1, 0, "\n<b>\\1</b>");

            // Headers: ###### Title -> <b>Title</b>
                var header6 = new Regex ("^###### (.*)$", RegexCompileFlags.MULTILINE);
                text = header6.replace (text, -1, 0, "\n<b>\\1</b>");

            // Bold: **text** -> <b>text</b>
                var bold_star = new Regex ("\\*\\*(.*?)\\*\\*");
                text = bold_star.replace (text, -1, 0, "<b>\\1</b>");
            // Bold: __text__ -> <b>text</b>
                var bold_under = new Regex ("__(.*?)__");
                text = bold_under.replace (text, -1, 0, "<b>\\1</b>");

            // Italic: *text* -> <i>text</i>
                var italic_star = new Regex ("\\*(.*?)\\*");
                text = italic_star.replace (text, -1, 0, "<i>\\1</i>");
            // Italic: _text_ -> <i>text</i>
                var italic_under = new Regex ("\\b_(.*?)_\\b");
                text = italic_under.replace (text, -1, 0, "<i>\\1</i>");

            // Strikethrough: ~~text~~ -> <s>text</s>
                var strike = new Regex ("~~(.*?)~~");
                text = strike.replace (text, -1, 0, "<s>\\1</s>");

            // Task lists: - [ ] item -> ☐ item
                var task_list_empty = new Regex ("^([ \t]*)[*+-] \\[[ ]\\] (.*)$", RegexCompileFlags.MULTILINE);
                text = task_list_empty.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string indent = match_info.fetch (1);
                    string content = match_info.fetch (2);
                    result.append (indent);
                    result.append (" ☐ ");
                    result.append (content);
                    return false;
                });

                var task_list_done = new Regex ("^([ \t]*)[*+-] \\[[xX]\\] (.*)$", RegexCompileFlags.MULTILINE);
                text = task_list_done.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string indent = match_info.fetch (1);
                    string content = match_info.fetch (2);
                    result.append (indent);
                    result.append (" ☑ ");
                    result.append (content);
                    return false;
                });

            // Lists: * item -> • item
                var list_item = new Regex ("^([ \t]*)[*+-] (.*)$", RegexCompileFlags.MULTILINE);
                text = list_item.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string indent = match_info.fetch (1);
                    string content = match_info.fetch (2);
                    string bullet = "•";

                    if (indent.length > 0) {
                        if (indent.length >= 6) {
                            bullet = "▫";
                        } else if (indent.length >= 4) {
                            bullet = "▪";
                        } else {
                            bullet = "◦";
                        }
                    }

                    result.append (indent);
                    result.append (" ");
                    result.append (bullet);
                    result.append (" ");
                    result.append (content);
                    return false;
                });

            // Ordered lists: 1. item -> 1. item
                var ordered_list = new Regex ("^([ \t]*)([0-9]+)\\. (.*)$", RegexCompileFlags.MULTILINE);
                text = ordered_list.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string indent = match_info.fetch (1);
                    string number = match_info.fetch (2);
                    string content = match_info.fetch (3);
                    result.append (indent);
                    result.append (" ");
                    result.append (number);
                    result.append (". ");
                    result.append (content);
                    return false;
                });

            // Alerts: > [!NOTE]
                var note_alert = new Regex ("^&gt; ?\\[!NOTE\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = note_alert.replace (text, -1, 0, "  <b><span color=\"#3584e4\">🗒️ Note</span></b>");

                var tip_alert = new Regex ("^&gt; ?\\[!TIP\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = tip_alert.replace (text, -1, 0, "  <b><span color=\"#2ec27e\">💡 Tip</span></b>");

                var important_alert = new Regex ("^&gt; ?\\[!IMPORTANT\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = important_alert.replace (text, -1, 0, "  <b><span color=\"#9141ac\">❗ Important</span></b>");

                var warning_alert = new Regex ("^&gt; ?\\[!WARNING\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = warning_alert.replace (text, -1, 0, "  <b><span color=\"#e5a50a\">⚠️ Warning</span></b>");

                var caution_alert = new Regex ("^&gt; ?\\[!CAUTION\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = caution_alert.replace (text, -1, 0, "  <b><span color=\"#e01b24\">🔴 Caution</span></b>");

            // Blockquotes: > text -> <i>  text</i>
                var blockquote = new Regex ("^&gt; ?(.*)$", RegexCompileFlags.MULTILINE);
                text = blockquote.replace (text, -1, 0, "  <i>\\1</i>");

            // Horizontal rules: --- -> ────────────────────────────────
                var hr = new Regex ("^([*_-]{3,})$", RegexCompileFlags.MULTILINE);
                text = hr.replace (text, -1, 0, "────────────────────────────────");

            // Images: ![alt](url) -> 🖼 <b>alt</b> (url)
                var images = new Regex ("""!\[(.*?)\]\(((?:https?://|www\.|magnet:)(?:[^()]*|\([^()]*\))*)\)""");
                text = images.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string alt = match_info.fetch (1);
                    string url = match_info.fetch (2);
                    string full_url = url.has_prefix ("www.") ? "https://" + url : url;
                    result.append_printf ("🖼 <b>%s</b> (<a href=\"%s\">%s</a>)", alt, full_url, full_url);
                    return false;
                });

            // Links: [text](url) -> <a href="url">text</a>
                var links = new Regex ("""\[(.*?)\]\(((?:https?://|www\.|magnet:)(?:[^()]*|\([^()]*\))*)\)""");
                text = links.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string text_match = match_info.fetch (1);
                    string url = match_info.fetch (2);
                    string full_url = url.has_prefix ("www.") ? "https://" + url : url;
                    result.append_printf ("<a href=\"%s\">%s</a>", full_url, text_match);
                    return false;
                });

            // Bare links: https://google.com -> <a href="https://google.com">https://google.com</a>
                var bare_links = new Regex ("""(?<!href=")(?<!">)(?<!=)((?:https?://|www\.|magnet:)[^\s<>"'()]+[^\s.,<>"'()!?;:])""");
                text = bare_links.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string url = match_info.fetch (1);
                    string full_url = url.has_prefix ("www.") ? "https://" + url : url;
                    result.append_printf ("<a href=\"%s\">%s</a>", full_url, url);
                    return false;
                });

            // Subscript and Superscript
                text = text.replace ("&lt;sub&gt;", "<sub>").replace ("&lt;/sub&gt;", "</sub>");
                text = text.replace ("&lt;sup&gt;", "<sup>").replace ("&lt;/sup&gt;", "</sup>");

            } catch (RegexError e) {
                warning (e.message);
            }

            return text.strip ();
        }
    }
}
