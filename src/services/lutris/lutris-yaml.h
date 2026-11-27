#pragma once

#include <glib.h>

typedef struct LutrisYaml LutrisYaml;

LutrisYaml *lutris_yaml_parse(const char *source);
void lutris_yaml_free(LutrisYaml *yaml);
gboolean lutris_yaml_has_scalar(LutrisYaml *yaml, const char *section, const char *key);
const char *lutris_yaml_get(LutrisYaml *yaml, const char *section, const char *key);
int lutris_yaml_get_toggle(LutrisYaml *yaml, const char *section, const char *setting);
gboolean lutris_yaml_toggle_editable(LutrisYaml *yaml, const char *section, const char *setting);
gboolean lutris_yaml_setting_editable(LutrisYaml *yaml, const char *section, const char *setting);
char *lutris_yaml_set_setting(LutrisYaml *yaml, const char *section, const char *setting, const char *value, gboolean boolean);
char *lutris_yaml_get_environment(LutrisYaml *yaml);
char *lutris_yaml_set_environment(LutrisYaml *yaml, const char *mapping_json);
