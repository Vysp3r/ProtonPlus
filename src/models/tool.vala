namespace ProtonPlus.Models {
    public abstract class Tool : Object {
        // This is a serialized runtime identity.  Its components remain
        // available through group and provider_id.
        public string id { get; internal set; default = ""; }
        public string provider_id { get; internal set; default = ""; }
        public string source_id { get; internal set; default = ""; }
        public string title { get; set; }
        public string description { get; set; }
        public Group group { get; set; }
        public bool legacy { get; set; }
        public int sort_priority { get; set; default = 1000; }
        public bool installed { get; private set; default = false; }
        public bool used { get; private set; default = false; }
        public InstalledToolEntry? resolved_installed_entry { get; private set; default = null; }
        internal string? resolved_usage_identifier { get; private set; default = null; }
        public ReleaseCatalog? release_catalog { get; private set; default = null; }
        public Gee.LinkedList<Variant> variants { get; set; default = new Gee.LinkedList<Variant> (); }

        construct {
            if (variants == null)
                variants = new Gee.LinkedList<Variant> ();
        }

        internal void set_identity (string provider_id, string source_id) {
            this.provider_id = provider_id;
            this.source_id = source_id;
            this.id = "%s/%s/%s".printf (group.launcher.instance_id, group.id, provider_id);
        }

        protected void initialize_release_catalog (ReleaseCatalog catalog) {
            release_catalog = catalog;
        }

        public virtual bool is_installed () {
            return installed;
        }

        public virtual bool is_used () {
            return used;
        }

        internal void set_resolved_installation_state (
            InstalledToolEntry? entry,
            string? usage_identifier,
            bool is_used
        ) {
            resolved_installed_entry = entry;
            resolved_usage_identifier = usage_identifier;
            installed = entry != null;
            used = installed && is_used;
        }

        public string? last_version {
            owned get {
                return release_catalog != null ? release_catalog.last_version : "";
            }
        }

    }
}
