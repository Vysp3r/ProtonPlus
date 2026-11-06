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

            amd_anti_lag_tile = create_tile ("amd-anti-lag");
            amd_prime_tile = create_tile ("amd-discrete-gpu");
            amd_hide_apu_tile = create_tile ("amd-hide-apu");
            amd_fsr4_upgrade_tile = create_tile ("amd-fsr4");
            amd_fsr4_upgrade_tile.toggle.notify["active"].connect (() => {
                amd_fsr4_upgrade_toggle_changed ();
            });

            amd_fsr4_rdna3_upgrade_tile = create_tile ("amd-fsr4-rdna3");
            amd_fsr4_rdna3_upgrade_tile.toggle.notify["active"].connect (() => {
                amd_fsr4_rdna3_upgrade_toggle_changed ();
            });

            amd_mlfg_upgrade_tile = create_tile ("amd-mlfg");
            amd_mlfg_rdna3_workaround_tile = create_tile ("amd-mlfg-rdna3-workaround");
            amd_reflex_allow_other_drivers_tile = create_tile ("amd-reflex-allow-other-drivers");
            amd_reflex_dxgi_spoof_tile = create_tile ("amd-reflex-dxgi-spoof");
            amd_reflex_force_nvapi_tile = create_tile ("amd-reflex-force-nvapi");
            amd_reflex_layer_spoof_tile = create_tile ("amd-reflex-layer-spoof");

            amd_staging_shared_memory_tile = create_tile ("amd-staging-shm");
            amd_mesa_glthread_tile = create_tile ("amd-glthread", true);
            amd_mesa_shader_cache_disable_tile = create_tile ("amd-shader-cache");

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
