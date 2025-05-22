namespace ProtonPlus.Utils.VDF {
    enum BIN_TYPES {
        BIN_TYPE_NODE = 0x00,
        BIN_TYPE_STRING = 0x01,
        BIN_TYPE_INT32 = 0x02,
        BIN_TYPE_FLOAT32 = 0x03,
        BIN_TYPE_POINTER = 0x04,
        BIN_TYPE_WIDESTRING = 0x05,
        BIN_TYPE_COLOR = 0x06,
        BIN_TYPE_UINT64 = 0x07,
        BIN_TYPE_END = 0x08,
        BIN_TYPE_INT64 = 0x0A,
        BIN_TYPE_END_ALT = 0x0B,
    }

    public class Binary {
        private VDF.Node[] _nodes;
        public Gee.TreeMap<string, unowned VDF.Node> nodes;
        private GLib.File file;
        private InputStream input_stream;
        private DataInputStream reader;
        private int current_node_index;
        private DataOutputStream writer;

        private string eat_string() throws Error {
            size_t len;
            try {
                string str = reader.read_upto("\0", 1, out len);
                reader.read_byte();
                return str;
            } catch (Error e) {
                stdout.printf("ERROR %s", e.message);
                throw e;
            }
        }

        private void parse_node(string current_node) throws Error {
            try {
                _nodes += new VDF.Node(current_node);
                current_node_index = _nodes.length - 1;
                while (true) {
                    uint8 type = reader.read_byte();
                    switch (type) {
                    case BIN_TYPES.BIN_TYPE_NODE:
                        parse_node(current_node + "." + eat_string());
                        break;
                    case BIN_TYPES.BIN_TYPE_STRING:
                    case BIN_TYPES.BIN_TYPE_INT32:
                    case BIN_TYPES.BIN_TYPE_FLOAT32:
                    case BIN_TYPES.BIN_TYPE_POINTER:
                    case BIN_TYPES.BIN_TYPE_WIDESTRING:
                    case BIN_TYPES.BIN_TYPE_COLOR:
                    case BIN_TYPES.BIN_TYPE_UINT64:
                    case BIN_TYPES.BIN_TYPE_INT64:
                        get_data(type);
                        break;
                    case BIN_TYPES.BIN_TYPE_END:
                    case BIN_TYPES.BIN_TYPE_END_ALT:
                        return;
                    default:
                        throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Unexpected byte");
                    }
                }
            } catch (Error e) {
                stdout.printf("ERROR %s", e.message);
                throw e;
            }
        }

        private void get_data(BIN_TYPES type) throws Error {
            if (current_node_index < 0) {
                throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Not in a node");
            }

            switch (type) {
            case BIN_TYPES.BIN_TYPE_STRING:
            case BIN_TYPES.BIN_TYPE_WIDESTRING:
                _nodes[current_node_index].set(eat_string(), new GLib.Variant.string(eat_string()));
                break;
            case BIN_TYPES.BIN_TYPE_INT32:
                _nodes[current_node_index].set(eat_string(), new GLib.Variant.int32(reader.read_int32()));
                break;
            case BIN_TYPES.BIN_TYPE_FLOAT32:
                throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Floats not supported yet");
            case BIN_TYPES.BIN_TYPE_POINTER:
                throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Pointers not supported yet");
            case BIN_TYPES.BIN_TYPE_COLOR:
                throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Colors not supported yet");
            case BIN_TYPES.BIN_TYPE_UINT64:
                _nodes[current_node_index].set(eat_string(), new GLib.Variant.uint64(reader.read_uint64()));
                break;
            case BIN_TYPES.BIN_TYPE_INT64:
                _nodes[current_node_index].set(eat_string(), new GLib.Variant.int64(reader.read_int64()));
                break;
            default:
                throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Unexpected byte");
            }
        }

        private uint count_dots(string str) {
            uint ret = 0;
            for (int i = 0; i < str.length; i++) {
                if (str[i] == '.') {
                    ret++;
                }
            }
            return ret;
        }

        private void save_node(string node_name, uint layer, string[] _nodes) throws Error {
            try {
                writer.put_byte(BIN_TYPES.BIN_TYPE_NODE);
                var splitted_name = node_name.split(".");
                writer.put_string(splitted_name[splitted_name.length - 1]);
                writer.put_byte('\0');

                var node = nodes.get(node_name);
                foreach (var elem in node.entries) {
                    if (elem.value.is_of_type(VariantType.STRING)) {
                        writer.put_byte(BIN_TYPES.BIN_TYPE_STRING);
                        writer.put_string(elem.key);
                        writer.put_byte('\0');
                        writer.put_string(elem.value.get_string());
                        writer.put_byte('\0');
                    } else if (elem.value.is_of_type(VariantType.UINT64)) {
                        writer.put_byte(BIN_TYPES.BIN_TYPE_UINT64);
                        writer.put_string(elem.key);
                        writer.put_byte('\0');
                        writer.put_uint64(elem.value.get_uint64());
                    } else if (elem.value.is_of_type(VariantType.INT64)) {
                        writer.put_byte(BIN_TYPES.BIN_TYPE_INT64);
                        writer.put_string(elem.key);
                        writer.put_byte('\0');
                        writer.put_int64(elem.value.get_int64());
                    } else if (elem.value.is_of_type(VariantType.INT32)) {
                        writer.put_byte(BIN_TYPES.BIN_TYPE_INT32);
                        writer.put_string(elem.key);
                        writer.put_byte('\0');
                        writer.put_int32(elem.value.get_int32());
                    }
                }

                foreach (var node_i in _nodes) {
                    if (node_i.contains(node_name)) {
                        if (count_dots(node_i) == layer + 1) {
                            save_node(node_i, layer + 1, _nodes);
                        }
                    }
                }
                writer.put_byte(BIN_TYPES.BIN_TYPE_END);
            } catch (Error e) {
                throw e;
            }
        }

        public void save() throws Error {
            try {
                var output_stream = file.replace(null, false, FileCreateFlags.PRIVATE);
                writer = new DataOutputStream(output_stream);
                writer.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);

                var keys = nodes.keys.to_array();
                string[] root_nodes = {};
                foreach (var elem in keys) {
                    if (!elem.contains(".")) {
                        root_nodes += elem;
                    }
                }

                foreach (var rn in root_nodes) {
                    save_node(rn, 0, keys);
                }

                writer.put_byte(BIN_TYPES.BIN_TYPE_END);

                output_stream.flush();
                output_stream.close(null);
            } catch (Error e) {
                throw e;
            }
        }

        public Binary(string path) {
            try {
                file = GLib.File.new_for_path(path);
                input_stream = file.read();
                reader = new DataInputStream(input_stream);
                current_node_index = -1;
                reader.set_byte_order(DataStreamByteOrder.LITTLE_ENDIAN);
                nodes = new Gee.TreeMap<string, unowned VDF.Node> ();

                while (true) {
                    uint8 type = reader.read_byte();
                    switch (type) {
                    case BIN_TYPES.BIN_TYPE_NODE:
                        parse_node(eat_string());
                        break;
                    case BIN_TYPES.BIN_TYPE_END:
                    case BIN_TYPES.BIN_TYPE_END_ALT:
                        foreach (var node in _nodes) {
                            nodes.set(node.node_name, node);
                        }
                        input_stream.close(null);
                        return;
                    default:
                        throw new GLib.Error(GLib.Quark.from_string("vala-vdf"), 0, "Unexpected byte");
                    }
                }
            } catch (Error e) {
                stderr.printf("%s\n", e.message);
            }
        }
    }
}