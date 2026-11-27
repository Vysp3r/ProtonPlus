#include "lutris-yaml.h"

#include <string.h>
#include <yaml.h>

/* Keep the parser events so tags, aliases, and scalar styles survive a save.
 * next skips a whole value, including nested mappings and sequences. */
typedef struct {
    yaml_event_t event;
    guint next;
} YamlEvent;

struct LutrisYaml {
    char *source;
    GArray *events;
};

static void clear_event(gpointer data)
{
    YamlEvent *entry = data;
    yaml_event_delete(&entry->event);
}

static YamlEvent *at(LutrisYaml *yaml, guint index)
{
    return &g_array_index(yaml->events, YamlEvent, index);
}

static gboolean scalar_is(const yaml_event_t *event, const char *value)
{
    return event->type == YAML_SCALAR_EVENT &&
        !strcmp((const char *)event->data.scalar.value, value);
}

static gboolean is_mapping(LutrisYaml *yaml, guint index)
{
    return yaml && index && index < yaml->events->len &&
        at(yaml, index)->event.type == YAML_MAPPING_START_EVENT;
}

/* Reject ambiguous keys in the mappings we address. In particular a YAML
 * merge could silently restore a version after removing its local key. */
static gboolean addressable_mapping(LutrisYaml *yaml, guint mapping)
{
    if (!is_mapping(yaml, mapping))
        return FALSE;

    g_autoptr(GHashTable) keys = g_hash_table_new(g_str_hash, g_str_equal);
    guint end = at(yaml, mapping)->next - 1;
    for (guint i = mapping + 1; i < end; i = at(yaml, i + 1)->next) {
        const yaml_event_t *event = &at(yaml, i)->event;
        if (event->type != YAML_SCALAR_EVENT || scalar_is(event, "<<") ||
            !g_hash_table_add(keys, event->data.scalar.value))
            return FALSE;
    }
    return TRUE;
}

static guint lookup(LutrisYaml *yaml, guint mapping, const char *key)
{
    if (!is_mapping(yaml, mapping))
        return 0;

    guint end = at(yaml, mapping)->next - 1;
    for (guint i = mapping + 1; i < end; i = at(yaml, i + 1)->next) {
        if (scalar_is(&at(yaml, i)->event, key))
            return i;
    }
    return 0;
}

LutrisYaml *lutris_yaml_parse(const char *source)
{
    /* Compose once as well to validate anchor references. */
    yaml_parser_t parser;
    yaml_document_t document;
    if (!yaml_parser_initialize(&parser))
        return NULL;
    yaml_parser_set_input_string(&parser, (const unsigned char *)source, strlen(source));
    gboolean valid = yaml_parser_load(&parser, &document);
    if (valid)
        yaml_document_delete(&document);
    yaml_parser_delete(&parser);
    if (!valid || !yaml_parser_initialize(&parser))
        return NULL;

    LutrisYaml *yaml = g_new0(LutrisYaml, 1);
    yaml->source = g_strdup(source);
    yaml->events = g_array_new(FALSE, FALSE, sizeof(YamlEvent));
    g_array_set_clear_func(yaml->events, clear_event);
    g_autoptr(GArray) stack = g_array_new(FALSE, FALSE, sizeof(guint));
    yaml_parser_set_input_string(&parser, (const unsigned char *)source, strlen(source));
    YamlEvent entry = {0};
    guint documents = 0;
    while ((valid = yaml_parser_parse(&parser, &entry.event))) {
        guint index = yaml->events->len;
        entry.next = index + 1;
        g_array_append_val(yaml->events, entry);
        switch (entry.event.type) {
        case YAML_DOCUMENT_START_EVENT:
            documents++;
            break;
        case YAML_MAPPING_START_EVENT:
        case YAML_SEQUENCE_START_EVENT:
            g_array_append_val(stack, index);
            break;
        case YAML_MAPPING_END_EVENT:
        case YAML_SEQUENCE_END_EVENT:
            at(yaml, g_array_index(stack, guint, stack->len - 1))->next = index + 1;
            g_array_set_size(stack, stack->len - 1);
            break;
        default:
            break;
        }
        if (entry.event.type == YAML_STREAM_END_EVENT)
            break;
    }
    yaml_parser_delete(&parser);

    if (!valid || documents != 1 || !addressable_mapping(yaml, 2)) {
        lutris_yaml_free(yaml);
        return NULL;
    }
    const char *sections[] = {"game", "wine"};
    for (guint i = 0; i < G_N_ELEMENTS(sections); i++) {
        guint key = lookup(yaml, 2, sections[i]);
        if (key && !addressable_mapping(yaml, key + 1)) {
            lutris_yaml_free(yaml);
            return NULL;
        }
    }
    return yaml;
}

