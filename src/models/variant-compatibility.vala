namespace ProtonPlus.Models {
    // Static variant metadata. This deliberately stays a small value object:
    // provider definitions describe the available artifacts, while this type
    // makes the host-compatibility decision reusable without selecting or
    // filtering variants.
    public class VariantCompatibility : Object {
        private CpuArchitecture[] supported_architectures;
        public X86_64Level minimum_x86_64_level { get; private set; }
        public Aarch64Level minimum_aarch64_level { get; private set; }
        public bool architecture_independent { get; private set; }

        public VariantCompatibility (
            CpuArchitecture[]? supported_architectures = null,
            X86_64Level minimum_x86_64_level = X86_64Level.UNKNOWN,
            bool architecture_independent = false,
            Aarch64Level minimum_aarch64_level = Aarch64Level.UNKNOWN
        ) {
            this.supported_architectures = copy_architectures (supported_architectures);
            this.minimum_x86_64_level = minimum_x86_64_level;
            this.minimum_aarch64_level = minimum_aarch64_level == Aarch64Level.UNKNOWN &&
                supports_architecture (CpuArchitecture.AARCH64)
                ? Aarch64Level.V8_0
                : minimum_aarch64_level;
            this.architecture_independent = architecture_independent;
        }

        public bool is_specified {
            get {
                return architecture_independent || supported_architectures.length > 0 ||
                       minimum_x86_64_level != X86_64Level.UNKNOWN ||
                       minimum_aarch64_level != Aarch64Level.UNKNOWN;
            }
        }

        public static VariantCompatibility unspecified () {
            return new VariantCompatibility ();
        }

        public static VariantCompatibility independent () {
            return new VariantCompatibility (null, X86_64Level.UNKNOWN, true);
        }

        public static VariantCompatibility for_architecture (CpuArchitecture architecture) {
            if (architecture == CpuArchitecture.X86_64)
                return for_x86_64_level (X86_64Level.BASELINE);
            if (architecture == CpuArchitecture.AARCH64)
                return for_aarch64_level (Aarch64Level.V8_0);
            return new VariantCompatibility ({ architecture });
        }

        public static VariantCompatibility for_architectures (CpuArchitecture[] architectures) {
            var x86_64_level = X86_64Level.UNKNOWN;
            var aarch64_level = Aarch64Level.UNKNOWN;
            foreach (var architecture in architectures) {
                if (architecture == CpuArchitecture.X86_64)
                    x86_64_level = X86_64Level.BASELINE;
                if (architecture == CpuArchitecture.AARCH64)
                    aarch64_level = Aarch64Level.V8_0;
            }
            return new VariantCompatibility (architectures, x86_64_level, false, aarch64_level);
        }

        public static VariantCompatibility for_x86_64_level (X86_64Level level) {
            return new VariantCompatibility ({ CpuArchitecture.X86_64 }, level);
        }

        public static VariantCompatibility for_aarch64_level (Aarch64Level level) {
            return new VariantCompatibility (
                { CpuArchitecture.AARCH64 }, X86_64Level.UNKNOWN, false, level
            );
        }

        public CpuArchitecture[] get_supported_architectures () {
            return copy_architectures (supported_architectures);
        }

        public bool explicitly_supports_architecture (CpuArchitecture architecture) {
            return supports_architecture (architecture);
        }

        public VariantCompatibility copy () {
            return new VariantCompatibility (
                supported_architectures, minimum_x86_64_level, architecture_independent,
                minimum_aarch64_level
            );
        }

        public bool equals (VariantCompatibility other) {
            if (architecture_independent != other.architecture_independent ||
                minimum_x86_64_level != other.minimum_x86_64_level ||
                minimum_aarch64_level != other.minimum_aarch64_level ||
                supported_architectures.length != other.supported_architectures.length)
                return false;

            foreach (var architecture in supported_architectures) {
                if (!other.supports_architecture (architecture))
                    return false;
            }
            return true;
        }

        public bool is_compatible_with (CpuCapabilities capabilities) {
            // An unknown host architecture must never make a variant disappear.
            if (capabilities.architecture == CpuArchitecture.UNKNOWN || !is_specified ||
                architecture_independent)
                return true;

            if (supported_architectures.length > 0 &&
                !supports_architecture (capabilities.architecture)) {
                // AArch64 systems may run x86-64 tools through an emulation
                // layer. Keep this intentionally one-way: an x86-64 system
                // must not be offered AArch64 artifacts.
                var supports_emulated_x86_64 = capabilities.architecture == CpuArchitecture.AARCH64 &&
                    supports_architecture (CpuArchitecture.X86_64);
                if (!supports_emulated_x86_64)
                    return false;
            }

            if (capabilities.architecture == CpuArchitecture.X86_64 &&
                supports_architecture (CpuArchitecture.X86_64) &&
                minimum_x86_64_level != X86_64Level.UNKNOWN)
                return capabilities.supports_x86_64_level (minimum_x86_64_level);

            if (capabilities.architecture == CpuArchitecture.AARCH64 &&
                supports_architecture (CpuArchitecture.AARCH64) &&
                minimum_aarch64_level != Aarch64Level.UNKNOWN)
                return capabilities.supports_aarch64_level (minimum_aarch64_level);

            return true;
        }

        public bool is_structurally_valid () {
            if (architecture_independent)
                return supported_architectures.length == 0 &&
                       minimum_x86_64_level == X86_64Level.UNKNOWN &&
                       minimum_aarch64_level == Aarch64Level.UNKNOWN;

            var has_x86_64 = false;
            var has_aarch64 = false;
            var seen_architectures = new CpuArchitecture[0];
            foreach (var architecture in supported_architectures) {
                if (architecture == CpuArchitecture.UNKNOWN)
                    return false;
                foreach (var seen_architecture in seen_architectures) {
                    if (architecture == seen_architecture)
                        return false;
                }
                seen_architectures += architecture;
                if (architecture == CpuArchitecture.X86_64)
                    has_x86_64 = true;
                if (architecture == CpuArchitecture.AARCH64)
                    has_aarch64 = true;
            }

            if (minimum_x86_64_level != X86_64Level.UNKNOWN && !has_x86_64)
                return false;
            if (has_x86_64 && minimum_x86_64_level < X86_64Level.BASELINE)
                return false;
            if (minimum_aarch64_level != Aarch64Level.UNKNOWN && !has_aarch64)
                return false;
            if (has_aarch64 && minimum_aarch64_level < Aarch64Level.V8_0)
                return false;
            return true;
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            var architectures = new Json.Array ();
            foreach (var architecture in supported_architectures)
                architectures.add_string_element (architecture_to_string (architecture));
            obj.set_array_member ("architectures", architectures);
            obj.set_string_member ("minimum_x86_64_level", x86_64_level_to_string (minimum_x86_64_level));
            obj.set_string_member ("minimum_aarch64_level", aarch64_level_to_string (minimum_aarch64_level));
            obj.set_boolean_member ("architecture_independent", architecture_independent);
            return obj;
        }

        public static VariantCompatibility from_json (Json.Object? obj) {
            if (obj == null)
                return unspecified ();

            var architecture_independent = false;
            if (obj.has_member ("architecture_independent")) {
                var node = obj.get_member ("architecture_independent");
                if (node == null || node.get_node_type () != Json.NodeType.VALUE ||
                    node.get_value_type () != typeof (bool))
                    return unspecified ();
                architecture_independent = node.get_boolean ();
            }

            var parsed_architectures = new CpuArchitecture[0];
            if (obj.has_member ("architectures")) {
                var values = obj.get_array_member ("architectures");
                if (values == null)
                    return unspecified ();
                for (var index = 0; index < values.get_length (); index++) {
                    var node = values.get_element (index);
                    if (node == null || node.get_node_type () != Json.NodeType.VALUE ||
                        node.get_value_type () != typeof (string))
                        return unspecified ();
                    var architecture = architecture_from_string (node.get_string ());
                    if (architecture == CpuArchitecture.UNKNOWN)
                        return unspecified ();
                    parsed_architectures += architecture;
                }
            }

            var level = X86_64Level.UNKNOWN;
            if (obj.has_member ("minimum_x86_64_level")) {
                var node = obj.get_member ("minimum_x86_64_level");
                if (node == null || node.get_node_type () != Json.NodeType.VALUE ||
                    node.get_value_type () != typeof (string))
                    return unspecified ();
                level = x86_64_level_from_string (node.get_string ());
                if (level == X86_64Level.UNKNOWN && node.get_string () != "")
                    return unspecified ();
            }

            var aarch64_level = Aarch64Level.UNKNOWN;
            if (obj.has_member ("minimum_aarch64_level")) {
                var node = obj.get_member ("minimum_aarch64_level");
                if (node == null || node.get_node_type () != Json.NodeType.VALUE ||
                    node.get_value_type () != typeof (string))
                    return unspecified ();
                aarch64_level = aarch64_level_from_string (node.get_string ());
                if (aarch64_level == Aarch64Level.UNKNOWN && node.get_string () != "")
                    return unspecified ();
            }

            var compatibility = new VariantCompatibility (
                parsed_architectures, level, architecture_independent, aarch64_level
            );
            return compatibility.is_structurally_valid () ? compatibility : unspecified ();
        }

        private bool supports_architecture (CpuArchitecture architecture) {
            foreach (var supported_architecture in supported_architectures) {
                if (supported_architecture == architecture)
                    return true;
            }
            return false;
        }

        private static CpuArchitecture[] copy_architectures (CpuArchitecture[]? values) {
            if (values == null)
                return {};
            var copied = new CpuArchitecture[values.length];
            for (var index = 0; index < values.length; index++)
                copied[index] = values[index];
            return copied;
        }

        private static string architecture_to_string (CpuArchitecture architecture) {
            switch (architecture) {
            case CpuArchitecture.X86_32:
                return "x86_32";
            case CpuArchitecture.X86_64:
                return "x86_64";
            case CpuArchitecture.AARCH64:
                return "aarch64";
            default:
                return "unknown";
            }
        }

        private static CpuArchitecture architecture_from_string (string value) {
            switch (value) {
            case "x86_32":
                return CpuArchitecture.X86_32;
            case "x86_64":
                return CpuArchitecture.X86_64;
            case "aarch64":
                return CpuArchitecture.AARCH64;
            default:
                return CpuArchitecture.UNKNOWN;
            }
        }

        private static string x86_64_level_to_string (X86_64Level level) {
            switch (level) {
            case X86_64Level.BASELINE:
                return "baseline";
            case X86_64Level.V2:
                return "v2";
            case X86_64Level.V3:
                return "v3";
            case X86_64Level.V4:
                return "v4";
            default:
                return "";
            }
        }

        private static X86_64Level x86_64_level_from_string (string value) {
            switch (value) {
            case "baseline":
                return X86_64Level.BASELINE;
            case "v2":
                return X86_64Level.V2;
            case "v3":
                return X86_64Level.V3;
            case "v4":
                return X86_64Level.V4;
            default:
                return X86_64Level.UNKNOWN;
            }
        }

        private static string aarch64_level_to_string (Aarch64Level level) {
            switch (level) {
            case Aarch64Level.V8_0:
                return "v8_0";
            case Aarch64Level.V8_1:
                return "v8_1";
            default:
                return "";
            }
        }

        private static Aarch64Level aarch64_level_from_string (string value) {
            switch (value) {
            case "v8_0":
                return Aarch64Level.V8_0;
            case "v8_1":
                return Aarch64Level.V8_1;
            default:
                return Aarch64Level.UNKNOWN;
            }
        }
    }
}
