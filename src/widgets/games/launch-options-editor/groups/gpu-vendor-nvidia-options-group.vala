namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Groups {
    using Adw;

    public class GpuVendorNvidiaOptionsGroup : BaseOptionsGroup {

        LaunchOptionTile nvapi_tile { get; set; }
        LaunchOptionTile nvidia_ngx_updater_tile { get; set; }
        LaunchOptionTile nvidia_hide_gpu_tile { get; set; }
        LaunchOptionTile dlss_indicator_tile { get; set; }
        LaunchOptionTile nvidia_libs_tile { get; set; }

        bool refreshing_controls;

        public GpuVendorNvidiaOptionsGroup (owned SimpleCallback standard_control_changed, Gee.List<ILaunchOption> launch_option_handlers) {
            base((owned) standard_control_changed, launch_option_handlers, true);
            refreshing_controls = true;

            nvapi_tile = create_tile (_ ("NVAPI"), _ ("Lets games access NVIDIA-specific features like DLSS."), { "PROTON_ENABLE_NVAPI=1" });
            nvapi_tile.toggle.notify["active"].connect ( () => {
                this.nvidia_nvapi_toggle_changed();
            });
            //gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NVAPI=1" }, nvapi_tile.toggle));
            nvidia_ngx_updater_tile = create_tile (_ ("Update DLSS components"), _ ("Auto upgrades DLSS components for supported games."), { "PROTON_ENABLE_NGX_UPDATER=1" });
            nvidia_ngx_updater_tile.toggle.notify["active"].connect ( () => {
                this.nvidia_dlss_updater_toggle_changed();
            });
            //gpu_vendor_bindings.append (new LaunchOptionBinding ({ "PROTON_ENABLE_NGX_UPDATER=1" }, nvidia_ngx_updater_tile.toggle));
            nvidia_hide_gpu_tile = create_tile (_ ("Hide NVIDIA GPU"), _ ("Makes Proton report an NVIDIA GPU as AMD for games that expect Windows-only NVIDIA driver behavior."), { "PROTON_HIDE_NVIDIA_GPU=1" });
            dlss_indicator_tile = create_tile (_ ("DLSS Indicator"), _ ("Shows a DLSS status indicator in-game."), { "PROTON_DLSS_INDICATOR=1" });
            nvidia_libs_tile = create_tile (_ ("NVIDIA Libraries"), _ ("Enables NVIDIA-specific libraries (PhysX, CUDA). This is not needed for DLSS or ray tracing."), { "PROTON_NVIDIA_LIBS=1" });

            this.add(nvapi_tile);
            this.add(nvidia_ngx_updater_tile);
            this.add(nvidia_hide_gpu_tile);
            this.add(dlss_indicator_tile);
            this.add(nvidia_libs_tile);

            refreshing_controls = false;
        }

        void nvidia_nvapi_toggle_changed () {
            if (refreshing_controls)
            return;

            if (!nvapi_tile.toggle.get_active () && nvidia_ngx_updater_tile.toggle.get_active ()) {
                refreshing_controls = true;
                nvidia_ngx_updater_tile.toggle.set_active (false);
                refreshing_controls = false;
            }

            this.standard_control_changed ();
        }

        void nvidia_dlss_updater_toggle_changed () {
            if (refreshing_controls)
            return;

            if (nvidia_ngx_updater_tile.toggle.get_active () && !nvapi_tile.toggle.get_active ()) {
                refreshing_controls = true;
                nvapi_tile.toggle.set_active (true);
                refreshing_controls = false;
            }

            this.standard_control_changed ();
        }

        internal void normalize_nvidia_vendor_dependencies () {
            if (!nvidia_ngx_updater_tile.toggle.get_active () || nvapi_tile.toggle.get_active ())
            return;

            var was_refreshing = refreshing_controls;
            refreshing_controls = true;
            nvapi_tile.toggle.set_active (true);
            refreshing_controls = was_refreshing;
        }

        internal void reset_controls () {
            refreshing_controls = true;
            nvapi_tile.toggle.set_active (false);
            nvidia_ngx_updater_tile.toggle.set_active (false);
            nvidia_hide_gpu_tile.toggle.set_active (false);
            dlss_indicator_tile.toggle.set_active (false);
            nvidia_libs_tile.toggle.set_active (false);
            refreshing_controls = false;
        }

        internal bool is_any_tile_active () {
            return nvapi_tile.toggle.get_active () 
                || nvidia_ngx_updater_tile.toggle.get_active () 
                || nvidia_hide_gpu_tile.toggle.get_active () 
                || dlss_indicator_tile.toggle.get_active () 
                || nvidia_libs_tile.toggle.get_active ();
        }
    }
}