void lutris_yaml_free(LutrisYaml *yaml)
{
    g_array_unref(yaml->events);
    g_free(yaml->source);
    g_free(yaml);
}

gboolean lutris_yaml_has_scalar(LutrisYaml *yaml, const char *section, const char *key)
{
    guint group = lookup(yaml, 2, section);
    guint item = group ? lookup(yaml, group + 1, key) : 0;
    if (!item)
        return TRUE;
    yaml_event_t *event = &at(yaml, item + 1)->event;
    return event->type == YAML_SCALAR_EVENT &&
        (!event->data.scalar.tag || !strcmp((char *)event->data.scalar.tag, YAML_STR_TAG));
}

const char *lutris_yaml_get(LutrisYaml *yaml, const char *section, const char *key)
{
    guint group = lookup(yaml, 2, section);
    guint item = group ? lookup(yaml, group + 1, key) : 0;
    if (!item || !lutris_yaml_has_scalar(yaml, section, key))
        return NULL;
    yaml_event_t *event = &at(yaml, item + 1)->event;
    const char *value = (const char *)event->data.scalar.value;
    if (strlen(value) != event->data.scalar.length)
        return NULL;
    if (event->data.scalar.plain_implicit &&
        (!*value || !g_ascii_strcasecmp(value, "null") || !strcmp(value, "~")))
        return NULL;
    return value;
}

static int append_output(void *data, unsigned char *buffer, size_t size)
{
    g_string_append_len(data, (const char *)buffer, size);
    return 1;
}

static gboolean emit_scalar(yaml_emitter_t *emitter, const char *value)
{
    yaml_event_t event;
    return yaml_scalar_event_initialize(&event, NULL, NULL,
        (const unsigned char *)value, -1, 0, 1, YAML_DOUBLE_QUOTED_SCALAR_STYLE) &&
        yaml_emitter_emit(emitter, &event);
}

static gboolean emit_setting(yaml_emitter_t *emitter, const char *setting, const char *raw)
{
    yaml_parser_t parser;
    if (!yaml_parser_initialize(&parser))
        return FALSE;

    yaml_parser_set_input_string(&parser, (const unsigned char *)raw, strlen(raw));
    gboolean success = emit_scalar(emitter, setting);
    yaml_event_t event;
    while (success && (success = yaml_parser_parse(&parser, &event))) {
        yaml_event_type_t type = event.type;
        if (type == YAML_STREAM_START_EVENT || type == YAML_STREAM_END_EVENT ||
            type == YAML_DOCUMENT_START_EVENT || type == YAML_DOCUMENT_END_EVENT)
            yaml_event_delete(&event);
        else
            success = yaml_emitter_emit(emitter, &event);
        if (type == YAML_STREAM_END_EVENT)
            break;
    }
    yaml_parser_delete(&parser);
    return success;
}

static gboolean section_editable(LutrisYaml *yaml, guint section_key)
{
    if (at(yaml, 2)->event.data.mapping_start.anchor)
        return FALSE;
    if (!section_key)
        return TRUE;
    return addressable_mapping(yaml, section_key + 1) &&
        !at(yaml, section_key)->event.data.scalar.anchor &&
        !at(yaml, section_key + 1)->event.data.mapping_start.anchor;
}

gboolean lutris_yaml_setting_editable(LutrisYaml *yaml, const char *section, const char *setting)
{
    guint section_key = lookup(yaml, 2, section);
    if (!section_editable(yaml, section_key))
        return FALSE;
    guint item = section_key ? lookup(yaml, section_key + 1, setting) : 0;
    return !item || (lutris_yaml_has_scalar(yaml, section, setting) &&
        !at(yaml, item)->event.data.scalar.anchor && !at(yaml, item + 1)->event.data.scalar.anchor);
}

