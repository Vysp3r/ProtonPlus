namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class LaunchOptionAcoDebug : LaunchOptionCustomPairs {

        public LaunchOptionAcoDebug () {

            string[] keys = { "validate", "nofpgather", "perfinfo", "force-isel", "nosched", "nowave32" };

            string[] display_opts = { _("Disabled"), _("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);
            tooltips.insert ("validate", _("Validates the compiler's internal representation after each pass. Used for driver debugging."));
            tooltips.insert ("nofpgather", _("Disables FP gathering optimizations. Workaround for specific texture issues in older games."));
            tooltips.insert ("perfinfo", _("Prints detailed compilation performance stats and register usage to system log."));
            tooltips.insert ("force-isel", _("Forces the use of the instruction selector pass even when it could be bypassed."));
            tooltips.insert ("nosched", _("Disables the instruction scheduling pass. Can help isolate compiler bugs."));
            tooltips.insert ("nowave32", _("Forces Wave64 mode execution on RDNA hardware instead of the default Wave32."));

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
                  "ACO_DEBUG"
            );
        }
    }
}