namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
using Adw;
using Gtk;

    public class LaunchOptionRadvDebug : LaunchOptionCustomPairs {

        public LaunchOptionRadvDebug () {

            string[] keys = { "nocng", "noabin", "nobg", "nodcc", "novrs", "nogpl", "noexecbuf2", "precompile", "noatc" };

            string[] display_opts = { _ ("Disabled"), _ ("Enabled (Enforce)") };
            string[] value_opts = { "", "1" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);
            tooltips.insert ("nocng", _ ("Disables Next-Gen Geometry (NGG). Fixes crashes in older Vulkan games."));
            tooltips.insert ("noabin", _ ("Disables internal application binary interface caching."));
            tooltips.insert ("nobg", _ ("Disables background shader compilation."));
            tooltips.insert ("nodcc", _ ("Disables Delta Color Compression. Can fix specific rendering artifacts."));
            tooltips.insert ("novrs", _ ("Disables Variable Rate Shading (VRS). Fixes UI artifacts in some games."));
            tooltips.insert ("nogpl", _ ("Disables Graphics Pipeline Library (GPL) to troubleshoot startup crashes."));
            tooltips.insert ("noexecbuf2", _ ("Forces fallback command submission mode. Helps diagnosing GPU hangs."));
            tooltips.insert ("novrs", _ ("Disables Vertex Runtime Shading. Can fix specific rendering artifacts."));
            tooltips.insert ("precompile", _ ("Precompiles shaders during loading screens to reduce in-game stuttering."));
            tooltips.insert ("noatc", _ ("Disables AMD Texture Compression. Fixes texture glitches on APUs and Steam Deck."));

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
                    "RADV_DEBUG"
            );
        }
    }
}