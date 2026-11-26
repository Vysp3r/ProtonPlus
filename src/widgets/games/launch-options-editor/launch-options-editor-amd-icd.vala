namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    public class LaunchOptionAmdIcd : LaunchOptionEnvCombo {
        public LaunchOptionAmdIcd () {
            base (
                "AMD_VULKAN_ICD",
                _("Vulkan driver"),
                _("Chooses the AMD Vulkan driver through the installed switchable graphics layer."),
                { _("System Default"), "Mesa RADV", "AMDVLK" },
                { "", "RADV", "AMDVLK" }
            );
        }
    }
}
