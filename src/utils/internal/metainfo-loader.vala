namespace ProtonPlus.Utils.Internal {
    using AppStream;
    public class MetaInfoLoader : Object {
        Models.Internal.MetaInfo? model = null;

        public MetaInfoLoader () {
        }

        private GLib.File? get_metafile () {

            string[] files = {
                "/usr/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml",
                "data/com.vysp3r.ProtonPlus.metainfo.xml",
                "../data/com.vysp3r.ProtonPlus.metainfo.xml",
                "/usr/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml.in",
                "data/com.vysp3r.ProtonPlus.metainfo.xml.in",
                "../data/com.vysp3r.ProtonPlus.metainfo.xml.in"
            };

            foreach (var item in files) {
                var file = GLib.File.new_for_path (item);
                if (file.query_exists ()) {
                    return file;
                }
            }

            warning ("Metainfo file not found!");
            return null;
        }

        private string? normalize_release_date (string? raw_date) {
            if (raw_date == null || raw_date == "") {
                return null;
            }

            // AppStream dates are usually ISO strings, but some sources may provide unix timestamps.
            var iso_date = new DateTime.from_iso8601 (raw_date, null);
            if (iso_date != null) {
                return iso_date.format ("%Y-%m-%d");
            }

            int64 unix_timestamp = 0;
            if (int64.try_parse (raw_date, out unix_timestamp)) {
                var unix_date = new DateTime.from_unix_local (unix_timestamp);
                if (unix_date != null) {
                    return unix_date.format ("%Y-%m-%d");
                }
            }

            return raw_date;
        }

        public Models.Internal.MetaInfo? load () {
            var mdata = new AppStream.Metadata ();

            try {
                // Try to load from gresource first
                var resource_file = GLib.File.new_for_uri ("resource:///com/vysp3r/ProtonPlus/metainfo.xml");
                if (resource_file.query_exists ()) {
                    mdata.parse_file (resource_file, AppStream.FormatKind.XML);
                } else {
                    // Fallback to filesystem
                    GLib.File? file = get_metafile ();
                    if (file == null)return null;
                    mdata.parse_file (file, AppStream.FormatKind.XML);
                }
                var component = mdata.get_component ();
                if (component == null)return null;

                model = new Models.Internal.MetaInfo ();

                model.id = component.id;
                model.name = component.name;
                model.summary = component.summary;
                model.metadata_license = component.get_metadata_license ();
                model.project_license = component.project_license;

                var releases = component.get_releases_plain ();

                foreach (var rel in releases.get_entries ()) {
                    if (rel == null)continue;

                    string version = rel.get_version ();

                    string? date_timestamp = rel.get_date ();
                    string? date_str = normalize_release_date (date_timestamp);

                    string description = rel.get_description () ?? "";

                    var release = new Models.Internal.MetaInfoRelease ();
                    release.description = description;
                    release.date = date_str;
                    release.version = version;
                    model.releases.add (release);
                }

                return model;
            } catch (Error e) {
                warning ("Parsing metainfo failed: %s", e.message);
                return null;
            }
        }
    }
}
