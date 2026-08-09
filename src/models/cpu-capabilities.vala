namespace ProtonPlus.Models {
    public enum CpuArchitecture {
        UNKNOWN,
        X86_32,
        X86_64,
        AARCH64
    }

    public enum X86_64Level {
        UNKNOWN,
        BASELINE,
        V2,
        V3,
        V4
    }

    public enum Aarch64Level {
        UNKNOWN,
        V8_0,
        V8_1
    }

    /// CPU feature inputs are deliberately compiler- and host-independent so
    /// the psABI classification remains testable without executing probes.
    public class X86_64Features : Object {
        public bool cmpxchg16b { get; set; }
        public bool lahf_sahf { get; set; }
        public bool popcnt { get; set; }
        public bool sse3 { get; set; }
        public bool sse4_1 { get; set; }
        public bool sse4_2 { get; set; }
        public bool ssse3 { get; set; }

        public bool avx { get; set; }
        public bool avx2 { get; set; }
        public bool bmi1 { get; set; }
        public bool bmi2 { get; set; }
        public bool f16c { get; set; }
        public bool fma { get; set; }
        public bool lzcnt { get; set; }
        public bool movbe { get; set; }
        public bool osxsave { get; set; }
        public bool xcr0_xmm { get; set; }
        public bool xcr0_ymm { get; set; }

        public bool avx512f { get; set; }
        public bool avx512bw { get; set; }
        public bool avx512cd { get; set; }
        public bool avx512dq { get; set; }
        public bool avx512vl { get; set; }
        public bool xcr0_opmask { get; set; }
        public bool xcr0_zmm_hi256 { get; set; }
        public bool xcr0_hi16_zmm { get; set; }
    }

    public class Aarch64Features : Object {
        public bool crc32 { get; set; }
        public bool lse_atomics { get; set; }
        public bool rdma { get; set; }
    }

    public class CpuCapabilities : Object {
        public CpuArchitecture architecture { get; private set; }
        public X86_64Level maximum_x86_64_level { get; private set; }
        public Aarch64Level maximum_aarch64_level { get; private set; }

        public CpuCapabilities (
            CpuArchitecture architecture,
            X86_64Level maximum_x86_64_level = X86_64Level.UNKNOWN,
            Aarch64Level maximum_aarch64_level = Aarch64Level.UNKNOWN
        ) {
            this.architecture = architecture;
            this.maximum_x86_64_level = architecture == CpuArchitecture.X86_64
                ? maximum_x86_64_level
                : X86_64Level.UNKNOWN;
            this.maximum_aarch64_level = architecture == CpuArchitecture.AARCH64
                ? (maximum_aarch64_level == Aarch64Level.UNKNOWN
                    ? Aarch64Level.V8_0
                    : maximum_aarch64_level)
                : Aarch64Level.UNKNOWN;
        }

        public bool supports_x86_64_level (X86_64Level level) {
            return architecture == CpuArchitecture.X86_64
                   && level != X86_64Level.UNKNOWN
                   && maximum_x86_64_level != X86_64Level.UNKNOWN
                   && (int) level <= (int) maximum_x86_64_level;
        }

        public bool supports_aarch64_level (Aarch64Level level) {
            return architecture == CpuArchitecture.AARCH64
                   && level != Aarch64Level.UNKNOWN
                   && maximum_aarch64_level != Aarch64Level.UNKNOWN
                   && (int) level <= (int) maximum_aarch64_level;
        }

        public static X86_64Level x86_64_level_from_features (X86_64Features features) {
            var has_v2 = features.cmpxchg16b
                         && features.lahf_sahf
                         && features.popcnt
                         && features.sse3
                         && features.sse4_1
                         && features.sse4_2
                         && features.ssse3;
            if (!has_v2)
                return X86_64Level.BASELINE;

            var has_usable_avx = features.avx
                                 && features.osxsave
                                 && features.xcr0_xmm
                                 && features.xcr0_ymm;
            var has_v3 = has_usable_avx
                         && features.avx2
                         && features.bmi1
                         && features.bmi2
                         && features.f16c
                         && features.fma
                         && features.lzcnt
                         && features.movbe;
            if (!has_v3)
                return X86_64Level.V2;

            var has_v4 = features.avx512f
                         && features.avx512bw
                         && features.avx512cd
                         && features.avx512dq
                         && features.avx512vl
                         && features.xcr0_opmask
                         && features.xcr0_zmm_hi256
                         && features.xcr0_hi16_zmm;
            return has_v4 ? X86_64Level.V4 : X86_64Level.V3;
        }

        public static Aarch64Level aarch64_level_from_features (Aarch64Features features) {
            return features.crc32 && features.lse_atomics && features.rdma
                ? Aarch64Level.V8_1
                : Aarch64Level.V8_0;
        }
    }
}
