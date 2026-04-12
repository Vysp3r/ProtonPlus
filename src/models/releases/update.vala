namespace ProtonPlus.Models.Releases {
    public abstract class Update<R>: Release<R> {
        public async bool update () {
            if (DownloadManager.instance.is_downloading (this))
                return false;

            canceled = false;

            state = State.BUSY_UPDATING;

            DownloadManager.instance.add_download (this);

            var update_success = yield _start_update ();

            DownloadManager.instance.remove_download (this);

            refresh_state ();

            return update_success;
        }

        protected abstract async bool _start_update ();
    }
}