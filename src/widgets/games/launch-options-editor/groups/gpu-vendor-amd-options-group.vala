namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorAmdOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile amd_fsr4_upgrade_tile { get; set; }
        LaunchOptionTile amd_fsr4_rdna3_upgrade_tile { get; set; }
        LaunchOptionTile amd_mlfg_upgrade_tile { get; set; }
        LaunchOptionTile amd_mlfg_rdna3_workaround_tile { get; set; }
        LaunchOptionTile amd_reflex_allow_other_drivers_tile { get; set; }
        LaunchOptionTile amd_reflex_dxgi_spoof_tile { get; set; }
        LaunchOptionTile amd_reflex_force_nvapi_tile { get; set; }
        LaunchOptionTile amd_reflex_layer_spoof_tile { get; set; }
        LaunchOptionTile amd_anti_lag_tile { get; set; }
        LaunchOptionTile amd_prime_tile { get; set; }
        LaunchOptionTile amd_hide_apu_tile { get; set; }
        LaunchOptionTile amd_staging_shared_memory_tile { get; set; }
        LaunchOptionTile amd_mesa_glthread_tile { get; set; }
        LaunchOptionTile amd_mesa_shader_cache_disable_tile { get; set; }
        LaunchOptionAmdIcd amd_icd_editor { get; set; }
        LaunchOptionRadvPerftest radv_perf_editor { get; set; }
        LaunchOptionRadvDebug radv_debug_editor { get; set; }
        LaunchOptionAcoDebug aco_debug_editor { get; set; }
        bool refreshing_controls;

        public GpuVendorAmdOptionsGroup (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, true, presentation_registry, false);
            refreshing_controls = true;

            amd_anti_lag_tile = create_tile (_("Mesa Anti-Lag"), _("Reduces latency on supported AMD Mesa setups."), { "ENABLE_LAYER_MESA_ANTI_LAG=1" }, false, LaunchLineType.ENVIRONMENT, "amd-anti-lag");
            amd_prime_tile = create_tile (_("Use discrete GPU"), _("Makes the game use the AMD dGPU on hybrid systems."), { "DRI_PRIME=1" }, false, LaunchLineType.ENVIRONMENT, "amd-discrete-gpu");
            amd_hide_apu_tile = create_tile (
                _("Treat APU as a discrete GPU"),
                _("Makes Proton report an AMD APU as a discrete GPU for games that mis-detect integrated graphics."),
                { "PROTON_HIDE_APU=1" }, false, LaunchLineType.ENVIRONMENT, "amd-hide-apu"
            );
            amd_fsr4_upgrade_tile = create_tile (
                _("FSR 4 upgrade (current path)"),
                _("Uses the selected custom Proton build's default FSR 4 release. Current Proton-GE disables Anti-Lag 2 while active."),
                { "PROTON_FSR4_UPGRADE=1" }, false, LaunchLineType.ENVIRONMENT, "amd-fsr4"
            );
            amd_fsr4_upgrade_tile.toggle.notify["active"].connect (() => {
                amd_fsr4_upgrade_toggle_changed ();
            });

            amd_fsr4_rdna3_upgrade_tile = create_tile (
                _("FSR 4 RDNA3 upgrade (legacy path)"),
                _("Uses the older RDNA3 switch retained by some Proton-GE builds and removed from current Proton-CachyOS."),
                { "PROTON_FSR4_RDNA3_UPGRADE=1" }, false, LaunchLineType.ENVIRONMENT,
                "amd-fsr4-rdna3"
            );
            amd_fsr4_rdna3_upgrade_tile.toggle.notify["active"].connect (() => {
                amd_fsr4_rdna3_upgrade_toggle_changed ();
            });

            amd_mlfg_upgrade_tile = create_tile (
                _("FSR 4 ML frame generation"),
                _("Requires FSR 4.0.3 or newer. RDNA3 may also need DXIL_SPIRV_CONFIG=wmma_rdna3_workaround."),
                { "PROTON_MLFG_UPGRADE=1" }, false, LaunchLineType.ENVIRONMENT, "amd-mlfg"
            );
            amd_mlfg_rdna3_workaround_tile = create_tile (
                _("RDNA3 ML frame-generation workaround"),
                _("Applies the DXIL-SPIR-V WMMA workaround only when RDNA3 ML frame generation needs it."),
                { "DXIL_SPIRV_CONFIG=wmma_rdna3_workaround" }, false,
                LaunchLineType.ENVIRONMENT, "amd-mlfg-rdna3-workaround"
            );
            amd_reflex_allow_other_drivers_tile = create_tile (
                _("AMD Reflex preset: allow DXVK-NVAPI"),
                _("Least-invasive preset. Allows DXVK-NVAPI on AMD; try this before GPU spoofing."),
                { "DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1" }, false, LaunchLineType.ENVIRONMENT,
                "amd-reflex-allow-other-drivers"
            );
            amd_reflex_dxgi_spoof_tile = create_tile (
                _("AMD Reflex preset: hide AMD GPU"),
                _("DXVK fallback that can expose Reflex but can break FSR 4 and ML frame generation."),
                { "DXVK_CONFIG=dxgi.hideAmdGpu=True" }, false, LaunchLineType.ENVIRONMENT,
                "amd-reflex-dxgi-spoof"
            );
            amd_reflex_force_nvapi_tile = create_tile (
                _("AMD Reflex preset: force NVAPI"),
                _("Invasive fallback for games that still hide Reflex. Can break FSR 4 and game GPU detection."),
                { "PROTON_FORCE_NVAPI=1" }, false, LaunchLineType.ENVIRONMENT,
                "amd-reflex-force-nvapi"
            );
            amd_reflex_layer_spoof_tile = create_tile (
                _("AMD Reflex preset: layer NVIDIA spoof"),
                _("Last-resort spoof discouraged by upstream because it can break Proton FSR 4."),
                { "LOW_LATENCY_LAYER_SPOOF_NVIDIA=1" }, false, LaunchLineType.ENVIRONMENT,
                "amd-reflex-layer-spoof"
            );

            amd_staging_shared_memory_tile = create_tile (
                _("Staging shared memory"),
                _("Enables shared memory support in the AMD GPU driver for better performance in some games."),
                { "STAGING_SHARED_MEMORY=1" }, false, LaunchLineType.ENVIRONMENT, "amd-staging-shm"
            );
            amd_mesa_glthread_tile = create_tile (
                _("Mesa GLThread"),
                _("Enables Mesa's GLThread optimization for better performance in some games."),
                { "mesa_glthread=true" },
                true, LaunchLineType.ENVIRONMENT, "amd-glthread"
            );
            amd_mesa_shader_cache_disable_tile = create_tile (
                _("Disable Mesa shader cache"),
                _("Disables Mesa's shader cache which can cause stuttering in some games."),
                { "MESA_SHADER_CACHE_DISABLE=0", "MESA_SHADER_CACHE_DISABLE=1" }, false, LaunchLineType.ENVIRONMENT, "amd-shader-cache"
            );

            radv_debug_editor = new LaunchOptionRadvDebug ();
            radv_perf_editor = new LaunchOptionRadvPerftest ();
            amd_icd_editor = new LaunchOptionAmdIcd ();
            aco_debug_editor = new LaunchOptionAcoDebug ();

            radv_debug_editor.changed.connect ((row) => {
                this.changed ();
            });
            radv_perf_editor.changed.connect ((row) => {
                this.changed ();
            });
            amd_icd_editor.changed.connect ((row) => {
                this.changed ();
            });
            aco_debug_editor.changed.connect ((row) => {
                this.changed ();
            });
            radv_debug_editor.set_tooltip_text (_("Configure RADV debug options for troubleshooting and performance testing."));
            radv_perf_editor.set_tooltip_text (
                _("Configure RADV performance test options for testing experimental driver features. Use with caution as these features can cause instability or other issues.") // vala-lint=line-length
            );
            amd_icd_editor.set_tooltip_text (
                _("Select which AMD Vulkan driver to use. This can be used to switch between RADV and AMD's official Vulkan driver on supported systems.")
            );
            aco_debug_editor.set_tooltip_text (
                _("Configure ACO compiler debug options to troubleshoot shader compilation issues, fix in-game stuttering, or analyze graphics performance. Use with caution.") // vala-lint=line-length
            );

            launch_option_handlers.add (radv_debug_editor);
            launch_option_handlers.add (radv_perf_editor);
            launch_option_handlers.add (amd_icd_editor);
            launch_option_handlers.add (aco_debug_editor);
            register_option ("amd-radv-debug", radv_debug_editor, radv_debug_editor);
            register_option ("amd-radv-perftest", radv_perf_editor, radv_perf_editor);
            register_option ("amd-vulkan-driver", amd_icd_editor, amd_icd_editor);
            register_option ("amd-aco-debug", aco_debug_editor, aco_debug_editor);

            this.add (amd_anti_lag_tile);
            this.add (amd_fsr4_upgrade_tile);
            this.add (amd_fsr4_rdna3_upgrade_tile);
            this.add (amd_mlfg_upgrade_tile);
            this.add (amd_mlfg_rdna3_workaround_tile);
            this.add (amd_reflex_allow_other_drivers_tile);
            this.add (amd_reflex_dxgi_spoof_tile);
            this.add (amd_reflex_force_nvapi_tile);
            this.add (amd_reflex_layer_spoof_tile);
            this.add (amd_prime_tile);
            this.add (amd_hide_apu_tile);
            this.add (amd_staging_shared_memory_tile);
            this.add (amd_mesa_glthread_tile);
            this.add (amd_mesa_shader_cache_disable_tile);

            this.add (radv_debug_editor);
            this.add (radv_perf_editor);
            this.add (amd_icd_editor);
            this.add (aco_debug_editor);

            refreshing_controls = false;
        }

        void amd_fsr4_upgrade_toggle_changed () {
            if (refreshing_controls)
                return;

            if (amd_fsr4_upgrade_tile.toggle.get_active () && amd_fsr4_rdna3_upgrade_tile.toggle.get_active ()) {
                refreshing_controls = true;
                amd_fsr4_rdna3_upgrade_tile.toggle.set_active (false);
                refreshing_controls = false;
            }

            this.changed ();
        }

        void amd_fsr4_rdna3_upgrade_toggle_changed () {
            if (refreshing_controls)
                return;

            if (amd_fsr4_rdna3_upgrade_tile.toggle.get_active () && amd_fsr4_upgrade_tile.toggle.get_active ()) {
                refreshing_controls = true;
                amd_fsr4_upgrade_tile.toggle.set_active (false);
                refreshing_controls = false;
            }

            this.changed ();
        }

        internal void normalize_amd_fsr_upgrade_dependencies () {
            if (!amd_fsr4_upgrade_tile.toggle.get_active () || !amd_fsr4_rdna3_upgrade_tile.toggle.get_active ())
                return;

            var was_refreshing = refreshing_controls;
            refreshing_controls = true;
            amd_fsr4_rdna3_upgrade_tile.toggle.set_active (false);
            amd_mlfg_upgrade_tile.toggle.set_active (false);
            amd_mlfg_rdna3_workaround_tile.toggle.set_active (false);
            amd_reflex_allow_other_drivers_tile.toggle.set_active (false);
            amd_reflex_dxgi_spoof_tile.toggle.set_active (false);
            amd_reflex_force_nvapi_tile.toggle.set_active (false);
            amd_reflex_layer_spoof_tile.toggle.set_active (false);
            refreshing_controls = was_refreshing;
        }

        internal void reset_controls () {
            refreshing_controls = true;
            amd_anti_lag_tile.toggle.set_active (false);
            amd_fsr4_upgrade_tile.toggle.set_active (false);
            amd_fsr4_rdna3_upgrade_tile.toggle.set_active (false);
            amd_prime_tile.toggle.set_active (false);
            amd_hide_apu_tile.toggle.set_active (false);
            amd_staging_shared_memory_tile.toggle.set_active (false);
            amd_mesa_glthread_tile.toggle.set_active (false);
            amd_mesa_shader_cache_disable_tile.toggle.set_active (false);
            refreshing_controls = false;
        }

    }
}
