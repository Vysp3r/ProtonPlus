namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    public class LaunchOptionFlag : Object {
        public string key { get; private set; }
        public string description { get; private set; }

        public LaunchOptionFlag (string key, string description) {
            this.key = key;
            this.description = description;
        }
    }

    // Shared by the semantic catalog and the flag editors. See docs/launch-options.md
    // for upstream references; existing commands are preserved by LaunchCommandWriter.
    public class LaunchOptionFlags : Object {
        public static LaunchOptionFlag[] choices (string id) {
            switch (id) {
                case "vkd3d-config": return {
                    new LaunchOptionFlag ("vk_debug", _("Loads Vulkan validation layers and enables debug extensions.")),
                    new LaunchOptionFlag ("skip_application_workarounds", _("Turns off game-specific workarounds for debugging.")),
                    new LaunchOptionFlag ("nodxr", _("Turns off DirectX Raytracing support.")),
                    new LaunchOptionFlag ("dxr", _("Forces DirectX Raytracing support even when considered unsafe.")),
                    new LaunchOptionFlag ("dxr12", _("Enables experimental DXR 1.2 support when opacity micromaps are available.")),
                    new LaunchOptionFlag ("force_static_cbv", _("Uses an unsafe constant-buffer optimization intended for NVIDIA GPUs.")),
                    new LaunchOptionFlag ("single_queue", _("Uses one queue instead of asynchronous compute and transfer queues.")),
                    new LaunchOptionFlag ("no_upload_hvv", _("Prevents upload heaps from using CPU-visible video memory. May reduce GPU performance.")),
                    new LaunchOptionFlag ("force_host_cached", _("Uses cached memory for host-visible allocations to speed up captures.")),
                    new LaunchOptionFlag ("no_invariant_position", _("Turns off the invariant-position workaround.")),
                    new LaunchOptionFlag ("pipeline_library_app_cache", _("Lets the application manage pipeline caches instead of using the automatic shader cache."))
                };
                case "amd-radv-perftest": return {
                    new LaunchOptionFlag ("cswave32", _("Uses 32-thread waves for compute shaders on GFX10 and newer GPUs.")),
                    new LaunchOptionFlag ("dccmsaa", _("Enables Delta Color Compression for multisampled images.")),
                    new LaunchOptionFlag ("dmashaders", _("Uploads shaders to video memory that the CPU cannot directly access.")),
                    new LaunchOptionFlag ("gewave32", _("Uses 32-thread waves for vertex, tessellation, and geometry shaders on GFX10 and newer GPUs.")),
                    new LaunchOptionFlag ("localbos", _("Enables local buffer objects.")),
                    new LaunchOptionFlag ("lowlatencydec", _("Enables low-latency video decoding.")),
                    new LaunchOptionFlag ("lowlatencyenc", _("Enables low-latency video encoding.")),
                    new LaunchOptionFlag ("nggc", _("Enables Next-Gen Geometry culling on GFX11 and newer GPUs.")),
                    new LaunchOptionFlag ("nircache", _("Caches intermediate shader code for individual graphics pipeline stages.")),
                    new LaunchOptionFlag ("nogttspill", _("Prevents memory allocations from spilling into system memory through GTT.")),
                    new LaunchOptionFlag ("nosam", _("Disables optimizations for systems whose entire video memory is CPU-visible.")),
                    new LaunchOptionFlag ("pswave32", _("Uses 32-thread waves for pixel shaders on GFX10 and newer GPUs.")),
                    new LaunchOptionFlag ("rtcps", _("Uses continuation-passing lowering for ray tracing instead of function calls."))
                };
                case "amd-radv-debug": return {
                    new LaunchOptionFlag ("hang", _("Detects GPU hangs and writes a diagnostic report.")),
                    new LaunchOptionFlag ("syncshaders", _("Synchronizes shader execution after every draw and dispatch.")),
                    new LaunchOptionFlag ("nocache", _("Turns off shader caching.")),
                    new LaunchOptionFlag ("nodcc", _("Turns off Delta Color Compression for images.")),
                    new LaunchOptionFlag ("nogpl", _("Turns off Vulkan graphics pipeline libraries.")),
                    new LaunchOptionFlag ("psocachestats", _("Reports pipeline cache hits and misses to inspect shader precompilation."))
                };
                case "amd-aco-debug": return {
                    new LaunchOptionFlag ("validateir", _("Checks the shader compiler intermediate representation during compilation.")),
                    new LaunchOptionFlag ("perfinfo", _("Prints information used to calculate pipeline statistics.")),
                    new LaunchOptionFlag ("force-waitcnt", _("Forces wait instructions whenever outstanding operations need to finish.")),
                    new LaunchOptionFlag ("nosched", _("Turns off instruction scheduling for compiler debugging."))
                };
                default: return {};
            }
        }

        public static string[] values (string id) {
            string[] result = {};
            foreach (var choice in choices (id))
                result += choice.key;
            return result;
        }

        public static HashTable<string, string> descriptions (string id) {
            var result = new HashTable<string, string> (str_hash, str_equal);
            foreach (var choice in choices (id))
                result.insert (choice.key, choice.description);
            return result;
        }
    }
}
