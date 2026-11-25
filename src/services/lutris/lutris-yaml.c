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

static gboolean emit_version(yaml_emitter_t *emitter, const char *version)
{
    return emit_scalar(emitter, "version") && emit_scalar(emitter, version);
}

gboolean lutris_yaml_version_editable(LutrisYaml *yaml)
{
    guint key = lookup(yaml, 2, "wine");
    guint wine = key ? key + 1 : 0;
    guint version_key = lookup(yaml, wine, "version");
    if (version_key) {
        yaml_event_t *key_event = &at(yaml, version_key)->event;
        yaml_event_t *value_event = &at(yaml, version_key + 1)->event;
        if (!lutris_yaml_has_scalar(yaml, "wine", "version") ||
            key_event->data.scalar.anchor || value_event->data.scalar.anchor)
            return FALSE;
    }
    /* Editing a shared wine mapping would also change alias consumers. */
    return (!wine || !at(yaml, wine)->event.data.mapping_start.anchor) &&
        !at(yaml, 2)->event.data.mapping_start.anchor;
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

/* Preserve comments and formatting when changing an existing inline scalar. */
static char *replace_inline_value(LutrisYaml *yaml, guint index, const char *version)
{
    yaml_event_t *value = &at(yaml, index)->event;
    if (value->start_mark.line != value->end_mark.line ||
        value->start_mark.index == value->end_mark.index ||
        value->data.scalar.style == YAML_LITERAL_SCALAR_STYLE ||
        value->data.scalar.style == YAML_FOLDED_SCALAR_STYLE)
        return NULL;

    const char *start = g_utf8_offset_to_pointer(yaml->source, value->start_mark.index);
    const char *end = g_utf8_offset_to_pointer(start, value->end_mark.index - value->start_mark.index);
    GString *output = g_string_new_len(yaml->source, start - yaml->source);
    append_quoted(output, version);
    g_string_append(output, end);
    return g_string_free(output, FALSE);
}

/* An inline block entry can be removed without regenerating the document. */
static char *remove_block_version(LutrisYaml *yaml, guint wine, guint index)
{
    yaml_event_t *mapping = &at(yaml, wine)->event;
    yaml_event_t *key = &at(yaml, index)->event;
    yaml_event_t *value = &at(yaml, index + 1)->event;
    if (mapping->data.mapping_start.style != YAML_BLOCK_MAPPING_STYLE ||
        key->start_mark.line != value->end_mark.line)
        return NULL;

    const char *start = g_utf8_offset_to_pointer(yaml->source, key->start_mark.index);
    const char *end = g_utf8_offset_to_pointer(yaml->source, value->end_mark.index);
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

    gboolean only_entry = at(yaml, wine)->next == wine + 4;
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

static char *insert_version(LutrisYaml *yaml, guint wine, const char *version)
{
    guint target = wine ? wine : 2;
    YamlEvent *mapping = at(yaml, target);
    if (mapping->event.data.mapping_start.style == YAML_FLOW_MAPPING_STYLE) {
        const char *start = g_utf8_offset_to_pointer(yaml->source, mapping->event.end_mark.index);
        GString *output = g_string_new_len(yaml->source, start - yaml->source);
        g_string_append(output, wine ? "version: " : "wine: {version: ");
        append_quoted(output, version);
        if (!wine)
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
    if (!wine) {
        g_string_append(output, "wine:");
        g_string_append(output, newline);
        g_string_append_len(output, line_start, start - line_start);
        g_string_append(output, "  ");
    }
    g_string_append(output, "version: ");
    append_quoted(output, version);
    g_string_append(output, newline);
    g_string_append(output, line_start);
    return g_string_free(output, FALSE);
}

char *lutris_yaml_set_version(LutrisYaml *yaml, const char *version)
{
    if (!lutris_yaml_version_editable(yaml))
        return NULL;
    guint key = lookup(yaml, 2, "wine");
    guint wine = key ? key + 1 : 0;
    guint version_key = lookup(yaml, wine, "version");
    if (!version_key && !version)
        return g_strdup(yaml->source);
    if (version_key) {
        char *patched = version ? replace_inline_value(yaml, version_key + 1, version)
            : remove_block_version(yaml, wine, version_key);
        if (patched)
            return patched;
    } else if (version) {
        char *patched = insert_version(yaml, wine, version);
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
    guint insert_at = version_key ? version_key : at(yaml, wine ? wine : 2)->next - 1;
    gboolean success = TRUE;
    for (guint i = 0; success && i < yaml->events->len; i++) {
        yaml_event_t event;
        success = yaml_parser_parse(&parser, &event);
        if (!success)
            break;
        if (i == insert_at && version) {
            if (!wine) {
                yaml_event_t mapping;
                success = emit_scalar(&emitter, "wine") &&
                    yaml_mapping_start_event_initialize(&mapping, NULL, NULL, 1, YAML_BLOCK_MAPPING_STYLE) &&
                    yaml_emitter_emit(&emitter, &mapping) && emit_version(&emitter, version) &&
                    yaml_mapping_end_event_initialize(&mapping) && yaml_emitter_emit(&emitter, &mapping);
            } else {
                success = emit_version(&emitter, version);
            }
        }
        if (!success || (version_key && (i == version_key || i == version_key + 1)))
            yaml_event_delete(&event);
        else
            success = yaml_emitter_emit(&emitter, &event);
    }
    yaml_emitter_delete(&emitter);
    yaml_parser_delete(&parser);
    return g_string_free(output, !success);
}
