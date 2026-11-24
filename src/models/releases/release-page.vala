namespace ProtonPlus.Models.Tools {
    // A provider-neutral result for one normalized browse operation.  The
    // next page is explicit because some providers may consume more than one
    // upstream response while finding an eligible result.
    public class ReleasePage : Object {
        public Gee.LinkedList<Release> releases { get; construct; }
        public int next_page { get; construct; }
        public bool has_more { get; construct; }

        public ReleasePage (Gee.LinkedList<Release> releases, int next_page, bool has_more) {
            Object (
                releases: releases,
                next_page: next_page,
                has_more: has_more
            );
        }
    }
}
