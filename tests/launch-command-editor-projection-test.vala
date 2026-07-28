namespace AppTests.LaunchCommandEditorProjectionTest {
    using GLib;
    using Gee;
    using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

    public void register_tests () {
        Test.add_func ("/launch-command-editor-projection/states", test_states);
        Test.add_func ("/launch-command-editor-projection/candidates", test_candidates);
        Test.add_func ("/launch-command-editor-projection/coverage", test_coverage);
        Test.add_func ("/launch-command-editor-projection/preservation", test_preservation);
    }

    private ArrayList<ILaunchCommandSelectionSource> sources (LaunchCommandSelection[] selections) {
        var result = new ArrayList<ILaunchCommandSelectionSource> ();
        foreach (var selection in selections)
            result.add (new LaunchCommandStaticSelectionSource (selection.option_id, selection));
        return result;
    }

    private LaunchCommandCapabilityContext capabilities (LaunchOptionCapability[] values) {
        return new LaunchCommandCapabilityContext (values);
    }

    private void test_states () {
        var projection = new LaunchCommandEditorProjection ();
        projection.update ("", sources ({}));
        assert (projection.state == LaunchCommandEditorProjectionState.PRISTINE_SOURCE);

        projection.update ("", sources ({ new LaunchCommandSelection ("proton-debug-log") }));
        assert (projection.state == LaunchCommandEditorProjectionState.CAPABILITY_CONTEXT_REQUIRED);

        projection.update ("", sources ({ new LaunchCommandSelection ("proton-debug-log") }),
            new ArrayList<string> (), capabilities ({ LaunchOptionCapability.PROTON }));
        assert (projection.state == LaunchCommandEditorProjectionState.MANAGED_CANDIDATE_READY);
        assert (projection.managed_candidate == "PROTON_LOG=1 %command%");

        projection.update ("PROTON_LOG=1 %command%", sources ({ new LaunchCommandSelection ("proton-debug-log") }),
            new ArrayList<string> (), capabilities ({ LaunchOptionCapability.PROTON }));
        assert (projection.state == LaunchCommandEditorProjectionState.PRISTINE_SOURCE);

        projection.update ("PROTON_USE_NTSYNC=0 %command%", sources ({}));
        assert (projection.state == LaunchCommandEditorProjectionState.UNMANAGED_SOURCE_PRESERVED);

        projection.update ("$(opaque) %command%", sources ({}));
        assert (projection.state == LaunchCommandEditorProjectionState.UNMANAGED_SOURCE_PRESERVED);

        projection.update ("UNKNOWN_VALUE=one %command%", sources ({}));
        assert (projection.state == LaunchCommandEditorProjectionState.UNMANAGED_SOURCE_PRESERVED);

        projection.update ("%command% %command%", sources ({}));
        assert (projection.state == LaunchCommandEditorProjectionState.UNMANAGED_SOURCE_PRESERVED);

        projection.update ("", sources ({
            new LaunchCommandSelection ("renderer-dx11"),
            new LaunchCommandSelection ("renderer-dx12")
        }));
        assert (projection.state == LaunchCommandEditorProjectionState.INVALID_SEMANTIC_SELECTIONS);
    }

    private void test_candidates () {
        var projection = new LaunchCommandEditorProjection ();
        projection.update ("", sources ({ new LaunchCommandSelection ("ntsync-mode") }),
            new ArrayList<string> (), capabilities ({ LaunchOptionCapability.PROTON }));
        assert (projection.managed_candidate == "PROTON_NO_NTSYNC=1 %command%");

        projection.update ("", sources ({ new LaunchCommandSelection ("dll-overrides", { "d3d11=n;dxgi=n,b" }) }),
            new ArrayList<string> (), capabilities ({ LaunchOptionCapability.PROTON }));
        assert (projection.managed_candidate == "WINEDLLOVERRIDES='d3d11=n;dxgi=n,b' %command%");

        projection.update ("", sources ({
            new LaunchCommandSelection ("performance-overlay"),
            new LaunchCommandSelection ("launch-backend", {}, "gamescope"),
            new LaunchCommandSelection ("gamescope-fullscreen"),
            new LaunchCommandSelection ("gamescope-frame-limit", { "60" }),
            new LaunchCommandSelection ("skip-launcher")
        }), new ArrayList<string> (), capabilities ({ LaunchOptionCapability.MANGOHUD, LaunchOptionCapability.GAMESCOPE }));
        assert (projection.managed_candidate == "mangohud gamescope -f -r 60 -- %command% -skip-launcher");

        projection.update ("", sources ({
            new LaunchCommandSelection ("launch-backend", {}, "scopebuddy"),
            new LaunchCommandSelection ("scopebuddy-resolution", { "auto" })
        }), new ArrayList<string> (), capabilities ({ LaunchOptionCapability.SCOPEBUDDY }));
        assert (projection.managed_candidate == "SCB_AUTO_RES=1 scopebuddy -- %command%");

        projection.update ("", sources ({
            new LaunchCommandSelection ("launch-backend", {}, "scopebuddy"),
            new LaunchCommandSelection ("scopebuddy-resolution", { "1920", "1080" })
        }), new ArrayList<string> (), capabilities ({ LaunchOptionCapability.SCOPEBUDDY }));
        assert (projection.managed_candidate == "scopebuddy -W 1920 -H 1080 -- %command%");
    }

    private void test_coverage () {
        var catalog = new LaunchOptionCatalog ();
        var presentations = new LaunchOptionPresentationRegistry (catalog);
        presentations.register ("proton-debug-log", null, null);
        assert (contains (presentations.validate_selection_sources (), "has no selection source"));

        presentations.register_selection_source ("proton-debug-log",
            new LaunchCommandStaticSelectionSource ("proton-debug-log"));
        presentations.register_selection_source ("proton-debug-log",
            new LaunchCommandStaticSelectionSource ("proton-debug-log"));
        assert (contains (presentations.validate_selection_sources (), "duplicate selection ownership"));

        var unknown = new LaunchOptionPresentationRegistry (catalog);
        unknown.register_selection_source ("unknown", new LaunchCommandStaticSelectionSource ("unknown"));
        assert (contains (unknown.validate_selection_sources (), "unknown option"));

        var projection = new LaunchCommandEditorProjection ();
        var source = new LaunchCommandStaticSelectionSource (
            "proton-debug-log", new LaunchCommandSelection ("dll-overrides", { "d3d11=n" })
        );
        var values = new ArrayList<ILaunchCommandSelectionSource> ();
        values.add (source);
        projection.update ("", values);
        assert (projection.state == LaunchCommandEditorProjectionState.INCOMPLETE_ADAPTER_COVERAGE);
    }

    private void test_preservation () {
        var source = "  WINEDLLOVERRIDES=\"d3d11=n;dxgi=n,b\"  %command%  ";
        var projection = new LaunchCommandEditorProjection ();
        projection.update (source, sources ({ new LaunchCommandSelection ("dll-overrides", { "d3d11=n;dxgi=n,b" }) }),
            new ArrayList<string> (), capabilities ({ LaunchOptionCapability.PROTON }));
        assert (projection.parsed.original_input == source);
        assert (projection.managed_candidate == "WINEDLLOVERRIDES='d3d11=n;dxgi=n,b' %command%");
        assert (projection.state == LaunchCommandEditorProjectionState.MANAGED_CANDIDATE_READY);
    }

    private bool contains (Gee.List<string> values, string needle) {
        foreach (var value in values) if (value.contains (needle)) return true;
        return false;
    }
}
