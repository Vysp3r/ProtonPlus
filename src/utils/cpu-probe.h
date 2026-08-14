#pragma once

#include <glib.h>

typedef struct _ProtonPlusCpuFeatureProbe ProtonPlusCpuFeatureProbe;

void protonplus_cpu_get_feature_probe (ProtonPlusCpuFeatureProbe *out_probe);
