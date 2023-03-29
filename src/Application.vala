using Utils.Constants;

public class ProtonPlus : Adw.Application {
    static GLib.Once<ProtonPlus> _instance;

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
        Utils.Theme.Load ();

        //
        Utils.Theme.Apply ();

        //
        var window = new Windows.Main (this);

        //
        if (GLib.Environment.get_variable ("DESKTOP_SESSION") == "gamescope-wayland") {
            window.fullscreen ();
        }

        //
        window.show ();
    }
}
