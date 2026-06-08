namespace AppTests {
    using GLib;

    public class ExampleTest : BaseTest {
        construct {
            add_test ("matematika", test_matematika);
            add_test ("text", test_text);
        }

        public void test_matematika () {
            assert (1 + 1 == 2);
        }

        public void test_text () {
            assert ("vala".length == 4);
        }
    }
}