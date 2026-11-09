namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class LaunchOptionAcoDebug : LaunchOptionCustomPairs {

        public LaunchOptionAcoDebug () {

            var keys = LaunchOptionFlags.values ("amd-aco-debug");

            string[] display_opts = { _("Disabled"), _("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = LaunchOptionFlags.descriptions ("amd-aco-debug");

            base (
                _("AMD ACO Debug Options"),
                _("Fine-tune AMD ACO shader compiler behavior"),
                _("Enable ACO Debug"),
                _("Apply low-level shader compiler flags and overrides"),
                keys,
                display_opts,
                value_opts,
                tooltips,
                ",",
                "ACO_DEBUG",
                false
            );
        }
    }
}
