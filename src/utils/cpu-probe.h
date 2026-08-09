#pragma once

#include <glib.h>

typedef struct _ProtonPlusCpuFeatureProbe {
    gboolean available;
    gboolean cmpxchg16b;
    gboolean lahf_sahf;
    gboolean popcnt;
    gboolean sse3;
    gboolean sse4_1;
    gboolean sse4_2;
    gboolean ssse3;
    gboolean avx;
    gboolean avx2;
    gboolean bmi1;
    gboolean bmi2;
    gboolean f16c;
    gboolean fma;
    gboolean lzcnt;
    gboolean movbe;
    gboolean osxsave;
    gboolean xcr0_xmm;
    gboolean xcr0_ymm;
    gboolean avx512f;
    gboolean avx512bw;
    gboolean avx512cd;
    gboolean avx512dq;
    gboolean avx512vl;
    gboolean xcr0_opmask;
    gboolean xcr0_zmm_hi256;
    gboolean xcr0_hi16_zmm;
    gboolean aarch64_crc32;
    gboolean aarch64_lse_atomics;
    gboolean aarch64_rdma;
} ProtonPlusCpuFeatureProbe;

void protonplus_cpu_get_feature_probe (ProtonPlusCpuFeatureProbe *out_probe);
