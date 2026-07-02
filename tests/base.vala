using GLib;
using Gee;

namespace AppTests {

    public class TestCommand : GLib.Object {
        public delegate void TestMethod ();

        public TestMethod method;

        public TestCommand (owned TestMethod m) {
            this.method = (owned) m;
        }
    }

    [CCode (has_target = false)]
    public delegate void RawTestCallback ([CCode (type = "gconstpointer")] void* data);

    [CCode (cname = "g_test_add_data_func")]
    extern void g_test_add_data_func (string testpath, [CCode (type = "gconstpointer")] void* test_data, RawTestCallback test_func);


    public class BaseTest : GLib.Object {
        public static Gee.List<TestCommand> saved_commands;

        public void add_test (string name, owned TestCommand.TestMethod method) {
            string case_name = this.get_type ().name ();
            string path = @"/$(case_name)/$(name)";

            var command = new TestCommand ((owned) method);
            saved_commands.add (command);

            g_test_add_data_func (path, (void*) command, universal_static_runner);
        }

        private static void universal_static_runner (void* data) {
            unowned TestCommand command = (TestCommand) data;
            command.method ();
        }
    }

    public void register_test_suite<T> () {
        GLib.Type t = typeof (T);
        GLib.Object.new (t);
    }
}