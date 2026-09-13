namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class LaunchOptionRadvPerftest : LaunchOptionCustomPairs {

        public LaunchOptionRadvPerftest () {

            string[] keys = {
                "cswave32",
                "dccmsaa",
                "dmashaders",
                "gewave32",
                "localbos",
                "lowlatencydec",
                "lowlatencyenc",
                "nggc",
                "nircache",
                "nogttspill",
                "nosam",
                "pswave32",
                "rtcps"
            };

            string[] display_opts = { _ ("Disabled"), _ ("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);

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
