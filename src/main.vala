int main (string[] args) {
    if (Thread.supported () == false) {
        stderr.printf ("Threads are not supported!\n");
        return -1;
    }

    foreach (var loc in Intl.get_language_names ()) {
        stderr.printf (loc + "\n");
    }

    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.GNOMELOCALEDIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    var app = new ProtonPlus.Application ();
    return app.run (args);
}
