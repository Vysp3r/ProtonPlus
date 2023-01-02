using Gtk;
using Models;

namespace Stores {
    public class Main {
        public Gtk.Application Application;
        public ApplicationWindow MainWindow;

        public Launcher CurrentLauncher;
        public List<Launcher> InstalledLaunchers;

        public Models.Preference Preference;

        public double ProgressBarValue;
        public bool IsInstallationCancelled;
        public bool IsDownloadCompleted;
        public bool IsExtractionCompleted;

        public List<Release> Releases;
        public bool ReleaseRequestIsDone;

        public bool close;

        static Once<Main> _instance;

        public static unowned Main get_instance () {
            return _instance.once (() => { return new Main (); });
        }
    }
}
