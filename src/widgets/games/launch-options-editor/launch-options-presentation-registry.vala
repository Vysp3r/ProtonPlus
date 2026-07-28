namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    public class LaunchOptionPresentation : Object {
        public LaunchOptionMetadata metadata { get; construct; }
        public ILaunchOption? option { get; set; }
        public bool movable { get; construct; }
        public bool currently_visible { get; set; default = false; }
        public LaunchOptionEligibility? eligibility { get; set; }
        public Gee.ArrayList<Gtk.Widget> widgets { get; private set; }
        public Gee.ArrayList<ILaunchCommandSelectionSource> selection_sources { get; private set; }

        public LaunchOptionPresentation (LaunchOptionMetadata metadata, ILaunchOption? option, bool movable) {
            Object (metadata: metadata, option: option, movable: movable);
            widgets = new Gee.ArrayList<Gtk.Widget> ();
            selection_sources = new Gee.ArrayList<ILaunchCommandSelectionSource> ();
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
                if (eligibility != null && eligibility.kind != LaunchOptionEligibilityKind.AVAILABLE)
                    detail = "%s • %s".printf (detail, eligibility.reason);
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
        Gee.ArrayList<ILaunchCommandSelectionSource> registered_selection_sources;

        public LaunchOptionPresentationRegistry (LaunchOptionCatalog catalog) {
            this.catalog = catalog;
            by_id = new Gee.HashMap<string, LaunchOptionPresentation> ();
            registered_selection_sources = new Gee.ArrayList<ILaunchCommandSelectionSource> ();
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
            var source = LaunchCommandSelectionAdapterFactory.create (id, widget, option);
            if (source != null)
                register_selection_source (id, source);
        }

        public void register_selection_source (string id, ILaunchCommandSelectionSource source) {
            registered_selection_sources.add (source);
            var presentation = by_id.get (id);
            if (presentation != null)
                presentation.selection_sources.add (source);
        }

        public Gee.List<ILaunchCommandSelectionSource> get_selection_sources () {
            return registered_selection_sources;
        }

        public Gee.List<string> validate_selection_sources () {
            var diagnostics = new Gee.ArrayList<string> ();
            var owners = new Gee.HashSet<string> ();
            foreach (var source in registered_selection_sources) {
                if (catalog.lookup (source.option_id) == null)
                    diagnostics.add ("Selection source registered for unknown option '%s'.".printf (source.option_id));
            }
            foreach (var presentation in get_ordered ()) {
                var semantics = presentation.metadata.semantics;
                if (semantics == null || !semantics.managed_emission)
                    continue;
                if (presentation.selection_sources.size == 0)
                    diagnostics.add ("Managed presentation '%s' has no selection source.".printf (presentation.metadata.id));
                if (presentation.selection_sources.size > 1)
                    diagnostics.add ("Managed presentation '%s' has duplicate selection ownership.".printf (presentation.metadata.id));
                foreach (var source in presentation.selection_sources) {
                    if (source.option_id != presentation.metadata.id)
                        diagnostics.add ("Selection source '%s' disagrees with presentation '%s'.".printf (
                            source.option_id, presentation.metadata.id));
                    if (owners.contains (source.option_id))
                        diagnostics.add ("Selection source '%s' has duplicate ownership.".printf (source.option_id));
                    owners.add (source.option_id);
                }
            }
            return diagnostics;
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

        public bool has_presentable_in_category (LaunchOptionCategory category) {
            foreach (var presentation in by_id.values) {
                if (presentation.metadata.category != category)
                    continue;
                var eligibility = presentation.eligibility;
                if (eligibility == null || eligibility.show_when_inactive
                    || (presentation.is_active () && eligibility.keep_visible_when_active))
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

        public void apply_filter (LaunchOptionView view, string query,
                                  LaunchOptionCapabilityResolver? resolver = null,
                                  LaunchCommandCapabilityContext? context = null) {
            var searching = query.strip () != "";
            foreach (var presentation in get_ordered ()) {
                var active = presentation.is_active ();
                var visible = catalog.should_display (presentation.metadata, view, query, active);
                if (resolver != null) {
                    var eligibility = resolver.evaluate (presentation.metadata, context, active);
                    presentation.eligibility = eligibility;
                    var eligible_for_view = active ? eligibility.keep_visible_when_active
                        : eligibility.show_when_inactive;
                    visible = eligible_for_view && visible;
                } else {
                    presentation.eligibility = null;
                }
                presentation.currently_visible = visible;

                foreach (var widget in presentation.widgets)
                    widget.visible = visible;
                presentation.apply_metadata (searching);
            }
        }

    }
}
