namespace ProtonPlus.Widgets {
    public class RunnerGroup : Adw.PreferencesGroup {
        List<Adw.PreferencesRow> rows;

        public Models.Group group;

        public RunnerGroup(Models.Group group) {
            this.group = group;

            set_title(group.title);
            set_description(group.description);

            load(false);
        }

        public void load(bool installed_only) {
            clear();

            if (installed_only)
                load_installed_only();
            else
                load_normal();
        }

        void load_normal() {
            foreach (var runner in group.runners) {
                var runner_row = new RunnerRow(runner);
                add(runner_row);
                rows.append(runner_row);
            }
        }

        void load_installed_only() {
            try {
                var directory_path = group.launcher.directory + group.directory;
                File directory = File.new_for_path(directory_path);
                FileEnumerator? enumerator = directory.enumerate_children("standard::*", FileQueryInfoFlags.NONE, null);

                if (enumerator != null) {
                    FileInfo? file_info;
                    while ((file_info = enumerator.next_file()) != null) {
                        if (file_info.get_file_type() != FileType.DIRECTORY)
                            continue;

                        var title = file_info.get_name();

                        if (title == "LegacyRuntime")
                            continue;

                        var runner = new Models.Runners.Proton_GE(group); // FIXME This should be replaced by it's own model instead of using Proton_GE
                        var release = new Models.Releases.Basic.simple(runner, title, directory_path + "/" + title);

                        var remove_button = new Gtk.Button.from_icon_name("trash-symbolic");
                        remove_button.set_tooltip_text(_("Delete %s").printf(release.title));
                        remove_button.add_css_class("flat");

                        var input_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 10);
                        input_box.set_valign(Gtk.Align.CENTER);
                        input_box.append(remove_button);

                        var row = new Adw.ActionRow();
                        row.set_title(release.title);
                        row.add_suffix(input_box);

                        remove_button.clicked.connect(() => {
                            var alert_dialog = new Adw.AlertDialog(_("Delete %s").printf(release.title), "%s\n\n%s".printf(_("You're about to remove %s from your system.").printf(release.title), _("Are you sure you want this?")));

                            alert_dialog.add_response("no", _("No"));
                            alert_dialog.add_response("yes", _("Yes"));

                            alert_dialog.set_response_appearance("no", Adw.ResponseAppearance.DEFAULT);
                            alert_dialog.set_response_appearance("yes", Adw.ResponseAppearance.DESTRUCTIVE);

                            alert_dialog.choose.begin(Application.window, null, (obj, res) => {
                                var response = alert_dialog.choose.end(res);

                                if (response != "yes")
                                    return;

                                var remove_dialog = new Dialogs.RemoveDialog(release);
                                remove_dialog.present(Application.window);

                                release.send_message.connect((message) => {
                                    switch (release.state) {
                                        case Models.Release.State.BUSY_INSTALLING :
                                            remove_dialog.add_text(message);
                                            break;
                                        case Models.Release.State.BUSY_REMOVING :
                                            remove_dialog.add_text(message);
                                            break;
                                        default:
                                            break;
                                    }
                                });

                                release.remove.begin(new Models.Parameters(), (obj, res) => {
                                    var success = release.remove.end(res);

                                    if (success)
                                        remove(row);

                                    remove_dialog.done(success);
                                });
                            });
                        });

                        add(row);
                        rows.append(row);
                    }
                }
            } catch (Error e) {
                message(e.message);
            }
        }

        void clear() {
            if (rows == null)return;

            foreach (var row in rows) {
                remove(row);
            }

            rows = new List<Adw.PreferencesRow> ();
        }
    }
}