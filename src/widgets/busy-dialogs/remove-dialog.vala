namespace ProtonPlus.Widgets.Dialogs {
    public class RemoveDialog : BusyDialog {
        public override void initialize (Models.Release release) {
            base.initialize (release);

            window_title.set_title (_("Remove"));
        }
    }
}