namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class LaunchOptionAmdIcd : LaunchOptionCustomPairs {

        public LaunchOptionAmdIcd () {
            string[] keys = { "driver" };

            string[] display_opts = {
                _ ("System Default"),
                "Mesa RADV (RADV)",
                "AMD Proprietary (AMDVLK)"
            };

            string[] value_opts = { "", "RADV", "AMDVLK" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);
            tooltips.insert ("driver", _ ("Switch between open-source Mesa driver and official AMDVLK driver."));

            base (
                    _ ("AMD Vulkan ICD Driver"),
                    _ ("Select preferred Vulkan driver implementation"),
                    _ ("Force Vulkan Driver"),
                    _ ("Override system-wide Vulkan driver preference for this game"),
                    keys,
                    display_opts,
                    value_opts,
                    tooltips,
                    ",",
                    "AMD_ICD"
            );
        }
    }
}