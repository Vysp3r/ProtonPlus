namespace ProtonPlus.Widgets.Components {
    using Adw;
    using Gtk;

    public class LaunchOptionRadvPerftest : LaunchOptionCustomPairs {
        
        public LaunchOptionRadvPerftest () {

            string[] keys = { "rt", "sam", "nggc", "gpl", "ruse" };
            
            string[] display_opts = { _("Disabled"), _("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);
            tooltips.insert ("rt", _("Enables experimental hardware Ray Tracing support."));
            tooltips.insert ("sam", _("Optimizes Smart Access Memory / Resizable BAR utilization."));
            tooltips.insert ("nggc", _("Enables Next-Gen Geometry Culling for better geometry performance."));
            tooltips.insert ("gpl", _("Graphics Pipeline Library. Drastically reduces shader stuttering."));
            tooltips.insert ("ruse", _("Enables User Space Queue submission. Can improve CPU-bound game performance on modern kernels."));

            base (
                _("AMD RADV Performance Tests"),
                _("Enable experimental AMD performance features"),
                _("Enable RADV Perftest"),
                _("Test bleeding-edge driver optimizations (use with caution)"),
                keys,
                display_opts,
                value_opts,
                tooltips,
                ",",
                "RADV_PERFTEST"
            );
        }
    }
}