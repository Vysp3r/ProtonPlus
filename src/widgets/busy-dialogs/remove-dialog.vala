namespace ProtonPlus.Widgets.Dialogs {
    public class RemoveDialog : BusyDialog {
        public RemoveDialog (Models.Release release) {
            initialize (release);

            window_title.set_title (_("Removing"));
        }
    }
}