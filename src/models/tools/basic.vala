namespace ProtonPlus.Models.Tools {
    public abstract class Basic : Tool {
        internal ProtonPlus.Models.Launchers.Runners.IRunner? source_runner { get; set; }
        internal string endpoint { get; set; }
        internal string directory_name_format { get; set; }
        public string tag { get; set; }

        public virtual string get_directory_name (string release_name) {
            if (release_name.contains ("Latest"))
                return release_name;

            var directory_name = new StringBuilder (directory_name_format);

            directory_name.replace ("$release_name", release_name);
            directory_name.replace ("$title", title);

            if (directory_name.len > 0 && directory_name.str[0] == '_') {
                directory_name.replace ("_", "", 1);
                directory_name.str = directory_name.str.ascii_down ();
            }

            if (directory_name.len > 0 && directory_name.str[0] == '!') {
                directory_name.replace ("!", "", 1);
                var split = directory_name.str.split (":");
                directory_name.str = split[0].replace (split[1], split[2]);
            }

            if (directory_name.len > 0 && directory_name.str[0] == '&') {
                directory_name.replace ("&", "", 1);
                var split = directory_name.str.split (":");
                directory_name.str = split[0].contains (split[1]) ? split[2] : split[3];
            }

            return directory_name.str;
        }

        private string render_variant_asset_name (Variant variant, string release_name, string tag_name) {
            var asset_name = new StringBuilder (variant.format);
            asset_name.replace ("$title", title);
            asset_name.replace ("$release_name", release_name);
            asset_name.replace ("$tag_name", tag_name);
            return asset_name.str;
        }

        private string get_archive_stem (string asset_name) {
            string[] archive_extensions = {
                "tar.gz",
                "tgz",
                "tar.xz",
                "tar.bz2",
                "tbz2",
                "tar.zst",
                "tzst",
                "zip",
                "7z",
                "rar"
            };

            var lowered_name = asset_name.ascii_down ();
            foreach (var extension in archive_extensions) {
                var suffix = ".%s".printf (extension);
                if (lowered_name.has_suffix (suffix)) {
                    return asset_name.substring (0, asset_name.length - suffix.length);
                }
            }

            return asset_name;
        }

        private bool variant_matches_asset (string expected_asset_name, string asset_name) {
            if (asset_name == expected_asset_name)
                return true;

            return get_archive_stem (asset_name) == expected_asset_name;
        }

        public virtual Gee.LinkedList<Variant> create_release_variants (
            string release_name,
            string tag_name,
            Gee.LinkedList<ProtonPlus.Models.Internal.Assets.IAsset> assets,
            string? fallback_download_url = null
        ) {
            var release_variants = new Gee.LinkedList<Variant> ();

            foreach (var variant in this.variants) {
                string? variant_download_url = null;
                var expected_asset_name = render_variant_asset_name (variant, release_name, tag_name);

                foreach (var asset in assets) {
                    if (variant_matches_asset (expected_asset_name, asset.name)) {
                        variant_download_url = asset.download_url;
                        break;
                    }
                }

                if (variant_download_url == null && variant.is_default) {
                    variant_download_url = fallback_download_url;
                }

                release_variants.add (new Variant (variant.name, variant.format, variant.is_default, this, variant_download_url));
            }

            return release_variants;
        }

        public string? get_default_variant_download_url (Gee.LinkedList<Variant> release_variants, string? fallback_download_url = null) {
            foreach (var variant in release_variants) {
                if (variant.is_default && variant.download_url != null && variant.download_url != "") {
                    return variant.download_url;
                }
            }

            return fallback_download_url;
        }

        public virtual void update_variant_download_url (string release_name) {
            foreach (var variant in this.variants) {
                var url = new StringBuilder (variant.format);
                url.replace ("$title", title);
                url.replace ("$release_name", release_name);
                variant.download_url = url.str;
            }
        }

        public override bool is_installed () {
            var directories = group.get_tool_directories ();
            foreach (var directory in directories) {
                if (directory.contains (title))return true;
            }
            return false;
        }

        public override bool is_used () {
            var directories = group.get_tool_directories ();
            foreach (var directory in directories) {
                if (directory.contains (title)) {
                    if (group.launcher.get_compatibility_tool_usage_count (directory) > 0)return true;
                }
            }
            return false;
        }

        public bool is_asset_exclude (string title, string[]? exclude_asset) {
            if (exclude_asset == null) return false;

            var excluded = false;

            foreach (var excluded_asset in exclude_asset) {
                if (title.contains (excluded_asset)) {
                    excluded = true;
                    break;
                }
            }

            return excluded;
        }
    }
}
