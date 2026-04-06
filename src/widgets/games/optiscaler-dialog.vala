namespace ProtonPlus.Widgets {
    // Minimal Phase 1 OptiScaler dialog: install/remove + state display.
    public class OptiScalerDialog : Adw.Dialog {
        Models.Game game;
        Adw.WindowTitle window_title;
        Gtk.Button action_button;
        Adw.ComboRow injection_row;
        Gtk.Label detail_label;
        Gtk.Label status_label;
        Gtk.Label error_label;
        Gtk.Spinner spinner;
        Adw.SwitchRow spoof_row;
        Adw.SwitchRow override_row;
        Adw.SwitchRow preserve_ini_row;
        Adw.HeaderBar header_bar;
        Gtk.Box content_box;
        Adw.PreferencesGroup launch_options_group;
        Adw.ToolbarView toolbar_view;

        bool working;

        construct {
            window_title = new Adw.WindowTitle(_("Manage OptiScaler"), "");

            action_button = new Gtk.Button.with_label(_("Install"));
            action_button.set_tooltip_text(_("Apply the current modification"));
            action_button.clicked.connect(action_button_clicked);

            header_bar = new Adw.HeaderBar();
            header_bar.pack_start(action_button);
            header_bar.set_title_widget(window_title);

            injection_row = new Adw.ComboRow();
            injection_row.title = _("Injection DLL name");
            string[] injections = {"dxgi","winmm","d3d12","dbghelp","version","wininet","winhttp"};
            var model = new Gtk.StringList(null);
            foreach (var s in injections) model.append(s);
            injection_row.set_model(model);
            injection_row.selected = 0;

            spoof_row = new Adw.SwitchRow();
            spoof_row.title = _("Disable DLSS spoofing (set Dxgi=false)");
            spoof_row.active = false;

            override_row = new Adw.SwitchRow();
            override_row.title = _("Apply WINEDLLOVERRIDES automatically");
            override_row.active = true;

            preserve_ini_row = new Adw.SwitchRow();
            preserve_ini_row.title = _("Preserve existing OptiScaler.ini");
            preserve_ini_row.active = false;

            launch_options_group = new Adw.PreferencesGroup();
            launch_options_group.set_margin_start(10);
            launch_options_group.set_margin_end(10);
            launch_options_group.set_margin_top(10);
            launch_options_group.set_margin_bottom(10);
            launch_options_group.add(injection_row);
            launch_options_group.add(spoof_row);
            launch_options_group.add(override_row);
            launch_options_group.add(preserve_ini_row);

            status_label = new Gtk.Label("");

            detail_label = new Gtk.Label("");

            spinner = new Gtk.Spinner();
            spinner.set_spinning(false);

            error_label = new Gtk.Label("");
            error_label.add_css_class("error");

            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            content_box.append(status_label);
            content_box.append(detail_label);
            content_box.append(spinner);
            content_box.append(launch_options_group);

            toolbar_view = new Adw.ToolbarView();
            toolbar_view.add_top_bar(header_bar);
            toolbar_view.set_content(content_box);

            set_size_request(750, 0);
            set_child(toolbar_view);
        }

        public OptiScalerDialog(Models.Game game) {
            this.game = game;

            update_state();
        }

        private void update_state() {
            var state = Utils.OptiScalerManager.instance.detect(game);
            if (state.installed) {
                string ver = state.version != null ? state.version : _("unknown version");
                status_label.set_label(_("Status: Installed") + (state.injection_file != null ? " (" + state.injection_file + ")" : ""));
                var details = _("Version: ") + ver;
                if (state.exe_dir != null && state.exe_dir.length > 0) details += "\n" + _("Exe Dir: ") + state.exe_dir;
                if (state.conflict) details += "\n" + _("Warning: Hash mismatch (possible conflict)");
                detail_label.set_label(details);
                install_button.set_sensitive(false);
                remove_button.set_sensitive(true);
            } else {
                status_label.set_label(_("Status: Not Installed"));
                detail_label.set_label("");
                install_button.set_sensitive(true);
                remove_button.set_sensitive(false);
            }
            if (working) {
                action_button.set_sensitive(false);
            } else {
                close_button.set_sensitive(true);
            }
        }

        private void set_working(bool value) {
            working = value;
            if (value) {
                spinner.set_spinning(true);
            } else {
                spinner.set_spinning(false);
            }
            update_state();
        }

        private async void do_install() {
            var opts = new Utils.OptiScalerManager.InstallOptions();
            // Gather selections
            opts.injection_name = ((Gtk.StringList) injection_row.get_model()).get_string(injection_row.selected);
            opts.disable_spoofing = spoof_row.active;
            opts.apply_launch_override = override_row.active;
            opts.preserve_ini = preserve_ini_row.active;
            bool ok = yield Utils.OptiScalerManager.instance.install(game, opts);
            if (!ok) {
                var err = Utils.OptiScalerManager.instance.last_error;
                if (err != null && err.length > 0) error_label.set_label(err);
                //Application.window.add_toast(new Adw.Toast(_("OptiScaler installation failed")));
            } else {
                error_label.set_label("");
                //Application.window.add_toast(new Adw.Toast(_("OptiScaler installed")));
            }
            set_working(false);
            update_state();
        }

        private async void do_remove() {
            bool ok = yield Utils.OptiScalerManager.instance.remove(game);
            if (!ok) {
                //Application.window.add_toast(new Adw.Toast(_("OptiScaler removal failed")));
            } else {
                //Application.window.add_toast(new Adw.Toast(_("OptiScaler removed")));
            }
            set_working(false);
            update_state();
        }

        private void action_button_clicked() {
//            // Installed
//            if (working) return;
//            set_working(true);
//            do_install.begin();
//
//            // Not installed
//            if (working) return;
//            set_working(true);
//            do_remove.begin();
        }
    }
}