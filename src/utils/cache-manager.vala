namespace ProtonPlus.Utils {
    public class CacheManager {
        // Install attempts keep both their temporary workspace and their
        // downloaded archives below CACHE_PATH.  Clearing the cache must not
        // remove either while an attempt is still using it.
        private static uint active_cache_operations = 0;
        private static bool clearing_cache = false;

        private static async void wait_for_cache_state_change () {
            Timeout.add (10, () => {
                wait_for_cache_state_change.callback ();
                return Source.REMOVE;
            });
            yield;
        }

        public static async void begin_cache_operation () {
            // A continuation runs on the main context, so incrementing after
            // the wait closes the race with clear_cache().
            while (clearing_cache)
                yield wait_for_cache_state_change ();

            active_cache_operations++;
        }

        public static void end_cache_operation () {
            assert (active_cache_operations > 0);
            active_cache_operations--;
        }

        public static async bool clear_cache () {
            // Serialize clear requests as well as install attempts.  Existing
            // operations are allowed to finish (or be cancelled) so their
            // cleanup never races deletion of CACHE_PATH.
            while (clearing_cache)
                yield wait_for_cache_state_change ();

            clearing_cache = true;
            while (active_cache_operations > 0)
                yield wait_for_cache_state_change ();

            int cache_lock = -1;
            try {
                while (cache_lock < 0) {
                    cache_lock = PartialDownloadCache.lock_cache (Globals.CACHE_PATH, true);
                    if (cache_lock < 0)
                        yield wait_for_cache_state_change ();
                }
            } catch (Error e) {
                clearing_cache = false;
                return false;
            }
            bool success = true;
            if (FileUtils.test (Globals.CACHE_PATH, FileTest.IS_DIR)) {
                if (!yield Utils.Filesystem.delete_directory (Globals.CACHE_PATH))
                    success = false;
            }

            if (success)
                success = Utils.Filesystem.create_directory (Globals.CACHE_PATH);

            Posix.close (cache_lock);
            clearing_cache = false;
            return success;
        }
    }
}
