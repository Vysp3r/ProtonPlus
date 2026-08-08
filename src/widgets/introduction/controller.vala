namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Controller : Base {
        public Controller () {
            base (
                _("Controller support"),
                _("ProtonPlus automatically adapts to controller input and shows contextual hints using your controller's button labels. Navigate pages, dialogs, and menus with the D-pad or sticks; use the face buttons for actions such as Confirm, Back, Search, and Filter; and switch sections with the shoulder buttons. You can choose the Confirm button and enable vibration in Preferences. On Steam Deck, focus a text field and press Steam + X to open the on-screen keyboard. Other systems may require a physical or system keyboard."), // vala-lint=line-length
                "gamepad-symbolic"
            );
        }
    }
}
