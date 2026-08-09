namespace AppTests.CpuCapabilitiesTest {
    using GLib;
    using ProtonPlus.Models;
    using ProtonPlus.Utils;

    public void register_tests () {
        Test.add_func ("/cpu-capabilities/architecture-normalization", test_architecture_normalization);
        Test.add_func ("/cpu-capabilities/cumulative-level-support", test_cumulative_level_support);
        Test.add_func ("/cpu-capabilities/aarch64-level-support", test_aarch64_level_support);
        Test.add_func ("/cpu-capabilities/feature-level-classification", test_feature_level_classification);
        Test.add_func ("/cpu-capabilities/v3-requirements", test_v3_requirements);
        Test.add_func ("/cpu-capabilities/probe-fallback-and-non-x86", test_probe_fallback_and_non_x86);
        Test.add_func ("/cpu-capabilities/derived-hwcaps", test_derived_hwcaps);
    }

    private X86_64Features complete_v2_features () {
        return new X86_64Features () {
            cmpxchg16b = true,
            lahf_sahf = true,
            popcnt = true,
            sse3 = true,
            sse4_1 = true,
            sse4_2 = true,
            ssse3 = true
        };
    }

    private X86_64Features complete_v3_features () {
        var features = complete_v2_features ();
        features.avx = true;
        features.avx2 = true;
        features.bmi1 = true;
        features.bmi2 = true;
        features.f16c = true;
        features.fma = true;
        features.lzcnt = true;
        features.movbe = true;
        features.osxsave = true;
        features.xcr0_xmm = true;
        features.xcr0_ymm = true;
        return features;
    }

    private X86_64Features complete_v4_features () {
        var features = complete_v3_features ();
        features.avx512f = true;
        features.avx512bw = true;
        features.avx512cd = true;
        features.avx512dq = true;
        features.avx512vl = true;
        features.xcr0_opmask = true;
        features.xcr0_zmm_hi256 = true;
        features.xcr0_hi16_zmm = true;
        return features;
    }

    private CpuCapabilities capabilities_for (X86_64Features features) {
        return System.get_cpu_capabilities_for_probe ("x86_64", true, features);
    }

    private CpuCapabilities capabilities_for_aarch64 (
        bool crc32,
        bool lse_atomics,
        bool rdma
    ) {
        return System.get_cpu_capabilities_for_probe (
            "aarch64", true, new X86_64Features (),
            new Aarch64Features () {
                crc32 = crc32,
                lse_atomics = lse_atomics,
                rdma = rdma
            }
        );
    }

    private void test_architecture_normalization () {
        foreach (var machine in new string[] { "x86_64", "amd64", "x64", "x86-64" }) {
            assert (System.normalize_cpu_architecture (machine) == CpuArchitecture.X86_64);
            assert (System.normalize_cpu_architecture ("  %s\t".printf (machine.ascii_up ())) == CpuArchitecture.X86_64);
        }
        foreach (var machine in new string[] { "aarch64", "arm64" }) {
            assert (System.normalize_cpu_architecture (machine) == CpuArchitecture.AARCH64);
            assert (System.normalize_cpu_architecture ("  %s\t".printf (machine.ascii_up ())) == CpuArchitecture.AARCH64);
        }
        foreach (var machine in new string[] { "i386", "i486", "i586", "i686", "x86", "x86_32", "ia32" }) {
            assert (System.normalize_cpu_architecture (machine) == CpuArchitecture.X86_32);
            assert (System.normalize_cpu_architecture ("  %s\t".printf (machine.ascii_up ())) == CpuArchitecture.X86_32);
        }

        assert (System.normalize_cpu_architecture ("") == CpuArchitecture.UNKNOWN);
        assert (System.normalize_cpu_architecture ("riscv64") == CpuArchitecture.UNKNOWN);
    }

    private void test_cumulative_level_support () {
        var baseline = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.BASELINE);
        assert (baseline.supports_x86_64_level (X86_64Level.BASELINE));
        assert (!baseline.supports_x86_64_level (X86_64Level.V2));
        assert (!baseline.supports_x86_64_level (X86_64Level.V3));
        assert (!baseline.supports_x86_64_level (X86_64Level.V4));

        var v2 = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2);
        assert (v2.supports_x86_64_level (X86_64Level.BASELINE));
        assert (v2.supports_x86_64_level (X86_64Level.V2));
        assert (!v2.supports_x86_64_level (X86_64Level.V3));

        var v3 = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V3);
        assert (v3.supports_x86_64_level (X86_64Level.BASELINE));
        assert (v3.supports_x86_64_level (X86_64Level.V2));
        assert (v3.supports_x86_64_level (X86_64Level.V3));
        assert (!v3.supports_x86_64_level (X86_64Level.V4));

        var v4 = new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V4);
        foreach (var level in new X86_64Level[] {
            X86_64Level.BASELINE, X86_64Level.V2, X86_64Level.V3, X86_64Level.V4
        })
            assert (v4.supports_x86_64_level (level));

        foreach (var architecture in new CpuArchitecture[] { CpuArchitecture.AARCH64, CpuArchitecture.X86_32 }) {
            var capabilities = new CpuCapabilities (architecture, X86_64Level.V4);
            assert (!capabilities.supports_x86_64_level (X86_64Level.BASELINE));
            assert (!capabilities.supports_x86_64_level (X86_64Level.V4));
        }
    }

    private void test_feature_level_classification () {
        assert (capabilities_for (complete_v2_features ()).maximum_x86_64_level == X86_64Level.V2);
        assert (capabilities_for (complete_v3_features ()).maximum_x86_64_level == X86_64Level.V3);
        assert (capabilities_for (complete_v4_features ()).maximum_x86_64_level == X86_64Level.V4);

        var avx_without_bmi2 = complete_v3_features ();
        avx_without_bmi2.bmi2 = false;
        assert (capabilities_for (avx_without_bmi2).maximum_x86_64_level == X86_64Level.V2);

        var no_os_avx_state = complete_v3_features ();
        no_os_avx_state.xcr0_ymm = false;
        assert (capabilities_for (no_os_avx_state).maximum_x86_64_level == X86_64Level.V2);
    }

    private void test_aarch64_level_support () {
        var v8_0 = capabilities_for_aarch64 (false, false, false);
        assert (v8_0.maximum_aarch64_level == Aarch64Level.V8_0);
        assert (v8_0.supports_aarch64_level (Aarch64Level.V8_0));
        assert (!v8_0.supports_aarch64_level (Aarch64Level.V8_1));

        var v8_1 = capabilities_for_aarch64 (true, true, true);
        assert (v8_1.maximum_aarch64_level == Aarch64Level.V8_1);
        assert (v8_1.supports_aarch64_level (Aarch64Level.V8_0));
        assert (v8_1.supports_aarch64_level (Aarch64Level.V8_1));

        assert (capabilities_for_aarch64 (false, true, true).maximum_aarch64_level == Aarch64Level.V8_0);
        assert (capabilities_for_aarch64 (true, false, true).maximum_aarch64_level == Aarch64Level.V8_0);
        assert (capabilities_for_aarch64 (true, true, false).maximum_aarch64_level == Aarch64Level.V8_0);

        assert (!new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V4)
            .supports_aarch64_level (Aarch64Level.V8_0));
    }

    private void test_v3_requirements () {
        foreach (var missing in new string[] {
            "avx", "avx2", "bmi1", "bmi2", "f16c", "fma", "lzcnt", "movbe", "osxsave", "xcr0_xmm", "xcr0_ymm"
        }) {
            var features = complete_v3_features ();
            switch (missing) {
            case "avx": features.avx = false; break;
            case "avx2": features.avx2 = false; break;
            case "bmi1": features.bmi1 = false; break;
            case "bmi2": features.bmi2 = false; break;
            case "f16c": features.f16c = false; break;
            case "fma": features.fma = false; break;
            case "lzcnt": features.lzcnt = false; break;
            case "movbe": features.movbe = false; break;
            case "osxsave": features.osxsave = false; break;
            case "xcr0_xmm": features.xcr0_xmm = false; break;
            case "xcr0_ymm": features.xcr0_ymm = false; break;
            default: assert_not_reached ();
            }
            assert (capabilities_for (features).maximum_x86_64_level == X86_64Level.V2);
        }
    }

    private void test_probe_fallback_and_non_x86 () {
        var unavailable = System.get_cpu_capabilities_for_probe ("x86_64", false, complete_v4_features ());
        assert (unavailable.architecture == CpuArchitecture.X86_64);
        assert (unavailable.maximum_x86_64_level == X86_64Level.BASELINE);

        var aarch64 = System.get_cpu_capabilities_for_probe ("aarch64", true, complete_v4_features ());
        assert (aarch64.architecture == CpuArchitecture.AARCH64);
        assert (aarch64.maximum_x86_64_level == X86_64Level.UNKNOWN);
        assert (aarch64.maximum_aarch64_level == Aarch64Level.V8_0);

        var unavailable_aarch64 = System.get_cpu_capabilities_for_probe (
            "aarch64", false, complete_v4_features (),
            new Aarch64Features () { crc32 = true, lse_atomics = true, rdma = true }
        );
        assert (unavailable_aarch64.maximum_aarch64_level == Aarch64Level.V8_0);
    }

    private void assert_hwcaps (CpuCapabilities capabilities, string[] expected) {
        var actual = System.get_hwcaps_for_capabilities (capabilities);
        assert (actual.length () == expected.length);
        for (uint index = 0; index < expected.length; index++)
            assert (actual.nth_data (index) == expected[index]);
    }

    private void test_derived_hwcaps () {
        assert_hwcaps (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.BASELINE), { "x86_64" });
        assert_hwcaps (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V2), { "x86_64_v2", "x86_64" });
        assert_hwcaps (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V3), { "x86_64_v3", "x86_64_v2", "x86_64" });
        assert_hwcaps (new CpuCapabilities (CpuArchitecture.X86_64, X86_64Level.V4), { "x86_64_v4", "x86_64_v3", "x86_64_v2", "x86_64" });
        assert_hwcaps (new CpuCapabilities (CpuArchitecture.AARCH64), { "aarch64" });
        assert_hwcaps (new CpuCapabilities (
            CpuArchitecture.AARCH64, X86_64Level.UNKNOWN, Aarch64Level.V8_1
        ), { "aarch64_v8_1", "aarch64" });
        assert_hwcaps (new CpuCapabilities (CpuArchitecture.UNKNOWN), { "unknown" });
    }
}
