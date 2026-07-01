namespace ProtonPlus.Models.Internal.Requests.GithubAction {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Releases : BaseReleases {

        public Releases (LinkedList<IRelease>? list = null) {
            base (list);
        }

        public Releases.from_json (Json.Array root_array) {
            base.from_json (root_array);
        }

        public override void append_from_json (Json.Array root_array) {
            for (int i = 0; i < root_array.get_length (); i++) {
                Json.Object object = root_array.get_object_element (i);
                IRelease release = new Release ();
                var parsed_release = release.from_json (object);
                if (parsed_release != null) {
                    this.list.add (parsed_release);
                }
            }
        }
    }
}
