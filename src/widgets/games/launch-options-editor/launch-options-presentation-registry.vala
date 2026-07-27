namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    public class LaunchOptionPresentation : Object {
        public LaunchOptionMetadata metadata { get; construct; }
        public ILaunchOption? option { get; set; }
        public bool movable { get; construct; }
        public bool currently_visible { get; set; default = false; }
        public Gee.ArrayList<Gtk.Widget> widgets { get; private set; }

        public LaunchOptionPresentation (LaunchOptionMetadata metadata, ILaunchOption? option, bool movable) {
            Object (metadata: metadata, option: option, movable: movable);
            widgets = new Gee.ArrayList<Gtk.Widget> ();
        }

        public bool is_active () {
            return option != null && option.is_active ();
        }

        public void add_widget (Gtk.Widget widget) {
            if (!widgets.contains (widget))
                widgets.add (widget);
        }

        public void apply_metadata (bool searching) {
            foreach (var widget in widgets) {
                var row = widget as Adw.PreferencesRow;
                if (row == null)
                    continue;

                row.title = metadata.title;
                var context = metadata.subsection != "" ? metadata.subsection : LaunchOptionCatalog.category_title (metadata.category);
                var detail = metadata.description;
                if (searching)
                    detail = "%s — %s".printf (context, detail);
                if (metadata.expertise == LaunchOptionExpertise.ADVANCED)
                    detail = "%s • %s".printf (detail, _("Advanced"));
                else if (metadata.expertise == LaunchOptionExpertise.EXPERIMENTAL)
                    detail = "%s • %s".printf (detail, _("Experimental"));
                if (metadata.applicability != "")
                    detail = "%s • %s".printf (detail, metadata.applicability);
                if (metadata.dependencies.length > 0)
                    detail = "%s • %s".printf (detail, _("Requires related option"));
                if (!widget.sensitive)
                    detail = "%s • %s".printf (detail, _("Unavailable on this system"));
                var action_row = widget as Adw.ActionRow;
                if (action_row != null)
                    action_row.subtitle = detail;
                var expander_row = widget as Adw.ExpanderRow;
                if (expander_row != null)
                    expander_row.subtitle = detail;
            }
        }
    }

    public class LaunchOptionPresentationRegistry : Object {
        LaunchOptionCatalog catalog;
        Gee.HashMap<string, LaunchOptionPresentation> by_id;

        public LaunchOptionPresentationRegistry (LaunchOptionCatalog catalog) {
            this.catalog = catalog;
            by_id = new Gee.HashMap<string, LaunchOptionPresentation> ();
        }

        public void register (string id, Gtk.Widget? widget, ILaunchOption? option, bool movable = true) {
            var presentation = by_id.get (id);
            if (presentation == null) {
                var metadata = catalog.lookup (id);
                assert (metadata != null);
                presentation = new LaunchOptionPresentation (metadata, option, movable);
                by_id.set (id, presentation);
            } else if (option != null) {
                presentation.option = option;
            }
            if (widget != null)
                presentation.add_widget (widget);
        }

        public LaunchOptionPresentation? lookup (string id) {
            return by_id.get (id);
        }

        public Gee.List<LaunchOptionPresentation> get_ordered () {
            var presentations = new Gee.ArrayList<LaunchOptionPresentation> ();
            foreach (var metadata in catalog.get_ordered ()) {
                var presentation = by_id.get (metadata.id);
                if (presentation != null)
                    presentations.add (presentation);
            }
            return presentations;
        }

        public bool has_visible_in_category (LaunchOptionCategory category) {
            foreach (var presentation in by_id.values) {
                if (presentation.metadata.category == category && presentation.currently_visible)
                    return true;
            }
            return false;
        }

        public bool has_registered_in_category (LaunchOptionCategory category) {
            foreach (var presentation in by_id.values) {
                if (presentation.metadata.category == category)
                    return true;
            }
            return false;
        }

        public bool has_visible_in_subsection (LaunchOptionCategory category, string subsection) {
            foreach (var presentation in by_id.values) {
                if (presentation.metadata.category == category
                    && presentation.metadata.subsection == subsection
                    && presentation.currently_visible)
                    return true;
            }
            return false;
        }

        public void apply_filter (LaunchOptionView view, string query) {
            var searching = query.strip () != "";
            foreach (var presentation in get_ordered ()) {
                var active = presentation.is_active ();
                var visible = catalog.should_display (presentation.metadata, view, query, active);
                presentation.currently_visible = visible;

                foreach (var widget in presentation.widgets)
                    widget.visible = visible;
                presentation.apply_metadata (searching);
            }
        }

    }
}
