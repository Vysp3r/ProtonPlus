namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorAmdOptionsGroup : BaseOptionsGroup {
        LaunchOptionTile amd_fsr4_upgrade_tile { get; set; }
        LaunchOptionTile amd_fsr4_rdna3_upgrade_tile { get; set; }
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

        public GpuVendorAmdOptionsGroup (SimpleCallback standard_control_changed, LaunchOptionsList launch_option_handlers) {
            base (standard_control_changed, launch_option_handlers, true);
            refreshing_controls = true;

            amd_anti_lag_tile = create_tile (_("Mesa Anti-Lag"), _("Reduces latency on supported AMD Mesa setups."), { "ENABLE_LAYER_MESA_ANTI_LAG=1" });
            amd_prime_tile = create_tile (_("Use dGPU"), _("Makes the game use the AMD dGPU on hybrid systems."), { "DRI_PRIME=1" });
            amd_hide_apu_tile = create_tile (_("Hide AMD APU"), _("Makes Proton report an AMD APU as a discrete GPU for games that mis-detect integrated graphics."), { "PROTON_HIDE_APU=1" });
            amd_fsr4_upgrade_tile = create_tile (_("FSR 4 Upgrade"), _("Upgrades FSR 3.1 to FSR 4 in supported games. This option also disables AMD Anti-Lag 2 currently due to various issues."), { "PROTON_FSR4_UPGRADE=1" });
            amd_fsr4_upgrade_tile.toggle.notify["active"].connect (() => {
                amd_fsr4_upgrade_toggle_changed ();
            });

            amd_fsr4_rdna3_upgrade_tile = create_tile (_("FSR 4 RDNA3 Upgrade"), _("Optimizes FSR 4.0 for RDNA3 hardware."), { "PROTON_FSR4_RDNA3_UPGRADE=1" });
            amd_fsr4_rdna3_upgrade_tile.toggle.notify["active"].connect (() => {
                amd_fsr4_rdna3_upgrade_toggle_changed ();
            });

            amd_staging_shared_memory_tile = create_tile (_("Staging shared memory"), _("Enables shared memory support in the AMD GPU driver for better performance in some games."), { "STAGING_SHARED_MEMORY=1" });
            amd_mesa_glthread_tile = create_tile (_("Mesa GLThread"), _("Enables Mesa's GLThread optimization for better performance in some games."), { "mesa_glthread=true" }, true);
            amd_mesa_shader_cache_disable_tile = create_tile (_("Disable Mesa shader cache"), _("Disables Mesa's shader cache which can cause stuttering in some games."), { "MESA_SHADER_CACHE_DISABLE=0", "MESA_SHADER_CACHE_DISABLE=1" });

            radv_debug_editor = new LaunchOptionRadvDebug ();
            radv_perf_editor = new LaunchOptionRadvPerftest ();
            amd_icd_editor = new LaunchOptionAmdIcd ();
            aco_debug_editor = new LaunchOptionAcoDebug ();

            radv_debug_editor.changed.connect ((row) => {
                this.standard_control_changed ();
            });
            radv_perf_editor.changed.connect ((row) => {
                this.standard_control_changed ();
            });
            amd_icd_editor.changed.connect ((row) => {
                this.standard_control_changed ();
            });
            aco_debug_editor.changed.connect ((row) => {
                this.standard_control_changed ();
            });
            radv_debug_editor.set_tooltip_text (_("Configure RADV debug options for troubleshooting and performance testing."));
            radv_perf_editor.set_tooltip_text (_("Configure RADV performance test options for testing experimental driver features. Use with caution as these features can cause instability or other issues."));
            amd_icd_editor.set_tooltip_text (_("Select which AMD Vulkan driver to use. This can be used to switch between RADV and AMD's official Vulkan driver on supported systems."));
            aco_debug_editor.set_tooltip_text (_("Configure ACO compiler debug options to troubleshoot shader compilation issues, fix in-game stuttering, or analyze graphics performance. Use with caution."));

            launch_option_handlers.add (radv_debug_editor);
            launch_option_handlers.add (radv_perf_editor);
            launch_option_handlers.add (amd_icd_editor);
            launch_option_handlers.add (aco_debug_editor);

            this.add (amd_anti_lag_tile);
            this.add (amd_fsr4_upgrade_tile);
            this.add (amd_fsr4_rdna3_upgrade_tile);
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

            this.standard_control_changed ();
        }

        void amd_fsr4_rdna3_upgrade_toggle_changed () {
            if (refreshing_controls)
                return;

            if (amd_fsr4_rdna3_upgrade_tile.toggle.get_active () && amd_fsr4_upgrade_tile.toggle.get_active ()) {
                refreshing_controls = true;
                amd_fsr4_upgrade_tile.toggle.set_active (false);
                refreshing_controls = false;
            }

            this.standard_control_changed ();
        }

        internal void normalize_amd_fsr_upgrade_dependencies () {
            if (!amd_fsr4_upgrade_tile.toggle.get_active () || !amd_fsr4_rdna3_upgrade_tile.toggle.get_active ())
                return;

            var was_refreshing = refreshing_controls;
            refreshing_controls = true;
            amd_fsr4_rdna3_upgrade_tile.toggle.set_active (false);
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

        internal bool is_any_tile_active () {
            return amd_anti_lag_tile.toggle.get_active ()
                   || amd_prime_tile.toggle.get_active ()
                   || amd_hide_apu_tile.toggle.get_active ()
                   || amd_fsr4_upgrade_tile.toggle.get_active ()
                   || amd_fsr4_rdna3_upgrade_tile.toggle.get_active ()
                   || amd_staging_shared_memory_tile.toggle.get_active ()
                   || amd_mesa_glthread_tile.toggle.get_active ()
                   || amd_mesa_shader_cache_disable_tile.toggle.get_active ();
        }
    }
}