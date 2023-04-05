using Utils.Constants;

public class ProtonPlus : Adw.Application {
    static GLib.Once<ProtonPlus> _instance;

    public Windows.Main mainWindow;

    public static unowned ProtonPlus get_instance () {
        return _instance.once (() => { return new ProtonPlus (); });
    }

    ProtonPlus () {
        application_id = APP_ID;
        flags |= ApplicationFlags.FLAGS_NONE;

        Intl.bindtextdomain (APP_ID, LOCALE_DIR);
    }

    public static int main (string[] args) {
        if (Thread.supported () == false) {
            stderr.printf ("Threads are not supported!\n");
            return -1;
        }

        return get_instance ().run (args);
    }

    public override void activate () {
        //
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/com/vysp3r/ProtonPlus/application.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (),
                                                   provider,
                                                   Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        //
        mainWindow = new Windows.Main (this);

        //
        if (GLib.Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland") {
            mainWindow.fullscreen ();
        }

        //
        mainWindow.show ();
    }
}