int lutris_yaml_get_toggle(LutrisYaml *yaml, const char *setting)
{
    guint section = lookup(yaml, 2, "wine");
    guint item = lookup(yaml, section ? section + 1 : 0, setting);
    if (!item)
        return -1;
    yaml_event_t *event = &at(yaml, item + 1)->event;
    if (event->type != YAML_SCALAR_EVENT ||
        (event->data.scalar.tag && strcmp((const char *)event->data.scalar.tag, YAML_BOOL_TAG)) ||
        (!event->data.scalar.tag && !event->data.scalar.plain_implicit))
        return -2;
    const char *value = (const char *)event->data.scalar.value;
    if (!g_ascii_strcasecmp(value, "true") || !g_ascii_strcasecmp(value, "yes") || !g_ascii_strcasecmp(value, "on"))
        return 1;
    if (!g_ascii_strcasecmp(value, "false") || !g_ascii_strcasecmp(value, "no") || !g_ascii_strcasecmp(value, "off"))
        return 0;
    return -2;
}

gboolean lutris_yaml_toggle_editable(LutrisYaml *yaml, const char *setting)
{
    guint group = lookup(yaml, 2, "wine");
    guint item = lookup(yaml, group ? group + 1 : 0, setting);
    return section_editable(yaml, group) && lutris_yaml_get_toggle(yaml, setting) != -2 &&
        (!item || (!at(yaml, item)->event.data.scalar.anchor && !at(yaml, item + 1)->event.data.scalar.anchor));
}

static void append_quoted(GString *output, const char *value)
{
    g_string_append_c(output, '"');
    for (const unsigned char *p = (const unsigned char *)value; *p; p++) {
        if (*p == '"' || *p == '\\')
            g_string_append_c(output, '\\');
        if (*p < 0x20)
            g_string_append_printf(output, "\\u%04x", (unsigned int)*p);
        else
            g_string_append_c(output, (char)*p);
    }
    g_string_append_c(output, '"');
}

/* Settings edited as NAME=value lines require a plain map of scalar strings. */
char *lutris_yaml_get_environment(LutrisYaml *yaml)
{
    guint system_key = lookup(yaml, 2, "system");
    if (!section_editable(yaml, system_key))
        return NULL;
    guint env = system_key ? lookup(yaml, system_key + 1, "env") : 0;
    if (!env)
        return g_strdup("{}");
    if (at(yaml, env)->event.data.scalar.anchor || !addressable_mapping(yaml, env + 1) ||
        at(yaml, env + 1)->event.data.mapping_start.anchor)
        return NULL;

    GString *output = g_string_new("{");
    for (guint i = env + 2; i < at(yaml, env + 1)->next - 1; i += 2) {
        yaml_event_t *key = &at(yaml, i)->event;
        yaml_event_t *value = &at(yaml, i + 1)->event;
        if (value->type != YAML_SCALAR_EVENT || key->data.scalar.anchor || value->data.scalar.anchor ||
            key->data.scalar.tag || (value->data.scalar.tag && strcmp((const char *)value->data.scalar.tag, YAML_STR_TAG)))
            return g_string_free(output, TRUE);

        const char *name = (const char *)key->data.scalar.value;
        const char *text = (const char *)value->data.scalar.value;
        if (strlen(name) != key->data.scalar.length || strlen(text) != value->data.scalar.length ||
            (value->data.scalar.plain_implicit &&
                (!*text || !g_ascii_strcasecmp(text, "null") || !strcmp(text, "~"))))
            return g_string_free(output, TRUE);
        if (i > env + 2)
            g_string_append_c(output, ',');
        append_quoted(output, name);
        g_string_append_c(output, ':');
        append_quoted(output, text);
    }
    g_string_append_c(output, '}');
    return g_string_free(output, FALSE);
}

static yaml_event_t *value_end(LutrisYaml *yaml, guint index)
{
    YamlEvent *value = at(yaml, index);
    gboolean block = value->event.type == YAML_MAPPING_START_EVENT &&
        value->event.data.mapping_start.style == YAML_BLOCK_MAPPING_STYLE;
    return &at(yaml, value->next - (block ? 2 : 1))->event;
}

/* Preserve comments and formatting outside the replacement's source range. */
static char *replace_inline_value(LutrisYaml *yaml, guint index, const char *raw)
{
    yaml_event_t *value = &at(yaml, index)->event;
    yaml_event_t *last = value_end(yaml, index);
    if (value->start_mark.index == last->end_mark.index ||
        (value->type == YAML_SCALAR_EVENT &&
            (value->start_mark.line != last->end_mark.line ||
             value->data.scalar.style == YAML_LITERAL_SCALAR_STYLE ||
             value->data.scalar.style == YAML_FOLDED_SCALAR_STYLE)))
        return NULL;

    const char *start = g_utf8_offset_to_pointer(yaml->source, value->start_mark.index);
    const char *end = g_utf8_offset_to_pointer(start, last->end_mark.index - value->start_mark.index);
    GString *output = g_string_new_len(yaml->source, start - yaml->source);
    g_string_append(output, raw);
    g_string_append(output, end);
    return g_string_free(output, FALSE);
}

