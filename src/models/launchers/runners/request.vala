namespace ProtonPlus.Models.Launchers.Runners {
    public class Request : Object {
        public async static void request (IRunner runner) {
            code = yield Utils.Web.get_request ("%s?per_page=25&page=%i".printf (runner.endpoint, page), get_request_type, out response);
        }
    }
}
