namespace ProtonPlus.Models {
    /// Provider-neutral remote release metadata.  Installation state belongs to
    /// Services.InstallJob; keeping this object free of a target context makes
    /// browse results, update discovery, and cache entries interchangeable.
    public class Release : Object {
        public enum Kind {
            GENERIC,
            GITHUB_ACTION,
            STEAM_TINKER_LAUNCH,
        }

        public string title { get; private set; }
        public string description { get; private set; }
        public string release_date { get; private set; }
        public Assets.Asset asset { get; private set; }
        public string page_url { get; private set; }
        // Upstream values are opaque and must never be inferred from title.
        public string upstream_release_id { get; private set; default = ""; }
        public string source_tag { get; private set; default = ""; }
        public int64 download_size { get; private set; default = 0; }
        public Kind kind { get; private set; default = Kind.GENERIC; }
        // This is remote-provider metadata, not an installation concern.
        public string artifacts_url { get; private set; default = ""; }
        // A collection is deliberately retained for per-target variant asset
        // selection.  It contains catalog data only.
        public Gee.LinkedList<Variant> variants { get; private set; }

        public Release (
            string title,
            string description,
            string release_date,
            Assets.Asset asset,
            string page_url,
            int64 download_size = 0,
            string upstream_release_id = "",
            string source_tag = "",
            Kind kind = Kind.GENERIC,
            string artifacts_url = ""
        ) {
            this.title = title;
            this.description = description;
            this.release_date = release_date;
            this.asset = asset;
            this.page_url = page_url;
            this.download_size = download_size;
            this.upstream_release_id = upstream_release_id;
            this.source_tag = source_tag;
            this.kind = kind;
            this.artifacts_url = artifacts_url;
            this.variants = new Gee.LinkedList<Variant> ();
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            obj.set_string_member ("kind", kind_to_string (kind));
            obj.set_string_member ("title", title);
            obj.set_string_member ("description", description);
            obj.set_string_member ("release_date", release_date);
            obj.set_object_member ("asset", asset.to_json ());
            obj.set_string_member ("page_url", page_url);
            obj.set_string_member ("upstream_release_id", upstream_release_id);
            obj.set_string_member ("source_tag", source_tag);
            obj.set_int_member ("download_size", download_size);
            if (artifacts_url != "")
                obj.set_string_member ("artifacts_url", artifacts_url);

            var variants_array = new Json.Array ();
            foreach (var variant in variants) {
                var variant_obj = new Json.Object ();
                variant_obj.set_string_member ("id", variant.id);
                variant_obj.set_string_member ("name", variant.name);
                variant_obj.set_string_member ("format", variant.format);
                variant_obj.set_boolean_member ("default", variant.is_default);
                variant_obj.set_string_member ("download_url", variant.download_url ?? "");
                variants_array.add_object_element (variant_obj);
            }
            obj.set_array_member ("variants", variants_array);
            return obj;
        }

        public static Release? from_json (Json.Object? obj) {
            if (obj == null || !obj.has_member ("kind") || !obj.has_member ("title") || !obj.has_member ("asset"))
                return null;

            var asset_node = obj.get_member ("asset");
            if (asset_node == null || asset_node.get_node_type () != Json.NodeType.OBJECT)
                return null;

            var asset = Assets.Asset.from_json (asset_node.get_object ());
            if (asset == null)
                return null;

            var title = obj.get_string_member_with_default ("title", "");
            var source_tag = obj.get_string_member_with_default ("source_tag", "");
            var upstream_release_id = obj.get_string_member_with_default ("upstream_release_id", "");
            var kind_string = obj.get_string_member_with_default ("kind", "");
            if (title == "" || (upstream_release_id == "" && source_tag == ""))
                return null;

            // Older cache entries may contain the former virtual Latest row.
            // It is a target projection now, so never restore it as catalog data.
            if (kind_string == "latest")
                return null;

            var release = new Release (
                title,
                obj.get_string_member_with_default ("description", ""),
                obj.get_string_member_with_default ("release_date", ""),
                asset,
                obj.get_string_member_with_default ("page_url", ""),
                obj.has_member ("download_size") ? obj.get_int_member ("download_size") : 0,
                upstream_release_id,
                source_tag,
                kind_from_string (kind_string),
                obj.get_string_member_with_default ("artifacts_url", "")
            );

            var variants_array = obj.get_array_member ("variants");
            if (variants_array != null) {
                for (var i = 0; i < variants_array.get_length (); i++) {
                    var variant_obj = variants_array.get_object_element (i);
                    if (variant_obj == null)
                        continue;

                    var name = variant_obj.get_string_member_with_default ("name", "");
                    if (name == "")
                        continue;
                    release.variants.add (new Variant (
                        variant_obj.get_string_member_with_default ("id", ""),
                        name,
                        variant_obj.get_string_member_with_default ("format", ""),
                        variant_obj.has_member ("default") && variant_obj.get_boolean_member ("default"),
                        variant_obj.get_string_member_with_default ("download_url", "")
                    ));
                }
            }
            return release;
        }

        public static string kind_to_string (Kind kind) {
            switch (kind) {
            case Kind.GITHUB_ACTION:
                return "github-action";
            case Kind.STEAM_TINKER_LAUNCH:
                return "steam-tinker-launch";
            default:
                return "generic";
            }
        }

        public static Kind kind_from_string (string kind) {
            switch (kind) {
            case "github-action":
                return Kind.GITHUB_ACTION;
            case "steam-tinker-launch":
                return Kind.STEAM_TINKER_LAUNCH;
            default:
                return Kind.GENERIC;
            }
        }
    }
}
