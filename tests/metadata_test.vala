namespace AppTests.MetadataTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Models.Providers;

    public void register_tests () {
        Test.add_func ("/protonplus-metadata/saves-and-loads", test_saves_and_loads);
        Test.add_func ("/protonplus-metadata/loads-legacy-fields", test_loads_legacy_fields);
        Test.add_func ("/protonplus-installed-discovery/prefers-ids-and-upgrades-unambiguous-legacy-metadata", test_installed_discovery);
    }

    private string create_temp_directory () {
        try {
            return DirUtils.make_tmp ("protonplus-metadata-test-XXXXXX");
        } catch (FileError e) {
            critical ("Could not create test directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_saves_and_loads () {
        var directory = create_temp_directory ();
        var metadata = ProtonPlus.Utils.Metadata.load (directory);
        metadata.runner_endpoint = "https://example.test/releases";
        metadata.runner_title = "Example Runner";
        metadata.tag = "v1.2.3";
        metadata.provider_id = "example-provider";
        metadata.tool_id = "example-system/proton/example-provider";
        metadata.launcher_id = "example-system";
        metadata.variant_id = "x86-64";
        metadata.release_id = "1001";

        assert (metadata.save (directory));
        assert (FileUtils.test (Path.build_filename (directory, ".protonplus"), FileTest.IS_REGULAR));

        var loaded_metadata = ProtonPlus.Utils.Metadata.load (directory);
        assert (loaded_metadata.runner_endpoint == "https://example.test/releases");
        assert (loaded_metadata.runner_title == "Example Runner");
        assert (loaded_metadata.tag == "v1.2.3");
        assert (loaded_metadata.provider_id == "example-provider");
        assert (loaded_metadata.tool_id == "example-system/proton/example-provider");
        assert (loaded_metadata.launcher_id == "example-system");
        assert (loaded_metadata.variant_id == "x86-64");
        assert (loaded_metadata.release_id == "1001");

        ProtonPlus.Utils.Filesystem.delete_file (Path.build_filename (directory, ".protonplus"));
        try {
            File.new_for_path (directory).delete (null);
        } catch (Error e) {
            critical ("Could not delete temporary directory: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_loads_legacy_fields () {
        var directory = create_temp_directory ();
        var metadata_path = Path.build_filename (directory, ".protonplus");
        ProtonPlus.Utils.Filesystem.create_file (
            metadata_path,
            "{\"runner_endpoint\":\"https://example.test/releases\",\"runner_title\":\"Example Runner\",\"tag\":\"v1.2.3\"}"
        );

        var metadata = ProtonPlus.Utils.Metadata.load (directory);
        assert (metadata.runner_endpoint == "https://example.test/releases");
        assert (metadata.runner_title == "Example Runner");
        assert (metadata.tag == "v1.2.3");
        assert (metadata.provider_id == "");
        assert (metadata.tool_id == "");
        assert (metadata.launcher_id == "");
        assert (metadata.variant_id == "");
        assert (metadata.release_id == "");
        assert (ProtonPlus.Utils.Filesystem.get_file_content (metadata_path) ==
                "{\"runner_endpoint\":\"https://example.test/releases\",\"runner_title\":\"Example Runner\",\"tag\":\"v1.2.3\"}");

        ProtonPlus.Utils.Filesystem.delete_file (metadata_path);
        assert (DirUtils.remove (directory) == 0);
    }

    private void test_installed_discovery () {
        var root = create_temp_directory ();
        var launcher = new Launcher ("Test", Launcher.InstallationTypes.SYSTEM, "", { root }, "fixture");
        var group = new Group ("Wine", "", "", launcher, "wine");
        group.tools = new Gee.LinkedList<Tool> ();

        var registry = new ProviderRegistry ();
        var proton_definition = registry.get_by_id ("wine-proton");
        var staging_definition = registry.get_by_id ("wine-staging");
        assert (proton_definition != null);
        assert (staging_definition != null);
        var proton = ProviderCatalog.create_tool ((!) proton_definition, group);
        var staging = ProviderCatalog.create_tool ((!) staging_definition, group);
        assert (proton != null);
        assert (staging != null);
        group.tools.add ((!) proton);
        group.tools.add ((!) staging);

        var install_path = Path.build_filename (root, "wine-v9.0-amd64");
        assert (ProtonPlus.Utils.Filesystem.create_directory (install_path));
        var metadata = ProtonPlus.Utils.Metadata.load (install_path);
        metadata.runner_endpoint = "https://api.github.com/repos/Kron4ek/Wine-Builds/releases";
        assert (metadata.save (install_path));

        group.refresh_installed_state ();
        assert (!((!) proton).is_installed ());
        assert (!((!) staging).is_installed ());
        var ambiguous_metadata = ProtonPlus.Utils.Metadata.load (install_path);
        assert (ambiguous_metadata.provider_id == "");
        assert (ambiguous_metadata.tool_id == "");
        assert (ambiguous_metadata.launcher_id == "");

        metadata.runner_title = ((!) proton).title;
        assert (metadata.save (install_path));
        group.refresh_installed_state ();
        assert (((!) proton).is_installed ());
        var upgraded_metadata = ProtonPlus.Utils.Metadata.load (install_path);
        assert (upgraded_metadata.provider_id == ((!) proton).provider_id);
        assert (upgraded_metadata.tool_id == ((!) proton).id);
        assert (upgraded_metadata.launcher_id == launcher.instance_id);

        upgraded_metadata.provider_id = ((!) staging).provider_id;
        upgraded_metadata.tool_id = ((!) staging).id;
        upgraded_metadata.launcher_id = launcher.instance_id;
        assert (upgraded_metadata.save (install_path));
        group.refresh_installed_state ();
        assert (!((!) proton).is_installed ());
        assert (((!) staging).is_installed ());

        ProtonPlus.Utils.Filesystem.delete_file (Path.build_filename (install_path, ".protonplus"));
        assert (DirUtils.remove (install_path) == 0);
        assert (DirUtils.remove (root) == 0);
    }
}
