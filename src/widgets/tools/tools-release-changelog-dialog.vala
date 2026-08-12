namespace ProtonPlus.Widgets.Tools {
    public class ReleaseChangelogDialog : Adw.Dialog {
        public ReleaseChangelogDialog (Services.InstallJob job) {
            Object (title: _("Changelog for %s").printf (job.title));

            var window_title = new Adw.WindowTitle (
                _("Changelog"), ReleaseRow.release_display_title (job)
            );
            var header_bar = new Adw.HeaderBar ();
            header_bar.set_title_widget (window_title);

            Gtk.Widget content;
            if (job.release.description == null ||
                job.release.description.strip () == "") {
                content = new Adw.StatusPage () {
                    title = _("No Changelog Available"),
                    icon_name = "book-open-symbolic",
                    vexpand = true
                };
            } else {
                var changelog = new ReleaseChangelog ();
                changelog.set_markdown (job.release.description);
                content = changelog;
            }

            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content);

            set_content_width (720);
            set_content_height (600);
            set_can_close (true);
            set_child (toolbar_view);
        }
    }
}
