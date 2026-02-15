namespace ProtonPlus {
	public static int main (string[] args) {
		if (!Thread.supported ()) {
			warning ("Threads are not supported!");
			return -1;
		}

		Intl.setlocale ();
		Intl.bindtextdomain (Config.APP_ID, Environment.get_variable("LOCALE_DIR") ?? Config.LOCALE_DIR);
		Intl.bind_textdomain_codeset (Config.APP_ID, "UTF-8");
		Intl.textdomain (Config.APP_ID);

		if (args.length > 1) {
			var cli = new CLI.Handler ();
			var loop = new MainLoop ();
			int result = 0;
			cli.run.begin (args, (obj, res) => {
				result = cli.run.end (res);
				loop.quit ();
			});
			loop.run ();
			return result;
		}

		var application = new Widgets.Application ();
		return application.run (args);
	}
}
