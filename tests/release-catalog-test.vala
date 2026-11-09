namespace AppTests.ReleaseCatalogTest {
    using GLib;
    using ProtonPlus.Models;

    public void register_tests () {
        Test.add_func ("/release-catalog/cache-timestamp-fresh", test_cache_timestamp_fresh);
        Test.add_func ("/release-catalog/cache-timestamp-expired", test_cache_timestamp_expired);
        Test.add_func ("/release-catalog/cache-timestamp-invalid", test_cache_timestamp_invalid);
        Test.add_func ("/release-catalog/cache-timestamp-future", test_cache_timestamp_future);
    }

    private DateTime fixed_now () {
        var now = new DateTime.from_iso8601 ("2026-08-30T12:00:00Z", null);
        assert (now != null);
        return (!) now;
    }

    private void test_cache_timestamp_fresh () {
        var now = fixed_now ();
        var updated = now.add_minutes (-59);
        assert (ReleaseCatalog.cache_timestamp_is_fresh (updated.format_iso8601 (), now));
    }

    private void test_cache_timestamp_expired () {
        var now = fixed_now ();
        var updated = now.add_hours (-1);
        assert (!ReleaseCatalog.cache_timestamp_is_fresh (updated.format_iso8601 (), now));
    }

    private void test_cache_timestamp_invalid () {
        var now = fixed_now ();
        assert (!ReleaseCatalog.cache_timestamp_is_fresh ("", now));
        assert (!ReleaseCatalog.cache_timestamp_is_fresh ("not-a-timestamp", now));
    }

    private void test_cache_timestamp_future () {
        var now = fixed_now ();
        var updated = now.add_minutes (1);
        assert (!ReleaseCatalog.cache_timestamp_is_fresh (updated.format_iso8601 (), now));
    }
}
