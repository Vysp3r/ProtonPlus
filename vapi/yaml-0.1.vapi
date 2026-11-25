namespace ProtonPlus.Services {
    [Compact]
    [CCode (cname = "LutrisYaml", cprefix = "lutris_yaml_", free_function = "lutris_yaml_free",
            cheader_filename = "services/lutris/lutris-yaml.h")]
    internal class LutrisYaml {
        public static LutrisYaml? parse (string source);
        public bool has_scalar (string section, string key);
        public unowned string? get (string section, string key);
        public bool version_editable ();
        public string? set_version (string? version);
    }
}
