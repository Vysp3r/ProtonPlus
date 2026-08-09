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

            dxvk_hdr_tile = create_tile (
                _("DXVK HDR"),
                _("Advertises HDR10 to DXVK games. Requires an HDR-capable compositor, display, and driver."),
                { "DXVK_HDR=1" },
                false,
                LaunchLineType.ENVIRONMENT,
                "dxvk-hdr"
            );
            legacy_proton_hdr_tile = create_tile (
                _("Legacy custom-Proton HDR"),
                _("Uses PROTON_ENABLE_HDR only in selected custom Proton builds that still advertise it."),
                { "PROTON_ENABLE_HDR=1" },
                false,
                LaunchLineType.ENVIRONMENT,
                "proton-hdr"
            );
            dxvk_no_hdr_tile = create_tile (
                _("Disable custom-Proton automatic HDR"),
                _("Uses DXVK_NO_HDR=1 only in custom Proton builds that advertise the automatic-HDR opt-out."),
                { "DXVK_NO_HDR=1" },
                false,
                LaunchLineType.ENVIRONMENT,
                "dxvk-no-hdr"
            );
            nvidia_hdr_wsi_tile = create_tile (
                _("NVIDIA legacy HDR WSI"),
                _("Needed by NVIDIA proprietary drivers older than 595; do not enable on driver 595 or newer."),
                { "ENABLE_HDR_WSI=1" },
                false,
                LaunchLineType.ENVIRONMENT,
                "nvidia-hdr-wsi"
            );

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
