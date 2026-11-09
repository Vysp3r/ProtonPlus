namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class LaunchOptionVKD3DConfig : LaunchOptionCustomPairs {

        public LaunchOptionVKD3DConfig () {

            var keys = LaunchOptionFlags.values ("vkd3d-config");

            string[] display_opts = { _("Disabled"), _("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = LaunchOptionFlags.descriptions ("vkd3d-config");

            base (
                _("VKD3D Proton Configurations"),
                _("Configure Direct3D 12 to Vulkan translation behavior"),
                _("Enable VKD3D Option"),
                _("Test specific Direct3D 12 compatibility workarounds and optimizations"),
                keys,
                display_opts,
                value_opts,
                tooltips,
                ",",
                "VKD3D_CONFIG",
                false
            );
        }
    }
}
