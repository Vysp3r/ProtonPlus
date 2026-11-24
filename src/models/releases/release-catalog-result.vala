namespace ProtonPlus.Models {
    // Catalog operations always return a collection.  On failure it is the
    // retained catalog state, which lets presentation code keep it visible.
    public class ReleaseCatalogResult : Object {
        public ReturnCode code { get; construct; }
        public Gee.LinkedList<Release> releases { get; construct; }

        public bool succeeded {
            get { return code == ReturnCode.RELEASES_LOADED; }
        }

        private ReleaseCatalogResult (ReturnCode code, Gee.LinkedList<Release> releases) {
            Object (code: code, releases: releases);
        }

        public static ReleaseCatalogResult success (Gee.LinkedList<Release> releases) {
            return new ReleaseCatalogResult (ReturnCode.RELEASES_LOADED, releases);
        }

        public static ReleaseCatalogResult failure (ReturnCode code, Gee.LinkedList<Release> releases) {
            assert (code != ReturnCode.RELEASES_LOADED);
            return new ReleaseCatalogResult (code, releases);
        }
    }

    // Latest discovery has a distinct successful empty state: no eligible
    // release is not a malformed response or a transport failure.
    public class ReleaseLookupResult : Object {
        public ReturnCode code { get; construct; }
        public Release? release { get; construct; }

        public bool succeeded {
            get { return code == ReturnCode.RELEASES_LOADED; }
        }

        public bool has_release {
            get { return release != null; }
        }

        private ReleaseLookupResult (ReturnCode code, Release? release) {
            Object (code: code, release: release);
        }

        public static ReleaseLookupResult found (Release release) {
            return new ReleaseLookupResult (ReturnCode.RELEASES_LOADED, release);
        }

        public static ReleaseLookupResult empty () {
            return new ReleaseLookupResult (ReturnCode.RELEASES_LOADED, null);
        }

        public static ReleaseLookupResult failure (ReturnCode code) {
            assert (code != ReturnCode.RELEASES_LOADED);
            return new ReleaseLookupResult (code, null);
        }

        public Release require_release () {
            assert (succeeded && release != null);
            return (!) release;
        }
    }
}
