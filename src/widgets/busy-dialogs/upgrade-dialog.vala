namespace ProtonPlus.Widgets.Dialogs {
    public class UpgradeDialog : BusyDialog {
        public override void initialize (Models.Release release) {
            base.initialize (release);

            window_title.set_title (_("Upgrade"));
        }
    }
}