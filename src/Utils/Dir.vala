namespace Utils {
    public enum Format{
        KB,
        GB
    }

    public class DirUtil : Object {
        private string _path;

        public DirUtil(string path){
            this._path = path;
        }

        private uint64 get_folder_size(string path_){
            uint64 size = 0;

            var dir = Posix.opendir(path_);
            if(dir == null){
                return 0;
            }

            unowned Posix.DirEnt? cur_d;
            Posix.Stat stat_;
            while((cur_d = Posix.readdir(dir)) != null){
                if(cur_d.d_name[0] == '.'){
                    continue;
                }

                Posix.stat(path_ + "/" + (string)cur_d.d_name, out stat_);

                if(Posix.S_ISDIR(stat_.st_mode)){
                    size += get_folder_size(path_ + "/" + (string)cur_d.d_name);
                } else {
                    size += stat_.st_size;
                }
            }

            return size;
        }

        public uint64 get_total_size(){
            return get_folder_size(this._path);
        }

        public double get_total_size_as(Format fmt){
            switch(fmt){
                default:
                case KB:
                    return (double)get_total_size() / 1024;
                case GB:
                    return (double)get_total_size() / (1024 * 1024 * 1024);
            }
        }

        public string get_total_size_as_string(){
            uint64 size = get_total_size();
            if(size >= 1073741824){
                return "%.2f GB".printf((double)size / (1024 * 1024 * 1024));
            } else if (size > 1048576){
                return "%.2f MB".printf((double)size / (1024 * 1024));
            } else {
                return "%lld B".printf(get_total_size());
            }
        }

        private bool remove_file_direct(string path){
            if(Posix.unlink(path) != 0)
                return false;
            return true;
        }

        public bool remove_file(string path){
            return remove_file_direct(this._path + "/" + path);
        }

        private bool remove_dir_direct(string path){
            var dir = Posix.opendir(path);
            if(dir == null){
                return false;
            }

            unowned Posix.DirEnt? cur_d;
            Posix.Stat stat_;
            while((cur_d = Posix.readdir(dir)) != null){
                if(cur_d.d_name[0] == '.' && ((cur_d.d_name[1] == '.' && cur_d.d_name[2] == '\0') || cur_d.d_name[1] == '\0')){
                    continue;
                }

                Posix.stat(path + "/" + (string)cur_d.d_name, out stat_);

                if(Posix.S_ISDIR(stat_.st_mode)){
                    if(remove_dir_direct(path + "/" + (string)cur_d.d_name) != true)
                        return false;
                    if(Posix.rmdir(path + "/" + (string)cur_d.d_name) != 0)
                        return false;
                } else {
                    if(remove_file_direct(path + "/" + (string)cur_d.d_name) != true)
                        return false;
                }
            }

            return true;
        }

        public bool remove_dir(string path){
            if(remove_dir_direct(this._path + "/" + path) == true){
                if(Posix.rmdir(this._path + "/" + path) == 0){
                    return true;
                }
            }
            return false;
        }
    }
}
