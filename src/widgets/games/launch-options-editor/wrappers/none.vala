namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor.Wrappers {
    using Adw;

    public class None : Base {
        LaunchOptionTile dxvk_hdr_tile { get; set; }
        LaunchOptionTile legacy_proton_hdr_tile { get; set; }
        LaunchOptionTile dxvk_no_hdr_tile { get; set; }
        LaunchOptionTile nvidia_hdr_wsi_tile { get; set; }

        public None (LaunchOptionsList launch_option_handlers, LaunchOptionPresentationRegistry? presentation_registry = null) {
            base (launch_option_handlers, presentation_registry);
        }

        public Gtk.Widget create_page () {
            var group = new Adw.PreferencesGroup ();

            dxvk_hdr_tile = create_tile ("dxvk-hdr");
            legacy_proton_hdr_tile = create_tile ("proton-hdr");
            dxvk_no_hdr_tile = create_tile ("dxvk-no-hdr");
            nvidia_hdr_wsi_tile = create_tile ("nvidia-hdr-wsi");

            group.add (dxvk_hdr_tile);
            group.add (legacy_proton_hdr_tile);
            group.add (dxvk_no_hdr_tile);
            group.add (nvidia_hdr_wsi_tile);

            return group;
        }

        public void selection_change () {
            foreach (var child in this._children)
                child.clear ();
        }

        public override void clear () {
            foreach (var child in this._children) {
                child.clear ();
            }
        }

        public override void parse_tokens (string[] tokens, bool[] consumed) {
            foreach (var child in this._children)
                child.parse_tokens (tokens, consumed);
        }

        public override void append_command_segments (Gee.LinkedList<string> segments) {
            foreach (var child in this._children) {
                if (child.is_active ())
                    child.append_command_segments (segments);
            }
        }
    }
}
