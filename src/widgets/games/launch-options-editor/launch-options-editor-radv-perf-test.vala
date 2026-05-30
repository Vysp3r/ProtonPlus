namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class LaunchOptionRadvPerftest : LaunchOptionCustomPairs {

        public LaunchOptionRadvPerftest () {

            string[] keys = { "rt", "sam", "nggc", "gpl", "ruse", "emulate_rt" };

            string[] display_opts = { _ ("Disabled"), _ ("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);
            tooltips.insert ("rt", _ ("Enables experimental hardware Ray Tracing support."));
            tooltips.insert ("sam", _ ("Optimizes Smart Access Memory / Resizable BAR utilization."));
            tooltips.insert ("nggc", _ ("Enables Next-Gen Geometry Culling for better geometry performance."));
            tooltips.insert ("gpl", _ ("Graphics Pipeline Library. Drastically reduces shader stuttering."));
            tooltips.insert ("ruse", _ ("Enables User Space Queue submission. Can improve CPU-bound game performance on modern kernels."));
            tooltips.insert ("emulate_rt", _ ("Emulates hardware Ray Tracing using software compute shaders on AMD GPUs. Enables RT features on unsupported hardware at the cost of a drastic performance drop."));

            base (
                    _ ("AMD RADV Performance Tests"),
                    _ ("Enable experimental AMD performance features"),
                    _ ("Enable RADV Perftest"),
                    _ ("Test bleeding-edge driver optimizations (use with caution)"),
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