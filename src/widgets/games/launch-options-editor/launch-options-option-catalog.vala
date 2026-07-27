namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    /* Presentation metadata only. LaunchOptionsList remains the owner of
     * shell-safe parsing, source order, and serialized command output. */
    public enum LaunchOptionCategory {
        PERFORMANCE,
        DISPLAY,
        PROTON,
        GRAPHICS,
        HARDWARE,
        INPUT_AUDIO,
        GAME_ARGUMENTS,
        DIAGNOSTICS
    }

    public enum LaunchOptionView {
        QUICK,
        ACTIVE,
        ALL,
        PERFORMANCE,
        DISPLAY,
        PROTON,
        GRAPHICS,
        HARDWARE,
        INPUT_AUDIO,
        GAME_ARGUMENTS,
        DIAGNOSTICS
    }

    public enum LaunchOptionExpertise {
        STANDARD,
        ADVANCED,
        EXPERIMENTAL
    }

    public class LaunchOptionMetadata : Object {
        public string id { get; construct; }
        public string title { get; construct; }
        public string description { get; construct; }
        public LaunchOptionCategory category { get; construct; }
        public string subsection { get; construct; }
        public uint display_rank { get; construct; }
        public bool quick_setting { get; construct; }
        public LaunchOptionExpertise expertise { get; construct; }
        public string applicability { get; construct; }
        public string unavailable_reason { get; construct; }
        public string[] dependencies { get; construct; }
        public string[] aliases { get; construct; }
        public string[] raw_tokens { get; construct; }
        public LaunchLineType serialization_type { get; construct; }
        public uint command_order_rank { get; construct; }

        public LaunchOptionMetadata (
            string id, string title, string description, LaunchOptionCategory category,
            string subsection, uint display_rank, bool quick_setting,
            LaunchOptionExpertise expertise, string applicability,
            string unavailable_reason, string[] dependencies, string[] aliases,
            string[] raw_tokens, LaunchLineType serialization_type,
            uint command_order_rank
        ) {
            Object (
                id: id, title: title, description: description, category: category,
                subsection: subsection, display_rank: display_rank,
                quick_setting: quick_setting, expertise: expertise,
                applicability: applicability, unavailable_reason: unavailable_reason,
                dependencies: dependencies, aliases: aliases, raw_tokens: raw_tokens,
                serialization_type: serialization_type,
                command_order_rank: command_order_rank
            );
        }

        public bool matches_search (string query) {
            var normalized = query.strip ().down ();
            if (normalized == "")
                return true;
            if (matches (title, normalized) || matches (description, normalized)
                || matches (subsection, normalized)
                || matches (LaunchOptionCatalog.category_title (category), normalized)
                || matches (applicability, normalized))
                return true;
            foreach (var alias in aliases) {
                if (matches (alias, normalized))
                    return true;
            }
            foreach (var token in raw_tokens) {
                if (matches (token, normalized))
                    return true;
            }
            return false;
        }

        bool matches (string text, string query) {
            return text.down ().contains (query);
        }
    }

    public class LaunchOptionCatalog : Object {
        Gee.ArrayList<LaunchOptionMetadata> entries;
        Gee.HashMap<string, LaunchOptionMetadata> by_id;

        public LaunchOptionCatalog () {
            entries = new Gee.ArrayList<LaunchOptionMetadata> ();
            by_id = new Gee.HashMap<string, LaunchOptionMetadata> ();
            add_defaults ();
        }

        public static string category_title (LaunchOptionCategory category) {
            switch (category) {
                case LaunchOptionCategory.PERFORMANCE: return _("Performance & monitoring");
                case LaunchOptionCategory.DISPLAY: return _("Display & launch tools");
                case LaunchOptionCategory.PROTON: return _("Proton & Wine compatibility");
                case LaunchOptionCategory.GRAPHICS: return _("Graphics translation");
                case LaunchOptionCategory.HARDWARE: return _("Hardware & drivers");
                case LaunchOptionCategory.INPUT_AUDIO: return _("Input & audio");
                case LaunchOptionCategory.GAME_ARGUMENTS: return _("Game arguments");
                case LaunchOptionCategory.DIAGNOSTICS: return _("Diagnostics & raw command");
                default: assert_not_reached ();
            }
        }

        public static LaunchOptionView category_view (LaunchOptionCategory category) {
            return (LaunchOptionView) ((int) category + (int) LaunchOptionView.PERFORMANCE);
        }

        public LaunchOptionMetadata? lookup (string id) {
            return by_id.get (id);
        }

        public Gee.List<LaunchOptionMetadata> get_ordered () {
            var ordered = new Gee.ArrayList<LaunchOptionMetadata> ();
            foreach (var entry in entries)
                ordered.add (entry);
            ordered.sort ((a, b) => {
                if (a.category != b.category)
                    return (int) a.category - (int) b.category;
                if (a.display_rank != b.display_rank)
                    return (int) a.display_rank - (int) b.display_rank;
                return strcmp (a.id, b.id);
            });
            return ordered;
        }

        public Gee.List<LaunchOptionMetadata> search (string query) {
            var results = new Gee.ArrayList<LaunchOptionMetadata> ();
            foreach (var entry in get_ordered ()) {
                if (entry.matches_search (query))
                    results.add (entry);
            }
            return results;
        }

        public bool should_display (LaunchOptionMetadata metadata, LaunchOptionView view, string query, bool active) {
            if (active)
                return true;
            if (query.strip () != "")
                return metadata.matches_search (query);
            if (view == LaunchOptionView.ALL)
                return true;
            if (view == LaunchOptionView.QUICK)
                return metadata.quick_setting;
            if (view == LaunchOptionView.ACTIVE)
                return false;
            return category_view (metadata.category) == view;
        }

        public bool is_valid () {
            var ids = new Gee.HashSet<string> ();
            foreach (var entry in entries) {
                if (entry.id == "" || ids.contains (entry.id))
                    return false;
                ids.add (entry.id);
                foreach (var dependency in entry.dependencies) {
                    if (!by_id.has_key (dependency))
                        return false;
                }
            }
            return true;
        }

        void add_option (
            string id, string title, string description, LaunchOptionCategory category,
            uint rank, string[] raw_tokens, string[] aliases = {},
            LaunchLineType type = LaunchLineType.ENVIRONMENT, string subsection = "",
            bool quick = false, LaunchOptionExpertise expertise = LaunchOptionExpertise.STANDARD,
            string applicability = "", string[] dependencies = {}
        ) {
            var entry = new LaunchOptionMetadata (
                id, title, description, category, subsection, rank, quick, expertise,
                applicability, "", dependencies, aliases, raw_tokens, type, rank
            );
            assert (!by_id.has_key (id));
            entries.add (entry);
            by_id.set (id, entry);
        }

        void add_defaults () {
            // Performance & monitoring
            add_option ("performance-overlay", _("MangoHud performance overlay"), _("Shows FPS, CPU/GPU usage, and temperatures in game."), LaunchOptionCategory.PERFORMANCE, 10, { "mangohud" }, { "MangoHud", "performance overlay" }, LaunchLineType.WRAPPER, "", true);
            add_option ("gamemode", _("GameMode"), _("Requests temporary system performance optimizations while the game is running."), LaunchOptionCategory.PERFORMANCE, 20, { "gamemoderun" }, { "Feral Gamemode", "gamemoderun" }, LaunchLineType.WRAPPER, "", true);
            add_option ("high-process-priority", _("High process priority"), _("Gives the game a higher CPU priority."), LaunchOptionCategory.PERFORMANCE, 30, { "PROTON_PRIORITY_HIGH=1" });
            add_option ("per-game-shader-cache", _("Per-game shader cache"), _("Keeps this game's shader cache separate."), LaunchOptionCategory.PERFORMANCE, 40, { "PROTON_LOCAL_SHADER_CACHE=1" }, { "local shader cache" });

            // Display & launch tools
            add_option ("launch-backend", _("Launch backend"), _("Choose the system default, Gamescope, or ScopeBuddy."), LaunchOptionCategory.DISPLAY, 10, { "gamescope", "scopebuddy" }, { "System default", "Gamescope", "ScopeBuddy" }, LaunchLineType.WRAPPER);
            add_option ("native-wayland", _("Native Wayland"), _("Runs the game on Wayland instead of XWayland."), LaunchOptionCategory.DISPLAY, 20, { "PROTON_ENABLE_WAYLAND=1" }, { "Wayland" });
            add_option ("desktop-game-profile", _("Use desktop game profile"), _("Uses the desktop profile instead of a Steam Deck-specific profile."), LaunchOptionCategory.DISPLAY, 30, { "SteamDeck=0" }, { "Disable Steam Deck Mode", "Steam Deck" });
            add_option ("vkbasalt", _("vkBasalt visual effects"), _("Adds visual effects such as sharpening and color adjustments."), LaunchOptionCategory.DISPLAY, 40, { "ENABLE_VKBASALT=1" }, { "VKBasalt" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("proton-hdr", _("HDR through Proton"), _("Outputs HDR colors through Proton when the display supports it."), LaunchOptionCategory.DISPLAY, 50, { "PROTON_ENABLE_HDR=1" }, {}, LaunchLineType.ENVIRONMENT, "", true);
            add_option ("gamescope-fullscreen", _("Fullscreen"), _("Runs the game in a fullscreen Gamescope session."), LaunchOptionCategory.DISPLAY, 60, { "-f" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-resolution", _("Output resolution"), _("Sets the Gamescope output resolution."), LaunchOptionCategory.DISPLAY, 70, { "-W", "-H" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-hdr", _("HDR"), _("Outputs HDR colors through Gamescope."), LaunchOptionCategory.DISPLAY, 80, { "--hdr-enabled" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), true, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-vrr", _("Variable refresh rate"), _("Matches the display refresh rate to the game's FPS."), LaunchOptionCategory.DISPLAY, 90, { "--adaptive-sync" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-frame-limit", _("Frame limit"), _("Caps the frame rate inside Gamescope."), LaunchOptionCategory.DISPLAY, 100, { "-r" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), true, LaunchOptionExpertise.STANDARD, _("Requires Gamescope"));
            add_option ("gamescope-arguments", _("Additional Gamescope arguments"), _("Keeps extra Gamescope flags such as output selection."), LaunchOptionCategory.DISPLAY, 110, { "gamescope" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("Gamescope"), false, LaunchOptionExpertise.ADVANCED, _("Requires Gamescope"));
            add_option ("scopebuddy-fullscreen", _("Fullscreen"), _("Runs the game in a fullscreen ScopeBuddy session."), LaunchOptionCategory.DISPLAY, 120, { "-f" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-resolution", _("Output resolution"), _("Sets the ScopeBuddy output resolution."), LaunchOptionCategory.DISPLAY, 130, { "SCB_W", "SCB_H" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-auto-hdr", _("Automatic HDR"), _("Enables HDR automatically when the display supports it."), LaunchOptionCategory.DISPLAY, 140, { "SCB_AUTO_HDR=1" }, {}, LaunchLineType.ENVIRONMENT, _("ScopeBuddy"), true, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-auto-vrr", _("Automatic variable refresh rate"), _("Matches the display refresh rate to the game's FPS."), LaunchOptionCategory.DISPLAY, 150, { "SCB_AUTO_VRR=1" }, {}, LaunchLineType.ENVIRONMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-frame-limit", _("Frame limit"), _("Caps the frame rate inside ScopeBuddy."), LaunchOptionCategory.DISPLAY, 160, { "-r" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), true, LaunchOptionExpertise.STANDARD, _("Requires ScopeBuddy"));
            add_option ("scopebuddy-arguments", _("Additional ScopeBuddy arguments"), _("Keeps extra ScopeBuddy flags such as preferred output selection."), LaunchOptionCategory.DISPLAY, 170, { "scopebuddy", "scb" }, {}, LaunchLineType.WRAPPER_ARGUMENT, _("ScopeBuddy"), false, LaunchOptionExpertise.ADVANCED, _("Requires ScopeBuddy"));

            // Proton & Wine compatibility
            add_option ("wined3d", _("OpenGL fallback (WineD3D)"), _("Uses OpenGL instead of Vulkan when DXVK causes problems."), LaunchOptionCategory.PROTON, 10, { "PROTON_USE_WINED3D=1" }, { "WineD3D" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("d7vk", _("D7VK for older Direct3D games"), _("Enables D7VK for older Direct3D games."), LaunchOptionCategory.PROTON, 20, { "PROTON_USE_D7VK=1" }, { "D7VK" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires a compatible Proton version"));
            add_option ("ntsync-mode", _("NTSync mode"), _("Uses FSync instead of NTSync for games that need that compatibility mode."), LaunchOptionCategory.PROTON, 30, { "PROTON_USE_NTSYNC=0" }, { "Use FSync" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("large-address-aware", _("Large address awareness for 32-bit games"), _("Lets supported 32-bit games use more than 2GB of memory."), LaunchOptionCategory.PROTON, 40, { "PROTON_FORCE_LARGE_ADDRESS_AWARE=1" });
            add_option ("wow64", _("WoW64 mode"), _("Enables WoW64 support for 32-bit games on 64-bit Proton builds."), LaunchOptionCategory.PROTON, 50, { "PROTON_USE_WOW64=1" }, { "Use WoW64" });
            add_option ("writecopy", _("Write-copy memory workaround"), _("Simulates page write protection for initialization errors."), LaunchOptionCategory.PROTON, 60, { "WINE_SIMULATE_WRITECOPY=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("vulkan-sync2", _("Vulkan synchronization 2"), _("Enables WINE_VK_USE_SYNC2."), LaunchOptionCategory.PROTON, 70, { "WINE_VK_USE_SYNC2=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("futex-waitv", _("Futex waitv synchronization"), _("Enables WINE_SYNC_USE_FUTEX_WAITV."), LaunchOptionCategory.PROTON, 80, { "WINE_SYNC_USE_FUTEX_WAITV=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("optiscaler", _("OptiScaler integration"), _("Enables Proton OptiScaler."), LaunchOptionCategory.PROTON, 90, { "PROTON_USE_OPTISCALER=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires Proton 11-1 or newer"));
            add_option ("discord-bridge", _("Discord bridge"), _("Enables Proton's Discord bridge."), LaunchOptionCategory.PROTON, 100, { "PROTON_DISCORD_BRIDGE=1" }, {}, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires Proton 11-1 or newer"));
            add_option ("dll-overrides", _("Wine DLL overrides"), _("Choose builtin or native Windows DLL behavior."), LaunchOptionCategory.PROTON, 110, { "DLL_OVERRIDES" }, { "mscoree", "dxgi", "wined3d" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);

            // Graphics translation
            add_option ("dxvk-frame-limit", _("DXVK frame limit"), _("Caps the frame rate with DXVK's built-in limiter."), LaunchOptionCategory.GRAPHICS, 10, { "DXVK_FRAME_RATE=" }, {}, LaunchLineType.ENVIRONMENT, _("DXVK"));
            add_option ("dxvk-async", _("Asynchronous pipeline compilation"), _("Enables DXVK asynchronous pipeline compilation."), LaunchOptionCategory.GRAPHICS, 20, { "DXVK_ASYNC=1" }, { "DXVK Async" }, LaunchLineType.ENVIRONMENT, _("DXVK"), false, LaunchOptionExpertise.EXPERIMENTAL, _("Requires compatible patched DXVK"));
            add_option ("vkd3d-shader-cache", _("VKD3D shader cache"), _("Enables VKD3D's internal shader cache."), LaunchOptionCategory.GRAPHICS, 30, { "VKD3D_SHADER_CACHE=1" }, {}, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"));
            add_option ("vkd3d-gpuva", _("VKD3D GPU virtual addressing"), _("Enables VKD3D GPU virtual addressing."), LaunchOptionCategory.GRAPHICS, 40, { "VKD3D_GPUVA=1" }, {}, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"), false, LaunchOptionExpertise.ADVANCED);
            add_option ("vkd3d-config", _("VKD3D compatibility settings"), _("Configure Direct3D 12 to Vulkan compatibility workarounds."), LaunchOptionCategory.GRAPHICS, 50, { "VKD3D_CONFIG", "shader_cache", "force_host_cache", "upload_hvv", "no_upload_hvv", "gpuva", "stable_power_state" }, { "VKD3D Proton Configurations" }, LaunchLineType.ENVIRONMENT, _("VKD3D-Proton"), false, LaunchOptionExpertise.ADVANCED);

            // Hardware & drivers
            add_option ("amd-discrete-gpu", _("Use discrete GPU"), _("Uses the AMD discrete GPU on hybrid systems."), LaunchOptionCategory.HARDWARE, 10, { "DRI_PRIME=1" }, { "Use dGPU" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-anti-lag", _("Mesa Anti-Lag"), _("Reduces latency on supported AMD Mesa setups."), LaunchOptionCategory.HARDWARE, 20, { "ENABLE_LAYER_MESA_ANTI_LAG=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-fsr4", _("FSR 4 upgrade"), _("Upgrades supported FSR 3.1 games to FSR 4."), LaunchOptionCategory.HARDWARE, 30, { "PROTON_FSR4_UPGRADE=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-fsr4-rdna3", _("FSR 4 RDNA3 upgrade"), _("Optimizes FSR 4 for RDNA3 hardware."), LaunchOptionCategory.HARDWARE, 40, { "PROTON_FSR4_RDNA3_UPGRADE=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-hide-apu", _("Treat APU as a discrete GPU"), _("Reports an AMD APU as a discrete GPU for games that mis-detect integrated graphics."), LaunchOptionCategory.HARDWARE, 50, { "PROTON_HIDE_APU=1" }, { "Hide AMD APU" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-vulkan-driver", _("Vulkan driver"), _("Chooses the AMD Vulkan driver for this game."), LaunchOptionCategory.HARDWARE, 60, { "AMD_ICD" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-staging-shm", _("Staging shared memory"), _("Enables AMD driver shared memory support."), LaunchOptionCategory.HARDWARE, 70, { "STAGING_SHARED_MEMORY=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.STANDARD, _("AMD"));
            add_option ("amd-glthread", _("Mesa GL threading"), _("Enables Mesa GLThread."), LaunchOptionCategory.HARDWARE, 80, { "mesa_glthread=true" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-shader-cache", _("Mesa shader-cache control"), _("Controls Mesa's shader cache."), LaunchOptionCategory.HARDWARE, 90, { "MESA_SHADER_CACHE_DISABLE=0", "MESA_SHADER_CACHE_DISABLE=1" }, {}, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-radv-perftest", _("Experimental RADV features"), _("Tests experimental RADV performance features."), LaunchOptionCategory.HARDWARE, 100, { "RADV_PERFTEST" }, { "AMD RADV Performance Tests" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.EXPERIMENTAL, _("AMD"));
            add_option ("amd-radv-debug", _("RADV workarounds and debugging"), _("Configure RADV compatibility workarounds and debugging."), LaunchOptionCategory.HARDWARE, 110, { "RADV_DEBUG" }, { "AMD RADV Debug Options" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("amd-aco-debug", _("ACO shader-compiler debugging"), _("Configure AMD ACO shader compiler debugging."), LaunchOptionCategory.HARDWARE, 120, { "ACO_DEBUG" }, { "AMD ACO Debug Options" }, LaunchLineType.ENVIRONMENT, _("AMD"), false, LaunchOptionExpertise.ADVANCED, _("AMD"));
            add_option ("nvidia-nvapi", _("NVAPI"), _("Lets games access NVIDIA-specific features such as DLSS."), LaunchOptionCategory.HARDWARE, 130, { "PROTON_ENABLE_NVAPI=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("nvidia-dlss-updater", _("DLSS component updates"), _("Updates DLSS components for supported games."), LaunchOptionCategory.HARDWARE, 140, { "PROTON_ENABLE_NGX_UPDATER=1" }, { "Update DLSS components" }, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"), { "nvidia-nvapi" });
            add_option ("nvidia-dlss-indicator", _("DLSS indicator"), _("Shows an in-game DLSS status indicator."), LaunchOptionCategory.HARDWARE, 150, { "PROTON_DLSS_INDICATOR=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("nvidia-libraries", _("NVIDIA libraries"), _("Enables NVIDIA-specific libraries."), LaunchOptionCategory.HARDWARE, 160, { "PROTON_NVIDIA_LIBS=1" }, {}, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("nvidia-report-amd", _("Report GPU as AMD"), _("Reports an NVIDIA GPU as AMD for affected games."), LaunchOptionCategory.HARDWARE, 170, { "PROTON_HIDE_NVIDIA_GPU=1" }, { "Hide NVIDIA GPU" }, LaunchLineType.ENVIRONMENT, _("NVIDIA"), false, LaunchOptionExpertise.STANDARD, _("NVIDIA"));
            add_option ("intel-xess", _("XeSS component upgrade"), _("Updates XeSS in supported games."), LaunchOptionCategory.HARDWARE, 180, { "PROTON_XESS_UPGRADE=1" }, { "XeSS Upgrade" }, LaunchLineType.ENVIRONMENT, _("Intel"), false, LaunchOptionExpertise.STANDARD, _("Intel"));

            // Input & audio
            add_option ("prefer-sdl", _("Prefer SDL controller input"), _("Works around controller detection issues."), LaunchOptionCategory.INPUT_AUDIO, 10, { "PROTON_PREFER_SDL=1" }, { "Prefer SDL controller" });
            add_option ("bypass-steam-input", _("Bypass Steam Input"), _("Disables Steam Input support."), LaunchOptionCategory.INPUT_AUDIO, 20, { "PROTON_NO_STEAMINPUT=1" }, { "Disable Steam Input" });
            add_option ("pulse-latency", _("PulseAudio latency"), _("Sets the PulseAudio latency target."), LaunchOptionCategory.INPUT_AUDIO, 30, { "PULSE_LATENCY_MSEC=" });
            add_option ("winealsa-channels", _("Wine ALSA output channels"), _("Sets the Wine ALSA output channel count."), LaunchOptionCategory.INPUT_AUDIO, 40, { "WINEALSA_CHANNELS=" }, { "WINEALSA Channels" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires Proton 11-1 or newer"));
            add_option ("winealsa-spatial", _("Wine ALSA spatial downmix"), _("Enables Wine ALSA spatial downmix for 4, 6, or 8 channels."), LaunchOptionCategory.INPUT_AUDIO, 50, { "WINEALSA_SPACIAL=1" }, { "WINEALSA Spatial Audio" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.STANDARD, _("Requires 4, 6, or 8 output channels"), { "winealsa-channels" });

            // Game arguments
            add_option ("skip-launcher", _("Skip launcher"), _("Adds -skip-launcher for games that support it."), LaunchOptionCategory.GAME_ARGUMENTS, 10, { "-skip-launcher" }, {}, LaunchLineType.ARGUMENT, "", true);
            add_option ("renderer-vulkan", _("Vulkan renderer"), _("Adds -vulkan."), LaunchOptionCategory.GAME_ARGUMENTS, 20, { "-vulkan" }, {}, LaunchLineType.ARGUMENT);
            add_option ("renderer-dx11", _("DirectX 11 renderer"), _("Adds -dx11."), LaunchOptionCategory.GAME_ARGUMENTS, 30, { "-dx11" }, {}, LaunchLineType.ARGUMENT);
            add_option ("renderer-dx12", _("DirectX 12 renderer"), _("Adds -dx12."), LaunchOptionCategory.GAME_ARGUMENTS, 40, { "-dx12" }, {}, LaunchLineType.ARGUMENT);
            add_option ("developer-console", _("Developer console"), _("Adds -console when the game supports it."), LaunchOptionCategory.GAME_ARGUMENTS, 50, { "-console" }, { "Console" }, LaunchLineType.ARGUMENT);
            add_option ("custom-game-arguments", _("Custom game arguments"), _("Adds your own game arguments without changing recognized controls."), LaunchOptionCategory.GAME_ARGUMENTS, 60, { "custom", "arguments" }, {}, LaunchLineType.ADDITIONAL, "", false, LaunchOptionExpertise.ADVANCED);

            // Diagnostics & raw command
            add_option ("proton-debug-log", _("Proton debug log"), _("Enables Proton troubleshooting logs."), LaunchOptionCategory.DIAGNOSTICS, 10, { "PROTON_LOG=1" }, { "Enable Proton logs" }, LaunchLineType.ENVIRONMENT, "", true);
            add_option ("dxvk-log-level", _("DXVK log level"), _("Controls DXVK logging."), LaunchOptionCategory.DIAGNOSTICS, 20, { "DXVK_LOG_LEVEL=none" }, { "Disable DXVK logging" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("vkd3d-log-level", _("VKD3D log level"), _("Controls VKD3D troubleshooting logs."), LaunchOptionCategory.DIAGNOSTICS, 30, { "VKD3D_LOG_LEVEL=" }, { "VKD3D Logging Level" }, LaunchLineType.ENVIRONMENT, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("steam-command", _("Steam command placeholder (%command%)"), _("Marks where Steam inserts the game's command."), LaunchOptionCategory.DIAGNOSTICS, 40, { "%command%" }, {}, LaunchLineType.COMMAND, "", false, LaunchOptionExpertise.ADVANCED);
            add_option ("raw-launch-options", _("Preserved unrecognized launch options"), _("Keeps unrecognized, quoted, and opaque shell content exactly as loaded."), LaunchOptionCategory.DIAGNOSTICS, 50, { "$(unsafe)", "|", "&&", "%command%" }, { "raw", "opaque", "unknown", "custom pair" }, LaunchLineType.ADDITIONAL, "", false, LaunchOptionExpertise.ADVANCED);
        }
    }
}
