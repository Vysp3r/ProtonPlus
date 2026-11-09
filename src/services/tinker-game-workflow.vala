namespace ProtonPlus.Services {
    // Registration lives inside the staged runtime. Promotion, backup and
    // registration rollback are therefore the same atomic directory transaction.
    public class TinkerGameWorkflow : StandardArchiveWorkflow {
        public override ReturnCode validate_install (InstallJob job, bool replace_existing) {
            if (job.tinker_game_context == null)
                return ReturnCode.INVALID_CONFIGURATION;
            if (Globals.IS_STEAM_OS || Globals.IS_FLATPAK ||
                job.tool.group.launcher.installation_type != Models.Launcher.InstallationTypes.SYSTEM) {
                job.error_message = _("TinkerGame currently requires native Steam and native ProtonPlus outside SteamOS.");
                return ReturnCode.UNSUPPORTED_OPERATION;
            }
            if (exists (job.install_location) && !is_owned (job)) {
                job.error_message = _("This TinkerGame installation is not managed by ProtonPlus.");
                return ReturnCode.INVALID_CONFIGURATION;
            }
            return base.validate_install (job, replace_existing);
        }

        internal static bool exists (string path) {
            return FileUtils.test (path, FileTest.EXISTS) || FileUtils.test (path, FileTest.IS_SYMLINK);
        }

        private bool is_owned (InstallJob job) {
            if (FileUtils.test (job.install_location, FileTest.IS_SYMLINK) ||
                FileUtils.test (Path.build_filename (job.install_location, ".protonplus"), FileTest.IS_SYMLINK))
                return false;
            var metadata = Utils.Metadata.load (job.install_location);
            return metadata.tool_id == job.tool.id && metadata.provider_id == "tinkergame";
        }

        public static bool yad_version_supported (string output) {
            var status = SteamTinkerLaunchYadCompatibility.classify_version_output (output);
            return status == SteamTinkerLaunchYadCompatibility.Status.SUPPORTED ||
                status == SteamTinkerLaunchYadCompatibility.Status.INCOMPATIBLE_15;
        }

        protected virtual async string missing_dependencies () {
            var missing = new Gee.ArrayList<string> ();
            // checkIntDeps at the reviewed revision requires xdotool despite
            // README describing it as optional. jq is needed by data readers.
            string[] dependencies = { "bash", "git", "pgrep", "pidof", "pkill", "tar", "unzip",
                "wget", "xdotool", "xprop", "xrandr", "xwininfo", "xxd", "jq", "steam" };
            foreach (var dependency in dependencies)
                if (!yield Utils.System.check_dependency (dependency))
                    missing.add (dependency);
            if (!yield Utils.System.check_dependency ("awk"))
                missing.add ("awk");
            if (!yield Utils.System.check_dependency ("yad"))
                missing.add ("yad >= 7.2");
            else {
                var version = yield Utils.System.run_command ("yad --version");
                if (!yad_version_supported (version.stdout))
                    missing.add ("yad >= 7.2");
            }
            return string.joinv (", ", missing.to_array ());
        }

        public override async ReturnCode install (InstallJob job, bool replace_existing) {
            var validation = validate_install (job, replace_existing);
            if (validation != ReturnCode.RUNNER_INSTALLED)
                return validation;
            var missing = yield missing_dependencies ();
            if (missing != "") {
                job.error_message = _("Missing TinkerGame dependencies:\n%s").printf (missing);
                return ReturnCode.INVALID_CONFIGURATION;
            }
            if (job.canceled)
                return ReturnCode.EXTRACTION_FAILED;
            var result = yield base.install (job, replace_existing);
            if (result == ReturnCode.RUNNER_INSTALLED && job.replacement_backup_path != null) {
                var backup = (!) job.replacement_backup_path;
                if (!yield Utils.Filesystem.delete_directory (backup))
                    warning ("Retained TinkerGame backup: %s", backup);
                job.replacement_backup_path = null;
            }
            return result;
        }

        protected override async ReturnCode prepare_staged_installation (InstallJob job, string path) {
            string[] generated = { "compatibilitytool.vdf", "toolmanifest.vdf", ".protonplus" };
            foreach (var name in generated)
                if (exists (Path.build_filename (path, name)))
                    return ReturnCode.INVALID_DATA;
            if (!yield validate_runtime_async (path)) {
                job.error_message = _("The TinkerGame archive is invalid or incomplete.");
                return ReturnCode.INVALID_DATA;
            }
            // Bind data resolution to this runtime even if a system-wide copy
            // exists. This exact assignment is verified against the reviewed upstream source.
            var paths = Path.build_filename (path, "lib", "core", "paths.sh");
            var content = Utils.Filesystem.get_file_content (paths);
            var original = "SYSTEMSTLCFGDIR=\"$PREFIX/share/${PROGNAME,,}\"";
            if (!content.contains (original) || !Utils.Filesystem.modify_file (
                    paths, content.replace (original, "SYSTEMSTLCFGDIR=\"$TG_LIBDIR/..\"")))
                return ReturnCode.INVALID_DATA;
            var executable = File.new_for_path (Path.build_filename (path, "tinkergame"));
            try {
                FileInfo applied;
                yield executable.set_attributes_async (executable_mode (), FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    Priority.DEFAULT, job.get_cancellable (), out applied);
            } catch (Error e) {
                job.error_message = e.message;
                return ReturnCode.FILESYSTEM_ERROR;
            }
            if (!yield write_registration (path))
                return ReturnCode.FILESYSTEM_ERROR;
            return ReturnCode.RUNNER_INSTALLED;
        }

        private FileInfo executable_mode () {
            var info = new FileInfo ();
            info.set_attribute_uint32 (FileAttribute.UNIX_MODE, 0755);
            return info;
        }

        protected virtual async bool write_registration (string path) {
            return Utils.Filesystem.modify_file (Path.build_filename (path, "compatibilitytool.vdf"),
                "\"compatibilitytools\" { \"compat_tools\" { \"Proton-tg\" { \"install_path\" \".\" \"display_name\" \"TinkerGame\" \"from_oslist\" \"windows\" \"to_oslist\" \"linux\" } } }\n") &&
                Utils.Filesystem.modify_file (Path.build_filename (path, "toolmanifest.vdf"),
                "\"manifest\" { \"commandline\" \"/tinkergame run\" \"commandline_waitforexitandrun\" \"/tinkergame waitforexitandrun\" }\n");
        }

        internal static async bool validate_runtime_async (string path, bool registered = false) {
            SourceFunc callback = validate_runtime_async.callback;
            var valid = false;
            new Thread<void> ("validate-tinkergame", () => {
                valid = validate_runtime (path) && (!registered || valid_registration (path));
                Idle.add ((owned) callback);
            });
            yield;
            return valid;
        }

        private static bool valid_registration (string path) {
            var tool = Utils.VDF.CompatibilityToolLoader.try_from_paths (path, path);
            if (tool == null || tool.internal_title != "Proton-tg")
                return false;
            var manifest_path = Path.build_filename (path, "toolmanifest.vdf");
            if (FileUtils.test (manifest_path, FileTest.IS_SYMLINK) ||
                !FileUtils.test (manifest_path, FileTest.IS_REGULAR))
                return false;
            var document = Utils.VDF.VdfParser.parse_document (Utils.Filesystem.get_file_content (manifest_path));
            if (document == null)
                return false;
            var manifest = document.root.get_child ("manifest");
            return manifest != null && manifest.get_child ("commandline")?.value == "/tinkergame run" &&
                manifest.get_child ("commandline_waitforexitandrun")?.value == "/tinkergame waitforexitandrun";
        }

        private static bool validate_runtime (string path) {
            foreach (var relative in required_files ()) {
                var current = path;
                foreach (var component in relative.split ("/")) {
                    current = Path.build_filename (current, component);
                    if (FileUtils.test (current, FileTest.IS_SYMLINK))
                        return false;
                }
                if (!FileUtils.test (current, FileTest.IS_REGULAR))
                    return false;
            }
            string[] directories = { "collections", "data", "eval", "guicfgs", "lang", "misc" };
            foreach (var directory in directories) {
                var entry = Path.build_filename (path, directory);
                if (FileUtils.test (entry, FileTest.IS_SYMLINK) || !FileUtils.test (entry, FileTest.IS_DIR))
                    return false;
            }
            return true;
        }

        protected override bool persist_runner_install_metadata (InstallJob job, string path) {
            var metadata = new Utils.Metadata ();
            metadata.provider_id = job.tool.provider_id;
            metadata.tool_id = job.tool.id;
            metadata.launcher_id = job.tool.group.launcher.tool_target_id;
            metadata.runner_title = job.tool.title;
            metadata.tag = job.release.source_tag;
            metadata.release_id = job.release.upstream_release_id;
            return metadata.save (path);
        }

        public override void refresh_state (InstallJob job) {
            job.step = InstallJob.Step.NOTHING;
            job.state = !is_owned (job) ? InstallJob.State.NOT_INSTALLED
                : Utils.Metadata.load (job.install_location).release_id == job.release.upstream_release_id &&
                    FileUtils.test (Path.build_filename (job.install_location, "tinkergame"), FileTest.IS_EXECUTABLE)
                ? InstallJob.State.UP_TO_DATE : InstallJob.State.UPDATE_AVAILABLE;
        }

        private async Models.ReleaseLookupResult lookup_latest (InstallJob job) {
            if (job.tool.release_catalog == null)
                return Models.ReleaseLookupResult.failure (ReturnCode.INVALID_CONFIGURATION);
            return yield job.tool.release_catalog.fetch_latest_eligible_release ();
        }

        public override async ReturnCode update (InstallJob job, InstallationOperationCoordinator coordinator) {
            var lookup = yield lookup_latest (job);
            if (!lookup.succeeded)
                return lookup.code;
            if (!lookup.has_release)
                return ReturnCode.NOTHING_TO_UPDATE;
            if (job.canceled)
                return ReturnCode.EXTRACTION_FAILED;
            job.set_release_for_update (lookup.require_release ());
            refresh_state (job);
            if (job.state == InstallJob.State.NOT_INSTALLED)
                return ReturnCode.RUNNER_NOT_INSTALLED;
            if (job.state == InstallJob.State.UP_TO_DATE) {
                var healthy = yield validate_runtime_async (job.install_location, true);
                refresh_state (job);
                if (job.state == InstallJob.State.NOT_INSTALLED)
                    return ReturnCode.RUNNER_NOT_INSTALLED;
                if (job.state == InstallJob.State.UP_TO_DATE && healthy)
                    return ReturnCode.NOTHING_TO_UPDATE;
            }
            job.state = InstallJob.State.BUSY_UPDATING;
            var result = yield coordinator.install_for_update (job);
            job.finish_operation ();
            if (result != ReturnCode.RUNNER_INSTALLED)
                return result;
            var recorder = coordinator as InstallationLifecycleRecorder;
            if (recorder != null)
                recorder.record_completed_update (job);
            return ReturnCode.RUNNER_UPDATED;
        }

        public override async ReturnCode remove (InstallJob job) {
            if (!is_owned (job))
                return ReturnCode.INVALID_CONFIGURATION;
            // Configuration and downloaded tools belong to the user, outside
            // this directory, and are always retained.
            var guard = yield InstallationService.instance.check_final_process_state (
                job, CompatibilityProcessOperationKind.REMOVAL, true);
            if (guard != ReturnCode.RUNNER_INSTALLED)
                return guard;
            if (!is_owned (job))
                return ReturnCode.INVALID_CONFIGURATION;
            job.step = InstallJob.Step.REMOVING;
            return (yield Utils.Filesystem.delete_directory (job.install_location))
                ? ReturnCode.RUNNER_REMOVED : ReturnCode.FILESYSTEM_ERROR;
        }

        internal static string[] required_files () {
            return { "tinkergame",
                "lib/cli/compat.sh",
                "lib/cli/dispatch.sh",
                "lib/cli/help.sh",
                "lib/cli/registry.sh",
                "lib/config/defaults.sh",
                "lib/config/load.sh",
                "lib/config/manage.sh",
                "lib/config/migrate.sh",
                "lib/config/save.sh",
                "lib/config/schema.sh",
                "lib/core/bootstrap.sh",
                "lib/core/cleanup.sh",
                "lib/core/common.sh",
                "lib/core/deps.sh",
                "lib/core/i18n.sh",
                "lib/core/log.sh",
                "lib/core/notify.sh",
                "lib/core/paths.sh",
                "lib/core/update.sh",
                "lib/core/util.sh",
                "lib/core/vdf.sh",
                "lib/deck/deck.sh",
                "lib/gui/dialogs.sh",
                "lib/gui/geometry.sh",
                "lib/gui/menu-core.sh",
                "lib/gui/menus.sh",
                "lib/gui/prepare.sh",
                "lib/gui/search.sh",
                "lib/gui/settings-entries.sh",
                "lib/gui/settings.sh",
                "lib/gui/tabs.sh",
                "lib/launch/args.sh",
                "lib/launch/custom.sh",
                "lib/launch/exec.sh",
                "lib/launch/firstinstall.sh",
                "lib/launch/gamescope.sh",
                "lib/launch/pipeline.sh",
                "lib/launch/postrun.sh",
                "lib/launch/prefix.sh",
                "lib/launch/proton-vars.sh",
                "lib/launch/proton.sh",
                "lib/launch/reshade.sh",
                "lib/launch/specialk.sh",
                "lib/launch/start.sh",
                "lib/launch/vr.sh",
                "lib/mods/hmm.sh",
                "lib/mods/mo2.sh",
                "lib/mods/vortex.sh",
                "lib/steam/config-vdf.sh",
                "lib/steam/libraries.sh",
                "lib/steam/nonsteam.sh",
                "lib/steam/sgdbnames.sh",
                "lib/tools/debug.sh",
                "lib/tools/deps.sh",
                "lib/tools/download.sh",
                "lib/tools/watch.sh",
                "data/commands.def",
                "data/options.def",
                "collections/Backup.conf",
                "collections/BlockInternet.conf",
                "collections/Conty.conf",
                "collections/DLSS.conf",
                "collections/DOSBox.conf",
                "collections/DelCompat.conf",
                "collections/Dependencies.conf",
                "collections/FSR.conf",
                "collections/FWS.conf",
                "collections/GDB.conf",
                "collections/Geo11-VR.conf",
                "collections/Geo11.conf",
                "collections/Luxtorpeda.conf",
                "collections/MO2.conf",
                "collections/MangoApp.conf",
                "collections/MangoHud.conf",
                "collections/MangoHudCfg.conf",
                "collections/OpenVR-FSR.conf",
                "collections/PEV.conf",
                "collections/PrimeRun.conf",
                "collections/Raytracing.conf",
                "collections/ReShade.conf",
                "collections/ReShadeSBS.conf",
                "collections/ReShadeVR.conf",
                "collections/Regedit.conf",
                "collections/SBS-VR.conf",
                "collections/SBS.conf",
                "collections/ScummVM.conf",
                "collections/SortGameArgs.conf",
                "collections/SpecialK.conf",
                "collections/Vortex.conf",
                "collections/Wine.conf",
                "collections/Wineconsole.conf",
                "collections/Zink.conf",
                "collections/x64dbg.conf",
                "eval/order.txt",
                "eval/packages/directx2010",
                "eval/packages/dotnet35",
                "eval/packages/dotnet40",
                "eval/packages/dotnet40-client-profile",
                "eval/packages/dotnet452",
                "eval/packages/dotnet46",
                "eval/packages/dotnet472",
                "eval/packages/dotnet48",
                "eval/packages/openal",
                "eval/packages/physx-9.12",
                "eval/packages/physx-9.14",
                "eval/packages/vcredist2005",
                "eval/packages/vcredist2008",
                "eval/packages/vcredist2010",
                "eval/packages/vcredist2012",
                "eval/packages/vcredist2013",
                "eval/packages/vcredist2015",
                "eval/packages/vcredist2017",
                "eval/packages/vcredist2019",
                "eval/packages/vcredist2022",
                "eval/packages/xna40",
                "eval/sets/evaluatorscript_depressurizer.vdf",
                "guicfgs/1920x1080/template/TinkerGame-AddVortexStage.conf",
                "guicfgs/1920x1080/template/TinkerGame-Ask_Recreate_Compatdata.conf",
                "guicfgs/1920x1080/template/TinkerGame-CategorySelection.conf",
                "guicfgs/1920x1080/template/TinkerGame-CreateCustomEvaluatorScript.conf",
                "guicfgs/1920x1080/template/TinkerGame-DXVK-Hud-Options.conf",
                "guicfgs/1920x1080/template/TinkerGame-DownloadCustomProton.conf",
                "guicfgs/1920x1080/template/TinkerGame-DownloadWine.conf",
                "guicfgs/1920x1080/template/TinkerGame-Editor.conf",
                "guicfgs/1920x1080/template/TinkerGame-EntryBlockSelection.conf",
                "guicfgs/1920x1080/template/TinkerGame-Favorites.conf",
                "guicfgs/1920x1080/template/TinkerGame-FavoritesSelection.conf",
                "guicfgs/1920x1080/template/TinkerGame-FetchSteamGridDBArtwork.conf",
                "guicfgs/1920x1080/template/TinkerGame-GameScopeGui.conf",
                "guicfgs/1920x1080/template/TinkerGame-Gui.conf",
                "guicfgs/1920x1080/template/TinkerGame-HMM.conf",
                "guicfgs/1920x1080/template/TinkerGame-HelpUrlMenu.conf",
                "guicfgs/1920x1080/template/TinkerGame-MainMenu.conf",
                "guicfgs/1920x1080/template/TinkerGame-Misc.conf",
                "guicfgs/1920x1080/template/TinkerGame-OneTimeRunGui.conf",
                "guicfgs/1920x1080/template/TinkerGame-PressureVessel.conf",
                "guicfgs/1920x1080/template/TinkerGame-Proton.conf",
                "guicfgs/1920x1080/template/TinkerGame-SetWineDebugChannels.conf",
                "guicfgs/1920x1080/template/TinkerGame-Shader.conf",
                "guicfgs/1920x1080/template/TinkerGame-SortCategories.conf",
                "guicfgs/1920x1080/template/TinkerGame-SteamGridDB.conf",
                "guicfgs/1920x1080/template/TinkerGame-Stl.conf",
                "guicfgs/1920x1080/template/TinkerGame-Tools.conf",
                "guicfgs/1920x1080/template/TinkerGame-Urls.conf",
                "guicfgs/1920x1080/template/TinkerGame-VR.conf",
                "guicfgs/1920x1080/template/TinkerGame-Vortex.conf",
                "guicfgs/1920x1080/template/TinkerGame-VortexOptions.conf",
                "guicfgs/1920x1080/template/TinkerGame-Wine.conf",
                "guicfgs/1920x1080/template/TinkerGame-WinetricksPackageSelection-dlls.conf",
                "guicfgs/1920x1080/template/TinkerGame-chooseWinetricksPrefix.conf",
                "guicfgs/1920x1080/template/TinkerGame-installVortexGui.conf",
                "guicfgs/1920x1080/template/TinkerGame-launchGameMenu.conf",
                "guicfgs/1920x1080/template/TinkerGame-launchGameTemplateMenu.conf",
                "guicfgs/1920x1080/template/TinkerGame-launchGlobalMenu.conf",
                "guicfgs/1920x1080/template/TinkerGame-non-steam game.conf",
                "guicfgs/1920x1080/template/TinkerGame-set game artwork.conf",
                "guicfgs/3840x2160/template/TinkerGame-AddVortexStage.conf",
                "guicfgs/3840x2160/template/TinkerGame-Ask_Recreate_Compatdata.conf",
                "guicfgs/3840x2160/template/TinkerGame-CategorySelection.conf",
                "guicfgs/3840x2160/template/TinkerGame-DXVK-Hud-Options.conf",
                "guicfgs/3840x2160/template/TinkerGame-DownloadCustomProton.conf",
                "guicfgs/3840x2160/template/TinkerGame-DownloadWine.conf",
                "guicfgs/3840x2160/template/TinkerGame-Editor.conf",
                "guicfgs/3840x2160/template/TinkerGame-EntryBlockSelection.conf",
                "guicfgs/3840x2160/template/TinkerGame-Favorites.conf",
                "guicfgs/3840x2160/template/TinkerGame-FavoritesSelection.conf",
                "guicfgs/3840x2160/template/TinkerGame-FetchSteamGridDBArtwork.conf",
                "guicfgs/3840x2160/template/TinkerGame-GameScopeGui.conf",
                "guicfgs/3840x2160/template/TinkerGame-Gui.conf",
                "guicfgs/3840x2160/template/TinkerGame-HMM.conf",
                "guicfgs/3840x2160/template/TinkerGame-HelpUrlMenu.conf",
                "guicfgs/3840x2160/template/TinkerGame-MainMenu.conf",
                "guicfgs/3840x2160/template/TinkerGame-Misc.conf",
                "guicfgs/3840x2160/template/TinkerGame-OneTimeRunGui.conf",
                "guicfgs/3840x2160/template/TinkerGame-PressureVessel.conf",
                "guicfgs/3840x2160/template/TinkerGame-Proton.conf",
                "guicfgs/3840x2160/template/TinkerGame-SetWineDebugChannels.conf",
                "guicfgs/3840x2160/template/TinkerGame-Shader.conf",
                "guicfgs/3840x2160/template/TinkerGame-SortCategories.conf",
                "guicfgs/3840x2160/template/TinkerGame-SteamCollectionSelection.conf",
                "guicfgs/3840x2160/template/TinkerGame-SteamGridDB.conf",
                "guicfgs/3840x2160/template/TinkerGame-Stl.conf",
                "guicfgs/3840x2160/template/TinkerGame-Tools.conf",
                "guicfgs/3840x2160/template/TinkerGame-Urls.conf",
                "guicfgs/3840x2160/template/TinkerGame-VR.conf",
                "guicfgs/3840x2160/template/TinkerGame-Vortex Toggle.conf",
                "guicfgs/3840x2160/template/TinkerGame-Vortex.conf",
                "guicfgs/3840x2160/template/TinkerGame-VortexOptions.conf",
                "guicfgs/3840x2160/template/TinkerGame-Wine.conf",
                "guicfgs/3840x2160/template/TinkerGame-WinetricksPackageSelection-dlls.conf",
                "guicfgs/3840x2160/template/TinkerGame-chooseWinetricksPrefix.conf",
                "guicfgs/3840x2160/template/TinkerGame-installVortexGui.conf",
                "guicfgs/3840x2160/template/TinkerGame-launchGameMenu.conf",
                "guicfgs/3840x2160/template/TinkerGame-launchGameTemplateMenu.conf",
                "guicfgs/3840x2160/template/TinkerGame-launchGlobalMenu.conf",
                "guicfgs/3840x2160/template/TinkerGame-non-steam game.conf",
                "guicfgs/3840x2160/template/TinkerGame-set game artwork.conf",
                "lang/chinese.txt",
                "lang/dutch.txt",
                "lang/english.txt",
                "lang/englishUK.txt",
                "lang/french.txt",
                "lang/german.txt",
                "lang/italian.txt",
                "lang/polish.txt",
                "lang/russian.txt",
                "misc/appinfo.txt",
                "misc/dxvk-no-nvapiHack.conf",
                "misc/favorites.conf",
                "misc/helpurls.txt",
                "misc/hmmgames.txt",
                "misc/mo2games.txt",
                "misc/repocustomlist.txt",
                "misc/sbstweaks/108800.conf",
                "misc/sbstweaks/108800.sh",
                "misc/sbstweaks/1282690.conf",
                "misc/sbstweaks/208200.conf",
                "misc/sbstweaks/214490.conf",
                "misc/sbstweaks/319910.conf",
                "misc/sbstweaks/35700.conf",
                "misc/sbstweaks/35720.conf",
                "misc/sbstweaks/391220.conf",
                "misc/sbstweaks/425210.conf",
                "misc/sbstweaks/444000.conf",
                "misc/sbstweaks/539330.conf",
                "misc/sbstweaks/71340.conf",
                "misc/sbstweaks/750920.conf",
                "misc/steamworks-shared.txt",
                "misc/tg-tabs.css",
                "misc/tinkergame-steamdeck-control.vdf",
                "misc/tinkergame-vr-patch",
                "misc/tinkergame.desktop",
                "misc/tinkergame.svg",
                "misc/vortexgames.txt",
                "misc/winedebugchannels.txt",
                "misc/x64dbg.reg" };
        }
    }
}
