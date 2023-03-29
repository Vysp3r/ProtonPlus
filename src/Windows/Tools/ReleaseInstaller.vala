namespace Windows.Tools {
    public class ReleaseInstaller : Gtk.Box {
        Gtk.Notebook notebook;
        Gtk.Button btnBack;
        Gtk.ProgressBar progressBar;
        Gtk.TextBuffer textBuffer;
        int lastPage;

        public ReleaseInstaller (Gtk.Notebook notebook, Gtk.Button btnBack) {
            //
            this.notebook = notebook;
            this.btnBack = btnBack;

            //
            set_orientation (Gtk.Orientation.VERTICAL);
            set_valign (Gtk.Align.CENTER);
            set_spacing (0);

            //
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 15);
            content.set_valign (Gtk.Align.CENTER);
            content.set_margin_bottom (15);
            content.set_margin_top (15);

            //
            progressBar = new Gtk.ProgressBar ();
            content.append (progressBar);

            //
            textBuffer = new Gtk.TextBuffer (new Gtk.TextTagTable ());

            //
            var textView = new Gtk.TextView ();
            textView.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
            textView.set_editable (false);
            textView.set_buffer (textBuffer);

            //
            var scrolledWindow = new Gtk.ScrolledWindow ();
            scrolledWindow.set_child (textView);
            scrolledWindow.set_min_content_height (200);
            content.append (scrolledWindow);

            //
            var button = new Gtk.Button.with_label ("Cancel");
            button.set_hexpand (true);
            button.clicked.connect (Cancel);
            content.append (button);

            //
            var clamp = new Adw.Clamp ();
            clamp.set_maximum_size (700);
            clamp.set_child (content);
            append (clamp);
        }

        void Cancel () {
            textBuffer.set_text ("");
            btnBack.set_sensitive (true);

            if (lastPage == 1) notebook.set_current_page (1);
            else notebook.set_current_page (0);
        }

        public void Download (int lastPage) {
            this.lastPage = lastPage;

            btnBack.set_sensitive (false);
            textBuffer.set_text ("Starting the download...\n");
        }

        void Extract () {
        }
    }
}
