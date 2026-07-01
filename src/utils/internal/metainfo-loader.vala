namespace ProtonPlus.Utils.Internal {
    using AppStream;
    public class MetaInfoLoader : Object {
        Models.Internal.MetaInfo? model = null;

        public MetaInfoLoader () {
        }

        private GLib.File? get_metafile () {
            var file = GLib.File.new_for_path ("/usr/share/metainfo/com.vysp3r.ProtonPlus.metainfo.xml");

            if (!file.query_exists ()) {
                file = GLib.File.new_for_path ("data/com.vysp3r.ProtonPlus.metainfo.xml");
            }

            if (!file.query_exists ()) {
                file = GLib.File.new_for_path ("../data/com.vysp3r.ProtonPlus.metainfo.xml");
            }

            if (!file.query_exists ()) {
                warning ("Metainfo file not found!");
                return null;
            }

            return file;
        }

        public Models.Internal.MetaInfo? load () {
            GLib.File? file = get_metafile ();
            if (file == null)return null;

            var mdata = new AppStream.Metadata ();

            try {
                mdata.parse_file (file, AppStream.FormatKind.XML);
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
                    GLib.DateTime date;
                    string? date_str;

                    if (date_timestamp == null) {
                        date_str = null;
                    } else {
                        date = new GLib.DateTime.from_unix_local ((int64) date_timestamp);
                        date_str = date.format ("%Y-%m-%d");
                    }

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
