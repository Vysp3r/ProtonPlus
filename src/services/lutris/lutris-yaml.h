#pragma once

#include <glib.h>

typedef struct LutrisYaml LutrisYaml;

LutrisYaml *lutris_yaml_parse(const char *source);
void lutris_yaml_free(LutrisYaml *yaml);
gboolean lutris_yaml_has_scalar(LutrisYaml *yaml, const char *section, const char *key);
const char *lutris_yaml_get(LutrisYaml *yaml, const char *section, const char *key);
gboolean lutris_yaml_version_editable(LutrisYaml *yaml);
char *lutris_yaml_set_version(LutrisYaml *yaml, const char *version);
