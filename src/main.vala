namespace ProtonPlus {
    public static int main (string[] args) {
        if (!Thread.supported ()) {
            message ("Threads are not supported!");
            return -1;
        }

        Intl.bindtextdomain (Config.APP_ID, Config.LOCALE_DIR);
        Intl.bind_textdomain_codeset (Config.APP_ID, "UTF-8");
        Intl.textdomain (Config.APP_ID);

        var application = new Widgets.Application ();
        return application.run (args);
    }
}