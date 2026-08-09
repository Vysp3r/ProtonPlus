#include "cpu-probe.h"

#include <stdint.h>

#if defined(__aarch64__) && defined(__linux__)
#include <asm/hwcap.h>
#include <sys/auxv.h>
#endif

#if (defined(__x86_64__) || defined(_M_X64)) && (defined(__GNUC__) || defined(__clang__))
#include <cpuid.h>

static uint64_t
read_xcr0 (void)
{
    uint32_t eax;
    uint32_t edx;

    __asm__ volatile (".byte 0x0f, 0x01, 0xd0"
                      : "=a" (eax), "=d" (edx)
                      : "c" (0));
    return ((uint64_t) edx << 32) | eax;
}
#endif

void
protonplus_cpu_get_feature_probe (ProtonPlusCpuFeatureProbe *out_probe)
{
    ProtonPlusCpuFeatureProbe probe = { 0 };

#if (defined(__x86_64__) || defined(_M_X64)) && (defined(__GNUC__) || defined(__clang__))
    unsigned int eax;
    unsigned int ebx;
    unsigned int ecx;
    unsigned int edx;
    unsigned int max_extended;
    uint64_t xcr0 = 0;

    if (!__get_cpuid (1, &eax, &ebx, &ecx, &edx)) {
        *out_probe = probe;
        return;
    }

    probe.available = TRUE;
    probe.cmpxchg16b = (ecx & bit_CMPXCHG16B) != 0;
    probe.popcnt = (ecx & bit_POPCNT) != 0;
    probe.sse3 = (ecx & bit_SSE3) != 0;
    probe.sse4_1 = (ecx & bit_SSE4_1) != 0;
    probe.sse4_2 = (ecx & bit_SSE4_2) != 0;
    probe.ssse3 = (ecx & bit_SSSE3) != 0;
    probe.avx = (ecx & bit_AVX) != 0;
    probe.f16c = (ecx & bit_F16C) != 0;
    probe.fma = (ecx & bit_FMA) != 0;
    probe.movbe = (ecx & bit_MOVBE) != 0;
    probe.osxsave = (ecx & bit_OSXSAVE) != 0;

    if (probe.osxsave)
        xcr0 = read_xcr0 ();
    probe.xcr0_xmm = (xcr0 & (1u << 1)) != 0;
    probe.xcr0_ymm = (xcr0 & (1u << 2)) != 0;
    probe.xcr0_opmask = (xcr0 & (1u << 5)) != 0;
    probe.xcr0_zmm_hi256 = (xcr0 & (1u << 6)) != 0;
    probe.xcr0_hi16_zmm = (xcr0 & (1u << 7)) != 0;

    if (__get_cpuid_max (0, NULL) >= 7) {
        __cpuid_count (7, 0, eax, ebx, ecx, edx);
        probe.bmi1 = (ebx & bit_BMI) != 0;
        probe.avx2 = (ebx & bit_AVX2) != 0;
        probe.bmi2 = (ebx & bit_BMI2) != 0;
        probe.avx512f = (ebx & bit_AVX512F) != 0;
        probe.avx512dq = (ebx & bit_AVX512DQ) != 0;
        probe.avx512cd = (ebx & bit_AVX512CD) != 0;
        probe.avx512bw = (ebx & bit_AVX512BW) != 0;
        probe.avx512vl = (ebx & bit_AVX512VL) != 0;
    }

    max_extended = __get_cpuid_max (0x80000000, NULL);
    if (max_extended >= 0x80000001) {
        __cpuid (0x80000001, eax, ebx, ecx, edx);
        probe.lahf_sahf = (ecx & bit_LAHF_LM) != 0;
        probe.lzcnt = (ecx & bit_LZCNT) != 0;
    }
#elif defined(__aarch64__) && defined(__linux__)
    probe.available = TRUE;
    {
        /* GCC's generic Armv8.1-A target enables CRC, LSE, and RDM. Require
         * all three kernel-exposed capabilities before accepting that ABI. */
        unsigned long hwcaps = getauxval (AT_HWCAP);
        probe.aarch64_crc32 = (hwcaps & HWCAP_CRC32) != 0;
        probe.aarch64_lse_atomics = (hwcaps & HWCAP_ATOMICS) != 0;
        probe.aarch64_rdma = (hwcaps & HWCAP_ASIMDRDM) != 0;
    }
#endif

    *out_probe = probe;
}
