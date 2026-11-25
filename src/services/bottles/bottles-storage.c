#include "bottles-storage.h"

#include <glib.h>
#include <string.h>
#include <yaml.h>

/* The CLI's bottles-path command reports the default storage root before
 * the Bottles manager applies the custom_bottles_path setting. */
char *protonplus_bottles_custom_root(const char *contents)
{
    yaml_parser_t parser;
    yaml_document_t document;
    if (!yaml_parser_initialize(&parser))
        return NULL;

    yaml_parser_set_input_string(&parser, (const unsigned char *)contents, strlen(contents));
    gboolean parsed = yaml_parser_load(&parser, &document);
    yaml_parser_delete(&parser);
    if (!parsed)
        return NULL;

    char *path = NULL;
    yaml_node_t *root = yaml_document_get_root_node(&document);
    if (root && root->type == YAML_MAPPING_NODE) {
        for (yaml_node_pair_t *pair = root->data.mapping.pairs.start;
             pair < root->data.mapping.pairs.top; pair++) {
            yaml_node_t *key = yaml_document_get_node(&document, pair->key);
            if (key->type != YAML_SCALAR_NODE ||
                strcmp((const char *)key->data.scalar.value, "custom_bottles_path"))
                continue;
            yaml_node_t *value = yaml_document_get_node(&document, pair->value);
            if (value->type == YAML_SCALAR_NODE) {
                /* Only absolute overrides can be resolved across sandboxes. */
                const char *setting = (const char *)value->data.scalar.value;
                g_free(path);
                path = g_strdup(g_path_is_absolute(setting) ? setting : "");
            }
        }
        if (!path)
            path = g_strdup("");
    }
    yaml_document_delete(&document);
    return path;
}
