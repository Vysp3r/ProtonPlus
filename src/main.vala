namespace ProtonPlus {
	public static int main (string[] args) {
		if (!Thread.supported ()) {
			error ("Threads are not supported!");
			return -1;
		}

		Intl.setlocale ();
		Intl.bindtextdomain (Config.APP_ID, Environment.get_variable("LOCALE_DIR") ?? Config.LOCALE_DIR);
		Intl.bind_textdomain_codeset (Config.APP_ID, "UTF-8");
		Intl.textdomain (Config.APP_ID);

		var application = new Widgets.Application ();
		return application.run (args);
	}
}
