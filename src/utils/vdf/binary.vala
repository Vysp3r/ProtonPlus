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
        // The map is the single owner of every node.  Keeping an unowned view
        // alongside a separate array made nodes added after parsing dangle.
        public Gee.TreeMap<string, VDF.Node> nodes { get; protected set; }
        private GLib.File file;
        private DataInputStream reader;
        private DataOutputStream writer;

        private string eat_string () throws Error {
            size_t len;
            string str = reader.read_upto ("\0", 1, out len);
            reader.read_byte ();
            return str;
        }

        private void parse_node (string current_node) throws Error {
            var node = new VDF.Node (current_node);
            nodes.set (node.node_name, node);

            while (true) {
                uint8 type = reader.read_byte ();
                switch (type) {
                    case BIN_TYPES.BIN_TYPE_NODE:
                        parse_node (current_node + "." + eat_string ());
                        break;
                    case BIN_TYPES.BIN_TYPE_STRING:
                    case BIN_TYPES.BIN_TYPE_INT32:
                    case BIN_TYPES.BIN_TYPE_FLOAT32:
                    case BIN_TYPES.BIN_TYPE_POINTER:
                    case BIN_TYPES.BIN_TYPE_WIDESTRING:
                    case BIN_TYPES.BIN_TYPE_COLOR:
                    case BIN_TYPES.BIN_TYPE_UINT64:
                    case BIN_TYPES.BIN_TYPE_INT64:
                        get_data (node, type);
                        break;
                    case BIN_TYPES.BIN_TYPE_END:
                    case BIN_TYPES.BIN_TYPE_END_ALT:
                        return;
                    default:
                        throw new GLib.Error (GLib.Quark.from_string ("vala-vdf"), 0, "Unexpected byte");
                }
            }
        }

        private void get_data (VDF.Node node, BIN_TYPES type) throws Error {
            switch (type) {
                case BIN_TYPES.BIN_TYPE_STRING:
                case BIN_TYPES.BIN_TYPE_WIDESTRING:
                    node.set (eat_string (), new GLib.Variant.string (eat_string ()));
                    break;
                case BIN_TYPES.BIN_TYPE_INT32:
                    node.set (eat_string (), new GLib.Variant.int32 (reader.read_int32 ()));
                    break;
                case BIN_TYPES.BIN_TYPE_FLOAT32:
                    throw new GLib.Error (GLib.Quark.from_string ("vala-vdf"), 0, "Floats not supported yet");
                case BIN_TYPES.BIN_TYPE_POINTER:
                    throw new GLib.Error (GLib.Quark.from_string ("vala-vdf"), 0, "Pointers not supported yet");
                case BIN_TYPES.BIN_TYPE_COLOR:
                    throw new GLib.Error (GLib.Quark.from_string ("vala-vdf"), 0, "Colors not supported yet");
                case BIN_TYPES.BIN_TYPE_UINT64:
                    node.set (eat_string (), new GLib.Variant.uint64 (reader.read_uint64 ()));
                    break;
                case BIN_TYPES.BIN_TYPE_INT64:
                    node.set (eat_string (), new GLib.Variant.int64 (reader.read_int64 ()));
                    break;
                default:
                    throw new GLib.Error (GLib.Quark.from_string ("vala-vdf"), 0, "Unexpected byte");
            }
        }

        private uint count_dots (string str) {
            uint ret = 0;
            for (int i = 0; i < str.length; i++) {
                if (str[i] == '.') {
                    ret++;
                }
            }
            return ret;
        }

        private void save_node (string node_name, uint layer, Gee.Set<string> node_names) throws Error {
            writer.put_byte (BIN_TYPES.BIN_TYPE_NODE);
            var split_name = node_name.split (".");
            writer.put_string (split_name[split_name.length - 1]);
            writer.put_byte ('\0');

            var node = nodes.get (node_name);
            foreach (var elem in node.entries) {
                if (elem.value.is_of_type (VariantType.STRING)) {
                    writer.put_byte (BIN_TYPES.BIN_TYPE_STRING);
                    writer.put_string (elem.key);
                    writer.put_byte ('\0');
                    writer.put_string (elem.value.get_string ());
                    writer.put_byte ('\0');
                } else if (elem.value.is_of_type (VariantType.UINT64)) {
                    writer.put_byte (BIN_TYPES.BIN_TYPE_UINT64);
                    writer.put_string (elem.key);
                    writer.put_byte ('\0');
                    writer.put_uint64 (elem.value.get_uint64 ());
                } else if (elem.value.is_of_type (VariantType.INT64)) {
                    writer.put_byte (BIN_TYPES.BIN_TYPE_INT64);
                    writer.put_string (elem.key);
                    writer.put_byte ('\0');
                    writer.put_int64 (elem.value.get_int64 ());
                } else if (elem.value.is_of_type (VariantType.INT32)) {
                    writer.put_byte (BIN_TYPES.BIN_TYPE_INT32);
                    writer.put_string (elem.key);
                    writer.put_byte ('\0');
                    writer.put_int32 (elem.value.get_int32 ());
                }
            }

            foreach (var child_name in node_names) {
                if (child_name.has_prefix (node_name + ".") && count_dots (child_name) == layer + 1)
                    save_node (child_name, layer + 1, node_names);
            }

            writer.put_byte (BIN_TYPES.BIN_TYPE_END);
        }

        public void save () throws Error {
            var output_stream = file.replace (null, false, FileCreateFlags.PRIVATE);
            writer = new DataOutputStream (output_stream);
            writer.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

            var node_names = nodes.keys;
            foreach (var node_name in node_names) {
                if (!node_name.contains ("."))
                    save_node (node_name, 0, node_names);
            }

            writer.put_byte (BIN_TYPES.BIN_TYPE_END);

            output_stream.flush ();
            output_stream.close (null);
        }

        protected Binary (string path) {
            file = GLib.File.new_for_path (path);
            nodes = new Gee.TreeMap<string, VDF.Node> ();
        }

        protected void parse () throws Error {
            var input_stream = file.read ();
            try {
                reader = new DataInputStream (input_stream);
                reader.set_byte_order (DataStreamByteOrder.LITTLE_ENDIAN);

                bool complete = false;
                while (!complete) {
                    uint8 type = reader.read_byte ();
                    switch (type) {
                        case BIN_TYPES.BIN_TYPE_NODE:
                            parse_node (eat_string ());
                            break;
                        case BIN_TYPES.BIN_TYPE_END:
                        case BIN_TYPES.BIN_TYPE_END_ALT:
                            complete = true;
                            break;
                        default:
                            throw new GLib.Error (GLib.Quark.from_string ("vala-vdf"), 0, "Unexpected byte");
                    }
                }
            } catch (Error e) {
                input_stream.close (null);
                throw e;
            }

            input_stream.close (null);
        }

        public static Binary load (string path) throws Error {
            var binary = new Binary (path);
            binary.parse ();
            return binary;
        }
    }
}
