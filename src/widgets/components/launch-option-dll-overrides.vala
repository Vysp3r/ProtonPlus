namespace ProtonPlus.Widgets.Components {
    using Adw;
    using Gtk;

    public class LaunchOptionDllOverrides : LaunchOptionCustomPairs {

        public LaunchOptionDllOverrides () {
            string[] default_dlls = { 
                "mscoree", 
                "d3d9",
                "d3d10",
                "d3d11", 
                "d3d12",
                "wined3d",
                "d3d9ongl",
                "d3dcompiler_47",
                "dxgi",
                "dsound",
                "ddraw", 
                "mshtml",
                "xaudio2_7",
                "xaudio2_9",
                "openal32",
                "dinput8",
                "winhttp",
                "urlmon",
                "wininet",
                "binkw32",
                "bink2w64",
                "gdi32",
                "usp10",
                "comctl32",
            };
            
            string[] dll_display = { 
                _("Disabled"), 
                "Native (n)", 
                "Builtin (b)", 
                "Native, Builtin (n,b)", 
                "Builtin, Native (b,n)" 
            };
            
            string[] dll_values = { "", "n", "b", "n,b", "b,n" };

            var tooltips = new HashTable<string, string> (str_hash, str_equal);
            tooltips.insert ("mscoree", _(".NET Framework runtime execution engine"));
            tooltips.insert ("d3d9", _("Direct3D 9 graphics API (often overridden for mods/wrappers)"));
            tooltips.insert ("d3d10", _("Direct3D 10 graphics API library"));
            tooltips.insert ("d3d11", _("Direct3D 11 graphics API library (DXVK)"));
            tooltips.insert ("d3d12", _("Direct3D 12 graphics API layer (VKD3D)"));
            tooltips.insert ("wined3d", _("Wine's internal OpenGL-based DirectX translator"));
            tooltips.insert ("d3d9ongl", _("Special D3D9 to OpenGL translation wrapper"));
            tooltips.insert ("d3dcompiler_47", _("Microsoft HLSL Shader Compiler (fixes shader crashes)"));
            tooltips.insert ("dxgi", _("DirectX Graphics Infrastructure (required for ReShade/SpecialK)"));
            tooltips.insert ("dsound", _("DirectSound library (fixes audio mixing and 3D sound)"));
            tooltips.insert ("ddraw", _("DirectDraw (critical for older 2D/3D games and patches)"));
            tooltips.insert ("mshtml", _("MSHTML web rendering engine for built-in game launchers"));
            tooltips.insert ("xaudio2_7", _("XAudio 2.7 audio library (fixes crackling or missing sound)"));
            tooltips.insert ("xaudio2_9", _("XAudio 2.9 audio library for modern Windows 10/11 games"));
            tooltips.insert ("openal32", _("OpenAL 3D Audio library (enables hardware sound acceleration)"));
            tooltips.insert ("dinput8", _("DirectInput 8 (commonly used to inject scripts/ASI mod loaders)"));
            tooltips.insert ("winhttp", _("Windows Internet HTTP API (fixes network connectivity in launchers)"));
            tooltips.insert ("urlmon", _("OLE Monkers library for URL handling and launcher updates"));
            tooltips.insert ("wininet", _("Windows Internet API layer (fixes online features in game launchers)"));
            tooltips.insert ("binkw32", _("Bink Video 32-bit decoder (fixes intro movie crashes)"));
            tooltips.insert ("bink2w64", _("Bink Video 64-bit decoder (fixes intro movie crashes in modern games)"));
            tooltips.insert ("gdi32", _("Graphics Device Interface (helps with custom fonts and rendering)"));
            tooltips.insert ("usp10", _("Uniscribe Script Processor (fixes Asian text / custom localization rendering)"));
            tooltips.insert ("comctl32", _("Common Controls Library (needed for custom game launchers)"));

            base (
                _("Wine DLL Overrides"),
                _("Manage library overrides (builtin/native)"),
                _("Enable DLL Overrides"),
                _("Bypass or prefer specific Windows DLLs"),
                default_dlls,
                dll_display,
                dll_values,
                tooltips
            );
        }
    }
}