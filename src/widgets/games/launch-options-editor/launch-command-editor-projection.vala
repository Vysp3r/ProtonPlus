namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    using Gee;

    public enum LaunchCommandEditorProjectionState {
        PRISTINE_SOURCE,
        MANAGED_CANDIDATE_READY,
        UNMANAGED_SOURCE_PRESERVED,
        INVALID_SEMANTIC_SELECTIONS,
        INCOMPLETE_ADAPTER_COVERAGE,
        CAPABILITY_CONTEXT_REQUIRED
    }

    /* Shadow-only parser/composer orchestration.  It has no persistence side
     * effects and callers remain responsible for retaining the original text. */
    public class LaunchCommandEditorProjection : Object {
        LaunchOptionCatalog catalog;
        LaunchCommandParser parser;
        LaunchCommandComposer composer;
        public LaunchCommandParseResult parsed { get; private set; }
        public ArrayList<LaunchCommandSelection> active_selections { get; private set; }
        public ArrayList<string> unmanaged_option_ids { get; private set; }
        public ArrayList<string> adapter_diagnostics { get; private set; }
        public ArrayList<LaunchCommandCompositionDiagnostic> composition_diagnostics { get; private set; }
        public LaunchCommandEditorProjectionState state { get; private set; }
        public string managed_candidate { get; private set; default = ""; }
        public bool retain_placeholder_for_arguments_only { get; private set; default = false; }
        public bool has_managed_candidate {
            get {
                return state == LaunchCommandEditorProjectionState.PRISTINE_SOURCE
                    || state == LaunchCommandEditorProjectionState.MANAGED_CANDIDATE_READY;
            }
        }

        public LaunchCommandEditorProjection (LaunchOptionCatalog? catalog = null,
                                               LaunchCommandParser? parser = null,
                                               LaunchCommandComposer? composer = null) {
            this.catalog = catalog ?? new LaunchOptionCatalog ();
            this.parser = parser ?? new LaunchCommandParser (this.catalog);
            this.composer = composer ?? new LaunchCommandComposer (this.catalog);
            parsed = this.parser.parse ("");
            active_selections = new ArrayList<LaunchCommandSelection> ();
            unmanaged_option_ids = new ArrayList<string> ();
            adapter_diagnostics = new ArrayList<string> ();
            composition_diagnostics = new ArrayList<LaunchCommandCompositionDiagnostic> ();
            state = LaunchCommandEditorProjectionState.PRISTINE_SOURCE;
        }

        public void update (string source, Collection<ILaunchCommandSelectionSource> sources,
                            Collection<string> coverage_diagnostics = new ArrayList<string> (),
                            LaunchCommandCapabilityContext? capabilities = null) {
            parsed = parser.parse (source);
            active_selections.clear ();
            unmanaged_option_ids.clear ();
            adapter_diagnostics.clear ();
            composition_diagnostics.clear ();
            managed_candidate = "";
            retain_placeholder_for_arguments_only = parsed.command_boundary_indexes.size == 1
                && parsed.command_boundary_indexes[0] == 0;

            foreach (var diagnostic in coverage_diagnostics) adapter_diagnostics.add (diagnostic);
            foreach (var source_item in sources) {
                var selection = source_item.get_selection ();
                var diagnostic = source_item.get_diagnostic ();
                if (diagnostic != null) adapter_diagnostics.add (diagnostic);
                if (selection == null) continue;
                if (selection.option_id != source_item.option_id)
                    adapter_diagnostics.add ("Selection source '%s' returned '%s'.".printf (
                        source_item.option_id, selection.option_id));
                active_selections.add (selection);
            }
            foreach (var occurrence in parsed.occurrences) {
                if (!occurrence.managed_emission || occurrence.is_legacy)
                    unmanaged_option_ids.add (occurrence.option_id);
            }

            if (adapter_diagnostics.size > 0) {
                state = LaunchCommandEditorProjectionState.INCOMPLETE_ADAPTER_COVERAGE;
                return;
            }
            if (!parsed.is_structurally_safe || unmanaged_option_ids.size > 0) {
                state = LaunchCommandEditorProjectionState.UNMANAGED_SOURCE_PRESERVED;
                return;
            }
            if (capabilities == null && requires_capability_context ()) {
                state = LaunchCommandEditorProjectionState.CAPABILITY_CONTEXT_REQUIRED;
                return;
            }
            var result = composer.compose (new LaunchCommandCompositionRequest (
                active_selections.to_array (), capabilities ?? new LaunchCommandCapabilityContext (),
                retain_placeholder_for_arguments_only
            ));
            foreach (var diagnostic in result.diagnostics) composition_diagnostics.add (diagnostic);
            if (!result.is_valid) {
                state = LaunchCommandEditorProjectionState.INVALID_SEMANTIC_SELECTIONS;
                return;
            }
            managed_candidate = result.launch_line;
            state = source == managed_candidate
                ? LaunchCommandEditorProjectionState.PRISTINE_SOURCE
                : LaunchCommandEditorProjectionState.MANAGED_CANDIDATE_READY;
        }

        bool requires_capability_context () {
            foreach (var selection in active_selections) {
                var metadata = catalog.lookup (selection.option_id);
                if (metadata == null || metadata.semantics == null) continue;
                if (metadata.semantics.get_required_capabilities ().length > 0) return true;
                if (metadata.semantics.kind == LaunchOptionSemanticKind.WRAPPER_SELECTOR
                    && selection.wrapper_id != "") return true;
            }
            return false;
        }
    }
}
