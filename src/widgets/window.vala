namespace ProtonPlus.Widgets {
    public class Window : Adw.ApplicationWindow {
        Header.Box header_box { get; set; }

        Loading.Box loading_box { get; set; }
        Main.Box main_box { get; set; }

        Adw.ToolbarView toolbar_view { get; set; }

        Utils.ControllerManager controller_manager;

        construct {
            set_application ((Adw.Application) GLib.Application.get_default ());
            set_title (Config.APP_NAME);

            header_box = new Header.Box ();
            header_box.launcher_selected.connect ((launcher) => {
                main_box.set_selected_launcher (launcher);
            });

            loading_box = new Loading.Box ();
            loading_box.loaded.connect ((launchers) => {
                header_box.initialize (launchers, main_box.view_switcher);

                toolbar_view.set_content (main_box);
            });

            main_box = new Main.Box ();

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_box);
            toolbar_view.set_content (loading_box);

            controller_manager = new Utils.ControllerManager (this, main_box.view_stack);
            controller_manager.start ();

            set_content (toolbar_view);

            loading_box.load.begin ();
        }

        public override bool close_request () {
            if (Utils.DownloadManager.instance.active_downloads.size == 0) {
                controller_manager.stop ();

                Utils.Filesystem.delete_directory.begin (Globals.CACHE_PATH);

                return false;
            }

            var dialog = new Adw.AlertDialog (_ ("Warning"), _ ("The application is currently checking for updates.\nExiting the application early may cause issues."));

            dialog.add_response ("exit", _ ("Exit"));
            dialog.set_response_appearance ("exit", Adw.ResponseAppearance.DESTRUCTIVE);

            dialog.add_response ("cancel", _ ("Cancel"));
            dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.SUGGESTED);

            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");

            dialog.response.connect ((response) => {
                if (response != "exit")
                return;

                controller_manager.stop ();

                Utils.Filesystem.delete_directory.begin (Globals.CACHE_PATH);

                application.quit ();
            });

            dialog.present (this);

            return true;
        }
    }
}