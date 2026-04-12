namespace ProtonPlus.Models.Releases {
    public abstract class Upgrade<R> : Release<R> {
        public async bool upgrade () {
            if (DownloadManager.instance.is_downloading ((Release<Parameters>) this))
                return false;

            canceled = false;

            state = State.BUSY_UPGRADING;

            DownloadManager.instance.add_download ((Release<Parameters>) this);

            var upgrade_success = yield _start_upgrade ();

            DownloadManager.instance.remove_download ((Release<Parameters>) this);

            refresh_state ();

            return upgrade_success;
        }

        protected abstract async bool _start_upgrade ();
    }
}