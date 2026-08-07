namespace ProtonPlus.Models.Tools {
    // Couples the provider outcome to its page so callers cannot mistake an
    // empty, valid page for a failed request.
    public class ReleasePageResult : Object {
        public ReturnCode code { get; construct; }
        public ReleasePage? page { get; construct; }

        public bool succeeded {
            get { return code == ReturnCode.RELEASES_LOADED; }
        }

        private ReleasePageResult (ReturnCode code, ReleasePage? page) {
            Object (code: code, page: page);
        }

        public static ReleasePageResult success (ReleasePage page) {
            return new ReleasePageResult (ReturnCode.RELEASES_LOADED, page);
        }

        public static ReleasePageResult failure (ReturnCode code) {
            assert (code != ReturnCode.RELEASES_LOADED);
            return new ReleasePageResult (code, null);
        }

        public ReleasePage require_page () {
            assert (succeeded && page != null);
            return (!) page;
        }
    }
}
