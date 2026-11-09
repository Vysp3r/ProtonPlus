namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class LaunchOptionRadvDebug : LaunchOptionCustomPairs {

        public LaunchOptionRadvDebug () {

            var keys = LaunchOptionFlags.values ("amd-radv-debug");

            string[] display_opts = { _ ("Disabled"), _ ("Enabled (Enforce)") };
            string[] value_opts = { "", "1" };

            var tooltips = LaunchOptionFlags.descriptions ("amd-radv-debug");

            base (
                _ ("AMD RADV Debug Options"),
                _ ("Fine-tune AMD Radeon Vulkan driver behavior"),
                _ ("Enable RADV Debug"),
                _ ("Apply low-level driver bugfixes and overrides"),
                keys,
                display_opts,
                value_opts,
                tooltips,
                ",",
                "RADV_DEBUG",
                false
            );
        }
    }
}
