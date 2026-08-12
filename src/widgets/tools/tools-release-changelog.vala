namespace ProtonPlus.Widgets.Tools {
    public class ReleaseChangelog : Gtk.Box {
        private Gtk.Box content;

        public ReleaseChangelog () {
            Object (
                    orientation: Gtk.Orientation.VERTICAL,
                    vexpand: true
            );

            content = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                margin_start = 12,
                margin_end = 12,
                margin_top = 12,
                margin_bottom = 12,
                hexpand = true,
                halign = Gtk.Align.FILL,
                valign = Gtk.Align.START
            };

            var scrolled = new Gtk.ScrolledWindow () {
                vexpand = true,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = content
            };

            append (scrolled);
        }

        public void set_markdown (string? markdown) {
            while (content.get_first_child () != null) {
                content.remove (content.get_first_child ());
            }

            if (markdown == null || markdown == "") {
                return;
            }

            try {
                var details = new Regex ("<details([^>]*)>([\\s\\S]*?)</details\\s*>", RegexCompileFlags.CASELESS);
                MatchInfo match_info;
                details.match (markdown, 0, out match_info);

                var previous_end = 0;
                while (match_info.matches ()) {
                    int start;
                    int end;
                    match_info.fetch_pos (0, out start, out end);

                    append_markdown (markdown.substring (previous_end, start - previous_end));
                    append_details (match_info.fetch (1), match_info.fetch (2));
                    previous_end = end;
                    match_info.next ();
                }

                append_markdown (markdown.substring (previous_end));
            } catch (RegexError e) {
                warning (e.message);
                append_markdown (markdown);
            }
        }

        private Gtk.Label create_label (string markdown) {
            return new Gtk.Label ("") {
                use_markup = true,
                label = markdown_to_markup (markdown),
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                selectable = true,
                focusable = false,
                xalign = 0,
                yalign = 0,
                hexpand = true,
                halign = Gtk.Align.FILL,
                valign = Gtk.Align.START
            };
        }

        private void append_markdown (string markdown) {
            if (markdown.strip () != "") {
                content.append (create_label (markdown));
            }
        }

        private void append_details (string attributes, string details) {
            string summary = _ ("Details");
            string body = details;

            try {
                var summary_tag = new Regex ("^[\\t \\r\\n]*<summary(?:\\s[^>]*)?>([\\s\\S]*?)</summary\\s*>(?:\\r?\\n)?", RegexCompileFlags.CASELESS);
                MatchInfo match_info;
                if (summary_tag.match (details, 0, out match_info) && match_info.matches ()) {
                    int end;
                    match_info.fetch_pos (0, null, out end);
                    summary = match_info.fetch (1).strip ();
                    if (summary == "") {
                        summary = _ ("Details");
                    }
                    body = details.substring (end);
                }
            } catch (RegexError e) {
                warning (e.message);
            }

            var expander = new Gtk.Expander (null) {
                hexpand = true,
                expanded = has_open_attribute (attributes)
            };
            expander.set_label_widget (create_label (summary));

            if (body.strip () != "") {
                var body_label = create_label (body);
                body_label.margin_start = 12;
                body_label.margin_top = 6;
                expander.set_child (body_label);
            }

            content.append (expander);
        }

        private bool has_open_attribute (string attributes) {
            try {
                var open_attribute = new Regex ("(?:^|\\s)open(?:\\s|=|$)", RegexCompileFlags.CASELESS);
                return open_attribute.match (attributes);
            } catch (RegexError e) {
                warning (e.message);
                return false;
            }
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
                text = note_alert.replace (text, -1, 0, "  <b>🗒️ Note</b>");

                var tip_alert = new Regex ("^&gt; ?\\[!TIP\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = tip_alert.replace (text, -1, 0, "  <b>💡 Tip</b>");

                var important_alert = new Regex ("^&gt; ?\\[!IMPORTANT\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = important_alert.replace (text, -1, 0, "  <b>❗ Important</b>");

                var warning_alert = new Regex ("^&gt; ?\\[!WARNING\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = warning_alert.replace (text, -1, 0, "  <b>⚠️ Warning</b>");

                var caution_alert = new Regex ("^&gt; ?\\[!CAUTION\\]$", RegexCompileFlags.MULTILINE | RegexCompileFlags.CASELESS);
                text = caution_alert.replace (text, -1, 0, "  <b>🔴 Caution</b>");

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
                var bare_links = new Regex ("""(<a\b[^>]*>[\s\S]*?</a>)|(?<!href=")(?<!">)(?<!=)((?:https?://|www\.|magnet:)[^\s<>"'()]+[^\s.,<>"'()!?;:])""", RegexCompileFlags.CASELESS);
                text = bare_links.replace_eval (text, -1, 0, 0, (match_info, result) => {
                    string anchor = match_info.fetch (1);
                    if (anchor != null) {
                        result.append (anchor);
                        return false;
                    }

                    string url = match_info.fetch (2);
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
