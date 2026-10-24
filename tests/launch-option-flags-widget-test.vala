using ProtonPlus.Widgets.Games.LaunchOptionsEditor;

void check_rows (Gtk.Widget widget, ref int count) {
    if (widget is Adw.ComboRow) {
        var row = (Adw.ComboRow) widget;
        assert (row.subtitle != null && row.subtitle != "");
        assert (row.tooltip_text == row.subtitle);
        count++;
    }
    assert (!(widget is Adw.EntryRow));
    for (var child = widget.get_first_child (); child != null; child = child.get_next_sibling ())
        check_rows (child, ref count);
}

int main (string[] args) {
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    if (!Gtk.init_check ())
        return 77;
    Adw.init ();
    string[] ids = { "vkd3d-config", "amd-radv-perftest", "amd-radv-debug", "amd-aco-debug" };
    LaunchOptionCustomPairs[] editors = {
        new LaunchOptionVKD3DConfig (), new LaunchOptionRadvPerftest (),
        new LaunchOptionRadvDebug (), new LaunchOptionAcoDebug ()
    };
    for (int i = 0; i < ids.length; i++) {
        var editor = editors[i];
        var values = LaunchOptionFlags.values (ids[i]);
        var source = LaunchCommandSelectionAdapterFactory.create (ids[i], editor, editor);
        assert (source != null);
        editor.enable_expansion = true;
        assert (source.get_selection () == null);
        int count = 0;
        check_rows (editor, ref count);
        assert (count == values.length);
        foreach (var key in values) {
            editor.value = key;
            assert (editor.value == key);
            var selection = source.get_selection ();
            assert (selection != null);
            var result = new LaunchCommandComposer ().compose (new LaunchCommandCompositionRequest (
                { selection }, new LaunchCommandCapabilityContext ({
                    LaunchOptionCapability.AMD, LaunchOptionCapability.VKD3D_PROTON
                })
            ));
            assert (result.is_valid);
        }
        editor.value = string.joinv (",", values);
        assert (editor.value == string.joinv (",", values));
        editor.value = "legacy_flag";
        assert (editor.value == "legacy_flag");
        editor.value = values[0];
        assert (editor.value == values[0]);
        editor.clear ();
        assert (editor.value == "");
        assert (!editor.is_active ());
        count = 0;
        check_rows (editor, ref count);
        assert (count == values.length);
    }
    var dlls = new LaunchOptionDllOverrides ();
    dlls.value = "custom_mod=n;dxgi=n,b";
    assert (dlls.value.contains ("custom_mod=n"));
    dlls.value = "d3d11=b";
    assert (dlls.value == "d3d11=b");
    return 0;
}
