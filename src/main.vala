namespace ProtonPlus {
	public static int main (string[] args) {
		if (!Thread.supported ()) {
			message ("Threads are not supported!");
			return -1;
		}

		Intl.setlocale ();
		Intl.bindtextdomain (Globals.APP_ID, Environment.get_variable("LOCALE_DIR") ?? Globals.LOCALE_DIR);
		Intl.bind_textdomain_codeset (Globals.APP_ID, "UTF-8");
		Intl.textdomain (Globals.APP_ID);

		var application = new Widgets.Application ();
		return application.run (args);
	}
}