/* An inline block entry can be removed without regenerating the document. */
static char *remove_block_setting(LutrisYaml *yaml, guint group, guint index)
{
    yaml_event_t *mapping = &at(yaml, group)->event;
    yaml_event_t *key = &at(yaml, index)->event;
    yaml_event_t *value = &at(yaml, index + 1)->event;
    yaml_event_t *last = value_end(yaml, index + 1);
    if (mapping->data.mapping_start.style != YAML_BLOCK_MAPPING_STYLE ||
        (value->type == YAML_SCALAR_EVENT && key->start_mark.line != last->end_mark.line))
        return NULL;

    const char *start = g_utf8_offset_to_pointer(yaml->source, key->start_mark.index);
    const char *end = g_utf8_offset_to_pointer(yaml->source, last->end_mark.index);
    const char *line_start = start;
    while (line_start > yaml->source && line_start[-1] == ' ')
        line_start--;
    if (line_start > yaml->source && line_start[-1] != '\n' && line_start[-1] != '\r')
        return NULL;

    const char *comment = end;
    while (*comment == ' ' || *comment == '\t')
        comment++;
    if (*comment && *comment != '#' && *comment != '\r' && *comment != '\n')
        return NULL;

    gboolean only_entry = at(yaml, group)->next == at(yaml, index + 1)->next + 1 && index == group + 1;
    if (only_entry || *comment == '#') {
        GString *output = g_string_new_len(yaml->source, start - yaml->source);
        if (only_entry)
            g_string_append(output, "{}");
        g_string_append(output, only_entry ? end : comment);
        return g_string_free(output, FALSE);
    }

    if (*comment == '\r')
        comment++;
    if (*comment == '\n')
        comment++;
    GString *output = g_string_new_len(yaml->source, line_start - yaml->source);
    g_string_append(output, comment);
    return g_string_free(output, FALSE);
}

static char *remove_flow_setting(LutrisYaml *yaml, guint group, guint index)
{
    if (at(yaml, group)->event.data.mapping_start.style != YAML_FLOW_MAPPING_STYLE)
        return NULL;

    yaml_event_t *key = &at(yaml, index)->event;
    const char *start = g_utf8_offset_to_pointer(yaml->source, key->start_mark.index);
    yaml_event_t *last = &at(yaml, at(yaml, index + 1)->next - 1)->event;
    const char *end = g_utf8_offset_to_pointer(yaml->source, last->end_mark.index);
    const char *previous = start;
    while (previous > yaml->source && g_ascii_isspace(previous[-1]))
        previous--;
    if (previous == yaml->source || (previous[-1] != '{' && previous[-1] != ','))
        return NULL;
    const char *separator = end;
    while (g_ascii_isspace(*separator))
        separator++;

    guint mapping_end = at(yaml, group)->next - 1;
    gboolean has_next = at(yaml, index + 1)->next < mapping_end;
    if (has_next || index == group + 1) {
        if (*separator == ',') {
            end = separator + 1;
            while (*end == ' ' || *end == '\t')
                end++;
        } else if (has_next || *separator != '}') {
            return NULL;
        }
    } else {
        if (previous[-1] != ',')
            return NULL;
        start = previous - 1;
    }

    GString *output = g_string_new_len(yaml->source, start - yaml->source);
    g_string_append(output, end);
    return g_string_free(output, FALSE);
}

