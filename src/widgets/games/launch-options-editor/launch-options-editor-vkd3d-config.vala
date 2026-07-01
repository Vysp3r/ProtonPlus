namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Adw;
    using Gtk;

    public class LaunchOptionVKD3DConfig : LaunchOptionCustomPairs {

        public LaunchOptionVKD3DConfig () {

            string[] keys = {
                "shader_cache",
                "force_host_cache",
                "no_upload_hvv",
                "upload_hvv",
                "nodxr",
                "dxr11",
                "dxr10",
                "bvh_force_cpu",
                "force_combined_providers",
                "gpuva",
                "no_alloc_view_descriptor_caches",
                "stable_power_state",
                "force_compute_root_parameters",
                "unaligned_stencil_clear"
            };

            string[] display_opts = { _("Disabled"), _("Enabled") };
            string[] value_opts = { "", "1" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);
            tooltips.insert ("shader_cache", _("Enables VKD3D's internal shader cache on disk. Drastically reduces micro-stuttering and speeds up consecutive loading times."));
            tooltips.insert ("force_host_cache", _("Forces VKD3D to use system RAM instead of VRAM for caching shader compilation data, ensuring smoother data stream between CPU and GPU."));
            tooltips.insert ("upload_hvv", _("Uses host-visible VRAM for staging buffers. Drastically reduces stuttering if Resizable BAR / SAM is enabled."));
            tooltips.insert ("no_upload_hvv", _("Disables host-visible VRAM staging buffers. Use as a compatibility fallback if experiencing memory-related crashes."));
            tooltips.insert ("nodxr", _("Disables D3D12 Ray Tracing (DXR) capabilities entirely. Significantly improves performance and stability on GPUs without strong hardware RT support."));
            tooltips.insert ("dxr11", _("Exposes D3D12 Ray Tracing (DXR 1.1 and 1.0) capabilities to the game via Vulkan extensions."));
            tooltips.insert ("dxr10", _("Restricts Ray Tracing capabilities to DXR 1.0 only. Useful for older RT games that crash with DXR 1.1."));
            tooltips.insert ("bvh_force_cpu", _("Forces Ray Tracing BVH acceleration structures to be built on the CPU instead of the GPU. Severe performance impact!"));
            tooltips.insert ("force_combined_providers", _("Aggressively unifies memory allocators for textures and buffers to save a small amount of VRAM."));
            tooltips.insert ("gpuva", _("Enables advanced GPU Virtual Addressing to improve Direct3D 12 memory mapping in massive open-world games."));
            tooltips.insert ("no_alloc_view_descriptor_caches", _("Disables descriptor caches. Workaround for specific games suffering from memory leaks."));
            tooltips.insert ("stable_power_state", _("Forces the GPU to maintain stable clock rates. Intended for accurate benchmarking only."));
            tooltips.insert ("force_compute_root_parameters", _("Alters how root parameters are passed to compute shaders. Can fix specific rendering glitches."));
            tooltips.insert ("unaligned_stencil_clear", _("Allows unaligned stencil buffer clears. Workaround for certain older Direct3D 12 renderers."));

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
                  "VKD3D_CONFIG"
            );
        }
    }
}
