namespace ProtonPlus.Widgets.Dialogs {
    public class UpgradeDialog : BusyDialog {
        public UpgradeDialog (Models.Release release) {
            initialize (release);

            window_title.set_title (_("Upgrading"));
        }
    }
}