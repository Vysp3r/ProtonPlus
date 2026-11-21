namespace ProtonPlus.Services {
    // Stage the portable payload from the upstream package and register it as
    // a Steam tool. The standard workflow owns promotion, updates and removal.
    internal class ProtonAutogenArchive : Object {
        private const string ENTRY_POINT = "proton-autogen-steam.py";

        internal static bool is_directory (string path) {
            Posix.Stat info;
            return Posix.lstat (path, out info) == 0 && Posix.S_ISDIR (info.st_mode);
        }

        private static bool is_regular (string path) {
            Posix.Stat info;
            return Posix.lstat (path, out info) == 0 && Posix.S_ISREG (info.st_mode);
        }

        internal static async ReturnCode prepare (InstallJob job, string path) {
            var tool_name = Path.get_basename (job.install_location);
            var result = ReturnCode.INVALID_DATA;
            string? filesystem_error = null;
            SourceFunc callback = prepare.callback;
            new Thread<void> ("stage-proton-autogen", () => {
                try {
                    var module = find_module (path);
                    if (module != null) {
                        var entry = File.new_for_path (Path.build_filename (path, ENTRY_POINT));
                        var script = resources_lookup_data (
                            "/com/vysp3r/ProtonPlus/" + ENTRY_POINT, ResourceLookupFlags.NONE
                        );
                        var manifest = "\"compatibilitytools\"\n{\n\t\"compat_tools\"\n\t{\n\t\t%s\n\t\t{\n" +
                            "\t\t\t\"install_path\" \".\"\n\t\t\t\"display_name\" %s\n" +
                            "\t\t\t\"from_oslist\" \"windows\"\n\t\t\t\"to_oslist\" \"linux\"\n\t\t}\n\t}\n}\n";
                        var quoted_name = Utils.VDF.VdfDocument.quote (tool_name);
                        var tool_manifest = "\"manifest\"\n{\n\t\"version\" \"2\"\n" +
                            "\t\"commandline\" \"/" + ENTRY_POINT + " %verb%\"\n" +
                            "\t\"require_tool_appid\" \"4183110\"\n\t\"compatmanager_layer_name\" \"proton\"\n}\n";
                        File.new_for_path ((!) module).move (
                            File.new_for_path (Path.build_filename (path, "proton_autogen")),
                            FileCopyFlags.NOFOLLOW_SYMLINKS
                        );
                        write_file (entry, script.get_data ());
                        entry.set_attribute_uint32 (FileAttribute.UNIX_MODE, 0755, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                        write_file (File.new_for_path (Path.build_filename (path, "toolmanifest.vdf")), tool_manifest.data);
                        write_file (File.new_for_path (Path.build_filename (path, "compatibilitytool.vdf")),
                            manifest.printf (quoted_name, quoted_name).data);
                        result = ReturnCode.RUNNER_INSTALLED;
                    }
                } catch (Error error) {
                    filesystem_error = error.message;
                    result = ReturnCode.FILESYSTEM_ERROR;
                }
                Idle.add ((owned) callback);
            });
            yield;

            if (result == ReturnCode.INVALID_DATA)
                job.error_message = _ ("The Proton-Autogen package is invalid or incomplete.");
            else if (filesystem_error != null) {
                warning ("Could not stage Proton-Autogen at %s: %s", path, (!) filesystem_error);
                job.error_message = _ ("Failed to prepare Proton-Autogen for Steam.");
            }
            return result;
        }

        private static string? find_module (string path) throws Error {
            var lib = Path.build_filename (path, "lib");
            if (!is_directory (lib))
                return null;

            var children = File.new_for_path (lib).enumerate_children (
                "standard::name,standard::type", FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );
            FileInfo? child;
            string? found = null;
            while ((child = children.next_file ()) != null) {
                if (child.get_file_type () != FileType.DIRECTORY || !child.get_name ().has_prefix ("python3."))
                    continue;
                var packages = Path.build_filename (lib, child.get_name (), "site-packages");
                var module = Path.build_filename (packages, "proton_autogen");
                if (!is_directory (packages) || !is_directory (module))
                    continue;
                if (found != null || !has_config_modules (module))
                    return null;
                found = module;
            }
            return found;
        }

        private static bool has_config_modules (string module) {
            var detection = Path.build_filename (module, "detection");
            var utils = Path.build_filename (module, "utils");
            return is_directory (detection) && is_directory (utils) &&
                is_regular (Path.build_filename (module, "__init__.py")) &&
                is_regular (Path.build_filename (module, "config.py")) &&
                is_regular (Path.build_filename (module, "loader.py")) &&
                is_regular (Path.build_filename (detection, "proton.py")) &&
                is_regular (Path.build_filename (utils, "logger.py"));
        }

        private static void write_file (File file, uint8[] bytes) throws Error {
            // Exclusive creation also rejects a packaged file or symlink at
            // any of the reserved registration paths.
            var stream = file.create (FileCreateFlags.NONE);
            size_t written;
            stream.write_all (bytes, out written);
            stream.close ();
        }
    }
}
