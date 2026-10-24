namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class LaunchOptionRadvPerftest : LaunchOptionCustomPairs {

        public LaunchOptionRadvPerftest () {

            var keys = LaunchOptionFlags.values ("amd-radv-perftest");

            string[] display_opts = { _ ("Disabled"), _ ("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = LaunchOptionFlags.descriptions ("amd-radv-perftest");

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
                "RADV_PERFTEST",
                false
            );
        }
    }
}