static char *insert_setting(LutrisYaml *yaml, guint group, const char *section, const char *setting, const char *raw)
{
    guint target = group ? group : 2;
    YamlEvent *mapping = at(yaml, target);
    if (mapping->event.data.mapping_start.style == YAML_FLOW_MAPPING_STYLE) {
        const char *start = g_utf8_offset_to_pointer(yaml->source, mapping->event.end_mark.index);
        GString *output = g_string_new_len(yaml->source, start - yaml->source);
        if (!group)
            g_string_append_printf(output, "%s: {", section);
        g_string_append_printf(output, "%s: ", setting);
        g_string_append(output, raw);
        if (!group)
            g_string_append_c(output, '}');
        if (mapping->next != target + 2)
            g_string_append(output, ", ");
        g_string_append(output, start);
        return g_string_free(output, FALSE);
    }

    yaml_event_t *first_key = &at(yaml, target + 1)->event;
    if (first_key->type != YAML_SCALAR_EVENT)
        return NULL;
    const char *start = g_utf8_offset_to_pointer(yaml->source, first_key->start_mark.index);
    const char *line_start = start;
    while (line_start > yaml->source && line_start[-1] == ' ')
        line_start--;
    if (line_start > yaml->source && line_start[-1] != '\n' && line_start[-1] != '\r')
        return NULL;
    const char *newline = strstr(yaml->source, "\r\n") ? "\r\n" : "\n";
    GString *output = g_string_new_len(yaml->source, start - yaml->source);
    if (!group) {
        g_string_append_printf(output, "%s:", section);
        g_string_append(output, newline);
        g_string_append_len(output, line_start, start - line_start);
        g_string_append(output, "  ");
    }
    g_string_append_printf(output, "%s: ", setting);
    g_string_append(output, raw);
    g_string_append(output, newline);
    g_string_append(output, line_start);
    return g_string_free(output, FALSE);
}

static char *set_node(LutrisYaml *yaml, const char *section, const char *setting, const char *raw)
{
    guint key = lookup(yaml, 2, section);
    guint group = key ? key + 1 : 0;
    guint item = lookup(yaml, group, setting);
    if (!item && !raw)
        return g_strdup(yaml->source);
    if (item) {
        char *patched = raw ? replace_inline_value(yaml, item + 1, raw)
            : remove_block_setting(yaml, group, item);
        if (!patched && !raw)
            patched = remove_flow_setting(yaml, group, item);
        if (patched)
            return patched;
    } else if (raw) {
        char *patched = insert_setting(yaml, group, section, setting, raw);
        if (patched)
            return patched;
    }

    yaml_parser_t parser;
    yaml_emitter_t emitter;
    if (!yaml_parser_initialize(&parser))
        return NULL;
    if (!yaml_emitter_initialize(&emitter)) {
        yaml_parser_delete(&parser);
        return NULL;
    }

    GString *output = g_string_new(NULL);
    yaml_emitter_set_output(&emitter, append_output, output);
    yaml_emitter_set_unicode(&emitter, 1);
    yaml_parser_set_input_string(&parser, (const unsigned char *)yaml->source, strlen(yaml->source));
    guint insert_at = item ? item : at(yaml, group ? group : 2)->next - 1;
    gboolean success = TRUE;
    for (guint i = 0; success && i < yaml->events->len; i++) {
        yaml_event_t event;
        success = yaml_parser_parse(&parser, &event);
        if (!success)
            break;
        if (i == insert_at && raw) {
            if (!group) {
                yaml_event_t mapping;
                success = emit_scalar(&emitter, section) &&
                    yaml_mapping_start_event_initialize(&mapping, NULL, NULL, 1, YAML_BLOCK_MAPPING_STYLE) &&
                    yaml_emitter_emit(&emitter, &mapping) && emit_setting(&emitter, setting, raw) &&
                    yaml_mapping_end_event_initialize(&mapping) && yaml_emitter_emit(&emitter, &mapping);
            } else {
                success = emit_setting(&emitter, setting, raw);
            }
        }
        if (!success || (item && (i >= item && i < at(yaml, item + 1)->next)))
            yaml_event_delete(&event);
        else
            success = yaml_emitter_emit(&emitter, &event);
    }
    yaml_emitter_delete(&emitter);
    yaml_parser_delete(&parser);
    return g_string_free(output, !success);
}

char *lutris_yaml_set_setting(LutrisYaml *yaml, const char *section, const char *setting,
    const char *value, gboolean boolean)
{
    if (boolean) {
        if (strcmp(section, "wine") || !lutris_yaml_toggle_editable(yaml, setting))
            return NULL;
    } else if (!lutris_yaml_setting_editable(yaml, section, setting)) {
        return NULL;
    }
    if (!value)
        return set_node(yaml, section, setting, NULL);
    if (boolean) {
        if (strcmp(value, "true") && strcmp(value, "false"))
            return NULL;
        return set_node(yaml, section, setting, value);
    }

    GString *quoted = g_string_new(NULL);
    append_quoted(quoted, value);
    char *updated = set_node(yaml, section, setting, quoted->str);
    g_string_free(quoted, TRUE);
    return updated;
}

char *lutris_yaml_set_environment(LutrisYaml *yaml, const char *mapping_json)
{
    g_autofree char *existing = lutris_yaml_get_environment(yaml);
    if (!existing)
        return NULL;
    return set_node(yaml, "system", "env", mapping_json);
}
