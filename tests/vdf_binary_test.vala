namespace AppTests.VdfBinaryTest {
    using GLib;

    public void register_tests () {
        Test.add_func ("/vdf-binary/parent-data-after-child", test_parent_data_after_child);
        Test.add_func ("/vdf-binary/similar-node-prefixes", test_similar_node_prefixes);
        Test.add_func ("/vdf-shortcuts/remove-exact-id", test_remove_shortcut_uses_exact_id);
        Test.add_func ("/vdf-shortcuts/append-first-unused-id", test_append_shortcut_uses_first_unused_id);
    }

    private string create_temp_file (out string root) throws FileError {
        root = DirUtils.make_tmp ("protonplus-vdf-test-XXXXXX");
        return Path.build_filename (root, "shortcuts.vdf");
    }

    private void write_cstring (DataOutputStream writer, string value) throws Error {
        writer.put_string (value);
        writer.put_byte ('\0');
    }

    private void remove_temp_file (string root, string path) {
        assert (FileUtils.remove (path) == 0);
        assert (DirUtils.remove (root) == 0);
    }

    private ProtonPlus.Utils.VDF.Shortcuts create_empty_shortcuts (string path) throws Error {
        var stream = File.new_for_path (path).create (FileCreateFlags.PRIVATE);
        var writer = new DataOutputStream (stream);
        writer.put_byte (0x08);
        stream.close ();

        return new ProtonPlus.Utils.VDF.Shortcuts (path);
    }

    private ProtonPlus.Utils.VDF.Node shortcut_node (string path, string name) {
        var node = new ProtonPlus.Utils.VDF.Node (path);
        node["AppName"] = new Variant.string (name);
        return node;
    }

    private ProtonPlus.Utils.VDF.Shortcut new_shortcut (string name) {
        ProtonPlus.Utils.VDF.Shortcut shortcut = {};
        shortcut.AppName = name;
        shortcut.DevkitGameID = "";
        shortcut.Exe = "";
        shortcut.FlatpakAppID = "";
        shortcut.LaunchOptions = "";
        shortcut.ShortcutPath = "";
        shortcut.StartDir = "";
        shortcut.Icon = "";
        return shortcut;
    }

    private void test_parent_data_after_child () {
        string root;

        try {
            var path = create_temp_file (out root);
            var stream = File.new_for_path (path).create (FileCreateFlags.PRIVATE);
            var writer = new DataOutputStream (stream);
            writer.byte_order = DataStreamByteOrder.LITTLE_ENDIAN;

            writer.put_byte (0x00);
            write_cstring (writer, "root");
            writer.put_byte (0x01);
            write_cstring (writer, "before");
            write_cstring (writer, "first");
            writer.put_byte (0x00);
            write_cstring (writer, "child");
            writer.put_byte (0x01);
            write_cstring (writer, "value");
            write_cstring (writer, "nested");
            writer.put_byte (0x08);
            writer.put_byte (0x01);
            write_cstring (writer, "after");
            write_cstring (writer, "second");
            writer.put_byte (0x08);
            writer.put_byte (0x08);
            stream.close ();

            var binary = new ProtonPlus.Utils.VDF.Binary (path);
            assert (binary.nodes["root"]["before"].get_string () == "first");
            assert (binary.nodes["root"]["after"].get_string () == "second");
            assert (binary.nodes["root.child"]["value"].get_string () == "nested");

            remove_temp_file (root, path);
        } catch (Error e) {
            critical ("Could not exercise binary VDF parsing: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_similar_node_prefixes () {
        string root;

        try {
            var path = create_temp_file (out root);
            var stream = File.new_for_path (path).create (FileCreateFlags.PRIVATE);
            var writer = new DataOutputStream (stream);
            writer.put_byte (0x08);
            stream.close ();

            var binary = new ProtonPlus.Utils.VDF.Binary (path);
            var foo = new ProtonPlus.Utils.VDF.Node ("foo");
            var foobar = new ProtonPlus.Utils.VDF.Node ("foobar");
            var foobar_child = new ProtonPlus.Utils.VDF.Node ("foobar.child");
            foo["value"] = new Variant.string ("foo");
            foobar["value"] = new Variant.string ("foobar");
            foobar_child["value"] = new Variant.string ("child");
            binary.nodes["foo"] = foo;
            binary.nodes["foobar"] = foobar;
            binary.nodes["foobar.child"] = foobar_child;
            binary.save ();

            var reloaded = new ProtonPlus.Utils.VDF.Binary (path);
            assert (reloaded.nodes.has_key ("foo"));
            assert (!reloaded.nodes.has_key ("foo.child"));
            assert (reloaded.nodes.has_key ("foobar.child"));

            remove_temp_file (root, path);
        } catch (Error e) {
            critical ("Could not exercise binary VDF serialization: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_remove_shortcut_uses_exact_id () {
        string root;

        try {
            var path = create_temp_file (out root);
            var shortcuts = create_empty_shortcuts (path);
            var protonplus = shortcut_node ("shortcuts.1", "ProtonPlus");
            var protonplus_tags = new ProtonPlus.Utils.VDF.Node ("shortcuts.1.tags");
            var unrelated = shortcut_node ("shortcuts.10", "Unrelated");
            var unrelated_tags = new ProtonPlus.Utils.VDF.Node ("shortcuts.10.tags");
            shortcuts.nodes["shortcuts.1"] = protonplus;
            shortcuts.nodes["shortcuts.1.tags"] = protonplus_tags;
            shortcuts.nodes["shortcuts.10"] = unrelated;
            shortcuts.nodes["shortcuts.10.tags"] = unrelated_tags;

            shortcuts.remove_shortcut_by_name ("ProtonPlus");

            assert (!shortcuts.nodes.has_key ("shortcuts.1"));
            assert (!shortcuts.nodes.has_key ("shortcuts.1.tags"));
            assert (shortcuts.nodes.has_key ("shortcuts.9"));
            assert (shortcuts.nodes.has_key ("shortcuts.9.tags"));
            assert (shortcuts.nodes["shortcuts.9"]["AppName"].get_string () == "Unrelated");

            remove_temp_file (root, path);
        } catch (Error e) {
            critical ("Could not remove a shortcut without affecting similar IDs: %s", e.message);
            assert_not_reached ();
        }
    }

    private void test_append_shortcut_uses_first_unused_id () {
        string root;

        try {
            var path = create_temp_file (out root);
            var shortcuts = create_empty_shortcuts (path);
            var first = shortcut_node ("shortcuts.0", "First");
            var first_tags = new ProtonPlus.Utils.VDF.Node ("shortcuts.0.tags");
            var third = shortcut_node ("shortcuts.2", "Third");
            var third_tags = new ProtonPlus.Utils.VDF.Node ("shortcuts.2.tags");
            shortcuts.nodes["shortcuts.0"] = first;
            shortcuts.nodes["shortcuts.0.tags"] = first_tags;
            shortcuts.nodes["shortcuts.2"] = third;
            shortcuts.nodes["shortcuts.2.tags"] = third_tags;

            var second = new_shortcut ("Second");
            shortcuts.append_shortcut (second);

            assert (shortcuts.nodes.has_key ("shortcuts.1"));
            assert (shortcuts.nodes.has_key ("shortcuts.1.tags"));
            assert (shortcuts.nodes["shortcuts.1"]["AppName"].get_string () == "Second");
            assert (shortcuts.nodes.has_key ("shortcuts.2"));
            assert (shortcuts.nodes["shortcuts.2"]["AppName"].get_string () == "Third");

            remove_temp_file (root, path);
        } catch (Error e) {
            critical ("Could not append a shortcut to a sparse file: %s", e.message);
            assert_not_reached ();
        }
    }
}
