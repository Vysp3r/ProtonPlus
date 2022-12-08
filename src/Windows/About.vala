namespace ProtonPlus.Windows {
    public class AboutTool : Gtk.Dialog {
        public AboutTool (Gtk.ApplicationWindow parent, string name, string directory) {
            set_title (_ ("About"));
            set_default_size (500, 0);
            set_transient_for (parent);

            var display = Gdk.Display.get_default ();
            var clipboard = display.get_clipboard ();

            // Setup boxMain
            var boxMain = this.get_content_area ();
            boxMain.set_orientation (Gtk.Orientation.VERTICAL);
            boxMain.set_margin_bottom (15);
            boxMain.set_margin_end (15);
            boxMain.set_margin_start (15);
            boxMain.set_margin_top (15);

            // Setup btnCopyTool
            var btnCopyTool = new Gtk.Button ();
            btnCopyTool.add_css_class ("flat");
            btnCopyTool.set_icon_name ("edit-copy-symbolic");

            // Setup rowTool
            var rowTool = new Adw.EntryRow ();
            rowTool.set_title (_ ("Name: "));
            rowTool.set_text (name);
            rowTool.add_suffix (btnCopyTool);
            rowTool.set_editable (false);

            btnCopyTool.clicked.connect (() => clipboard.set_text (rowTool.get_text ()));

            // Setup btnCopyLauncher
            var btnCopyDirectory = new Gtk.Button ();
            btnCopyDirectory.add_css_class ("flat");
            btnCopyDirectory.set_icon_name ("edit-copy-symbolic");

            // Setup rowDirectory
            var rowDirectory = new Adw.EntryRow ();
            rowDirectory.set_title (_ ("Directory: "));
            rowDirectory.set_text (directory);
            rowDirectory.add_suffix (btnCopyDirectory);
            rowDirectory.set_editable (false);

            btnCopyDirectory.clicked.connect (() => clipboard.set_text (rowDirectory.get_text ()));

            // Setup groupMain
            var groupMain = new Adw.PreferencesGroup ();
            groupMain.add (rowTool);
            groupMain.add (rowDirectory);
            boxMain.append (groupMain);

            // Show the window
            show ();
        }
    }
}
