namespace ProtonPlus.Stores {
    public class Threads {
        private static GLib.Once<Threads> _instance;

        public static unowned Threads instance () {
            return _instance.once (() => { return new Threads (); });
        }

        public double ProgressBar;
        public bool ProgressBarDone;
    }
}
