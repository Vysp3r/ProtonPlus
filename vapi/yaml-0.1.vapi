namespace ProtonPlus.Services {
    [Compact]
    [CCode (cname = "LutrisYaml", cprefix = "lutris_yaml_", free_function = "lutris_yaml_free",
            cheader_filename = "services/lutris/lutris-yaml.h")]
    internal class LutrisYaml {
        public static LutrisYaml? parse (string source);
        public bool has_scalar (string section, string key);
        public bool has_setting (string section, string key);
        public unowned string? get (string section, string key);
        public bool setting_editable (string section, string setting);
        public int get_toggle (string section, string setting);
        public bool toggle_editable (string section, string setting);
        public string? set_setting (string section, string setting, string? value, bool boolean = false);
        public string? get_environment ();
        public string? set_environment (string? mapping_json);
    }
}
