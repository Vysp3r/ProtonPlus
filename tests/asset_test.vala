namespace AppTests.AssetTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Assets;

    public void register_tests () {
        Test.add_func ("/assets/canonical-metadata", test_canonical_metadata);
        Test.add_func ("/assets/release-size-delegates-to-asset", test_release_size_delegates_to_asset);
        Test.add_func ("/assets/release-cache-size-compatibility", test_release_cache_size_compatibility);
    }

    private Json.Object object_from_json (string content) {
        try {
            var root = Json.from_string (content);
            assert (root.get_node_type () == Json.NodeType.OBJECT);
            return root.get_object ();
        } catch (Error e) {
            critical ("Could not parse asset fixture: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_canonical_metadata () {
        var asset = new Asset (
            "runner.tar.xz", "https://example.test/runner.tar.xz", 4294967296
        );
        assert (asset.name == "runner.tar.xz");
        assert (asset.download_url == "https://example.test/runner.tar.xz");
        assert (asset.download_size == 4294967296);
        assert (asset.is_archive ());

        var generated = Asset.from_download_url (
            "https://example.test/downloads/generated.zip?signature=fixture"
        );
        assert (generated.name == "generated.zip");
        assert (generated.download_size == 0);
    }

    private void test_release_size_delegates_to_asset () {
        var source_asset = new Asset ("source.tar.gz", "https://example.test/source.tar.gz", 91);
        var source_release = new Release ("source", "", "", source_asset, "", null, "source", "source");
        assert (source_release.download_size == 91);
        assert (source_release.download_size == source_release.asset.download_size);

        var legacy_release = new Release (
            "legacy", "", "", new Asset ("legacy.tar.gz", "https://example.test/legacy.tar.gz"), "", 42,
            "legacy", "legacy"
        );
        assert (legacy_release.download_size == 42);
        assert (legacy_release.download_size == legacy_release.asset.download_size);
    }

    private void test_release_cache_size_compatibility () {
        var existing_cache = object_from_json (
            "{\"kind\":\"generic\",\"title\":\"cached\",\"asset\":{\"name\":\"cached.tar.gz\",\"download_url\":\"https://example.test/cached.tar.gz\"},\"download_size\":77,\"upstream_release_id\":\"77\",\"variants\":[]}"
        );
        var loaded = Release.from_json (existing_cache);
        assert (loaded != null);
        var cached = (!) loaded;
        assert (cached.download_size == 77);
        assert (cached.asset.download_size == 77);

        var serialized = cached.to_json ();
        assert (serialized.get_int_member ("download_size") == 77);
        var serialized_asset = serialized.get_object_member ("asset");
        assert (serialized_asset != null);
        assert (serialized_asset.get_string_member ("name") == "cached.tar.gz");
        assert (serialized_asset.get_string_member ("download_url") == "https://example.test/cached.tar.gz");
        assert (!serialized_asset.has_member ("download_size"));
        var round_trip = Release.from_json (serialized);
        assert (round_trip != null);
        var reloaded = (!) round_trip;
        assert (reloaded.asset.name == "cached.tar.gz");
        assert (reloaded.asset.download_url == "https://example.test/cached.tar.gz");
        assert (reloaded.asset.download_size == 77);

        var cache_without_size = object_from_json (
            "{\"kind\":\"generic\",\"title\":\"no-size\",\"asset\":{\"name\":\"no-size.tar.gz\",\"download_url\":\"https://example.test/no-size.tar.gz\"},\"source_tag\":\"no-size\",\"variants\":[]}"
        );
        var loaded_without_size = Release.from_json (cache_without_size);
        assert (loaded_without_size != null);
        var without_size = (!) loaded_without_size;
        assert (without_size.download_size == 0);
        assert (without_size.asset.download_size == 0);
    }
}
