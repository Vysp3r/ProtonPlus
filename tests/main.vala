using GLib;
using Gee;

int main (string[] args) {

    AppTests.BaseTest.saved_commands = new Gee.ArrayList<AppTests.TestCommand> ();
    Test.init (ref args);

    AppTests.register_test_suite<AppTests.ExampleTest> ();


    return Test.run ();
}