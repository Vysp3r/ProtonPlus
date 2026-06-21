namespace ProtonPlus.Models.Internal.Requests.Github {
    using Gee;
    using ProtonPlus.Models.Internal.Requests;

    public class Releases : BaseReleases {

        public override void append_from_json (Json.Array root_array) {
            for (int i = 0; i < root_array.get_length (); i++) {
                Json.Object object = root_array.get_object_element (i);
                IRelease release = new Release ();
                release.from_json (object);
                this.list.add (release);
            }
        }
    }
}
