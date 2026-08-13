namespace ProtonPlus.Widgets.Games {
    public class ExtraButton : Object {
        public Gtk.MenuButton button { get; private set; }
        GameActionTarget target;
        GameActionAvailability? availability;
        Gtk.PopoverMenu actions_popover;
        Gtk.Button anticheat_button;
        Gtk.Label anticheat_button_label;
        SimpleAction custom_executable_action;
        SimpleAction open_install_directory_action;
        SimpleAction open_prefix_directory_action;
        SimpleAction open_protontricks_action;
        SimpleAction open_protondb_action;
        SimpleAction open_anticheat_action;
        ulong awacy_status_handler = 0;
        ulong awacy_lookup_complete_handler = 0;
        bool bound = false;

        public ExtraButton (GameActionTarget target) {
            this.target = target;
            button = new Gtk.MenuButton ();

            var action_group = new SimpleActionGroup ();
            custom_executable_action = create_action (
                action_group, "custom-executable", open_custom_executable
            );
            open_install_directory_action = create_action (
                action_group, "open-install-directory", open_install_directory
            );
            open_prefix_directory_action = create_action (
                action_group, "open-prefix-directory", open_prefix_directory
            );
            open_protontricks_action = create_action (
                action_group, "open-protontricks", open_protontricks
            );
            open_protondb_action = create_action (
                action_group, "open-protondb", open_protondb
            );
            open_anticheat_action = create_action (
                action_group, "open-anticheat", open_anticheat_from_popover
            );
            button.insert_action_group ("game", action_group);

            anticheat_button_label = new Gtk.Label (null) {
                hexpand = true,
                xalign = 0
            };
            anticheat_button = new Gtk.Button () {
                action_name = "game.open-anticheat",
                child = anticheat_button_label,
                has_frame = false,
                hexpand = true,
                tooltip_text = "AreWeAntiCheatYet"
            };
            anticheat_button.add_css_class ("flat");
            anticheat_button.add_css_class ("model");

            actions_popover = new Gtk.PopoverMenu.from_model (new Menu ());
            actions_popover.closed.connect (() => {
                if (bound && target.item != null && button.get_mapped () &&
                    button.is_sensitive ())
                    button.grab_focus ();
            });
            button.set_popover (actions_popover);
            Window.register_popover_for_controller (
                actions_popover, button
            );

            button.set_icon_name ("view-more-symbolic");
            button.set_tooltip_text (_("Game Actions"));
            button.set_has_frame (false);
            button.add_css_class ("flat");
            unbind ();
        }

        public void bind (GameListItem item) {
            disconnect_anticheat ();
            bound = true;
            var steam_game = item.game as Models.Games.Steam;
            if (steam_game != null) {
                awacy_status_handler = ((!) steam_game).notify["awacy-status"].connect (
                    refresh
                );
                awacy_lookup_complete_handler = ((!) steam_game).notify["awacy-lookup-complete"].connect (
                    refresh
                );
            }
            refresh ();
            button.update_property (
                Gtk.AccessibleProperty.LABEL,
                _("Actions for %s").printf (item.game.name),
                -1
            );
        }

        public void unbind () {
            bound = false;
            button.popdown ();
            disconnect_anticheat ();
            availability = null;
            button.set_sensitive (false);
            button.set_visible (false);
            if (anticheat_button.get_parent () != null)
                actions_popover.remove_child (anticheat_button);
            actions_popover.set_menu_model (new Menu ());
            button.reset_property (Gtk.AccessibleProperty.LABEL);
        }

        void refresh () {
            var item = target.item;
            if (item == null)
                return;
            var steam_game = ((!) item).game as Models.Games.Steam;
            availability = GameActionAvailability.evaluate (
                steam_game != null,
                ((!) item).is_non_steam,
                ((!) item).is_native,
                ((!) item).has_install_directory,
                ((!) item).has_prefix_directory,
                Globals.PROTONTRICKS_INSTALLED ||
                    Globals.PROTONTRICKS_FLATPAK_INSTALLED,
                steam_game?.awacy_status,
                steam_game?.awacy_name != null,
                steam_game?.awacy_lookup_complete ?? false
            );

            var current = (!) availability;
            custom_executable_action.set_enabled (
                current.enable_custom_executable
            );
            open_install_directory_action.set_enabled (
                current.show_install_directory
            );
            open_prefix_directory_action.set_enabled (current.show_prefix_directory);
            open_protontricks_action.set_enabled (current.show_protontricks);
            open_protondb_action.set_enabled (current.show_protondb);
            open_anticheat_action.set_enabled (current.enable_anticheat);

            var menu = new Menu ();
            if (current.show_custom_executable)
                menu.append (_("_Run Custom Executable…"), "game.custom-executable");
            if (current.show_install_directory)
                menu.append (_("Open _Game Folder"), "game.open-install-directory");
            if (current.show_prefix_directory)
                menu.append (_("Open _Prefix Folder"), "game.open-prefix-directory");
            if (current.show_protontricks)
                menu.append (_("Open in Proton_tricks"), "game.open-protontricks");
            if (current.show_protondb)
                menu.append (_("Open Proton_DB"), "game.open-protondb");
            if (current.show_anticheat) {
                var anticheat_item = new MenuItem (null, null);
                anticheat_item.set_attribute ("custom", "s", "anticheat");
                menu.append_item (anticheat_item);
                anticheat_button_label.set_label (
                    anticheat_label (current.anticheat_state)
                );
                anticheat_button.set_sensitive (current.enable_anticheat);
            }
            if (anticheat_button.get_parent () != null)
                actions_popover.remove_child (anticheat_button);
            actions_popover.set_menu_model (menu);
            if (current.show_anticheat)
                actions_popover.add_child (anticheat_button, "anticheat");
            button.set_sensitive (current.has_secondary_actions);
            button.set_visible (current.has_secondary_actions);
        }

        static SimpleAction create_action (SimpleActionGroup group, string name,
            owned ActionCallback callback) {
            var action = new SimpleAction (name, null);
            action.activate.connect ((parameter) => callback ());
            group.add_action (action);
            return action;
        }

        delegate void ActionCallback ();

        string anticheat_label (GameAntiCheatState state) {
            string status;
            switch (state) {
            case GameAntiCheatState.SUPPORTED:
                status = _("Supported");
                break;
            case GameAntiCheatState.RUNNING:
                status = _("Running");
                break;
            case GameAntiCheatState.PLANNED:
                status = _("Planned");
                break;
            case GameAntiCheatState.BROKEN:
                status = _("Broken");
                break;
            case GameAntiCheatState.DENIED:
                status = _("Denied");
                break;
            case GameAntiCheatState.LOADING:
                status = _("Loading…");
                break;
            default:
                status = _("Unknown");
                break;
            }
            return _("Anti-Cheat: %s").printf (status);
        }

        void open_custom_executable () {
            var expected = target.item;
            if (expected == null)
                return;
            var root = button.get_root () as Gtk.Window;
            if (root == null)
                return;

            var file_dialog = new Gtk.FileDialog () {
                title = _("Select executable")
            };
            var filters = new ListStore (typeof (Gtk.FileFilter));
            var filter = new Gtk.FileFilter () {
                name = _("Executables (*.exe, *.msi, *.msu, *.bat)")
            };
            filter.add_pattern ("*.exe");
            filter.add_pattern ("*.msi");
            filter.add_pattern ("*.msu");
            filter.add_pattern ("*.bat");
            filters.append (filter);
            file_dialog.set_filters (filters);

            file_dialog.open.begin ((!) root, null, (object, result) => {
                try {
                    var file = file_dialog.open.end (result);
                    var path = file?.get_path ();
                    if (path != null)
                        run_custom_executable ((!) expected, (!) path, (!) root);
                } catch (Error error) {
                    warning (error.message);
                }
            });
        }

        static void run_custom_executable (GameListItem expected, string exe_path,
            Gtk.Window root) {
            var game = expected.game;
            var steam = game.launcher as Models.Launchers.Steam;
            var proton_path = steam?.resolve_effective_proton_executable (
                game.compatibility_tool
            );
            if (proton_path == null) {
                present_error_dialog (root, new Main.ErrorDialog (
                    _("Compatibility Tool Not Found"),
                    _("The compatibility tool required for %s is missing from your system. Please ensure it is correctly installed.").printf (game.name), // vala-lint=line-length
                    ""
                ));
                return;
            }

            var inner_command = "STEAM_COMPAT_DATA_PATH=%s STEAM_COMPAT_CLIENT_INSTALL_PATH=%s %s run %s".printf (
                Shell.quote (game.prefixdir), Shell.quote (game.launcher.directory),
                Shell.quote ((!) proton_path), Shell.quote (exe_path)
            );
            Utils.System.run_command.begin ("sh -c " + Shell.quote (inner_command),
                (object, result) => {
                    var command_result = Utils.System.run_command.end (result);
                    if (command_result.exit_status == 0)
                        return;
                    var diagnostic = command_result.stderr.strip ();
                    if (diagnostic == "")
                        diagnostic = command_result.stdout.strip ();
                    var details = _("Exit status: %d").printf (
                        command_result.exit_status
                    );
                    if (diagnostic != "")
                        details = "%s\n\n%s".printf (details, diagnostic);
                    present_error_dialog (root, new Main.ErrorDialog (
                        _("Custom Executable Failed"),
                        _("The custom executable for %s could not be launched.").printf (game.name),
                        details
                    ));
                });
        }

        static void present_error_dialog (Gtk.Window root, Adw.AlertDialog dialog) {
            if (root.get_root () == null)
                return;
            Window.present_dialog_for_controller (dialog, root);
        }

        void open_install_directory () {
            var item = target.item;
            if (item != null && ((!) item).has_install_directory)
                Utils.System.open_path (((!) item).game.installdir);
        }

        void open_prefix_directory () {
            var item = target.item;
            if (item != null && ((!) item).has_prefix_directory)
                Utils.System.open_path (((!) item).game.prefixdir);
        }

        void open_protontricks () {
            var steam_game = target.item?.game as Models.Games.Steam;
            if (steam_game == null || ((!) steam_game).is_non_steam)
                return;
            if (Globals.PROTONTRICKS_INSTALLED) {
                Utils.System.run_command.begin (
                    "protontricks %u --gui".printf (((!) steam_game).appid)
                );
            } else if (Globals.PROTONTRICKS_FLATPAK_INSTALLED) {
                Utils.System.run_command.begin (
                    "flatpak run com.github.Matoking.protontricks %u --gui".printf (
                        ((!) steam_game).appid
                    )
                );
            }
        }

        void open_protondb () {
            var steam_game = target.item?.game as Models.Games.Steam;
            if (steam_game != null && !((!) steam_game).is_non_steam) {
                Utils.System.open_uri (
                    "https://www.protondb.com/app/%u".printf (((!) steam_game).appid)
                );
            }
        }

        void open_anticheat () {
            var steam_game = target.item?.game as Models.Games.Steam;
            if (steam_game != null && ((!) steam_game).awacy_name != null) {
                Utils.System.open_uri (
                    "https://areweanticheatyet.com/game/%s".printf (
                        ((!) steam_game).awacy_name
                    )
                );
            }
        }

        void open_anticheat_from_popover () {
            actions_popover.popdown ();
            open_anticheat ();
        }

        void disconnect_anticheat () {
            var game = target.item?.game;
            if (awacy_status_handler != 0 && game != null) {
                ((!) game).disconnect (awacy_status_handler);
                awacy_status_handler = 0;
            }
            if (awacy_lookup_complete_handler != 0 && game != null) {
                ((!) game).disconnect (awacy_lookup_complete_handler);
                awacy_lookup_complete_handler = 0;
            }
        }

        public override void dispose () {
            unbind ();
            base.dispose ();
        }
    }
}
