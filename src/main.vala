namespace ProtonPlus {
    public static int main (string[] args) {
        if (!Thread.supported ()) {
            message ("Threads are not supported!");
            return -1;
        }

        var application = new Widgets.Application ();

        return application.run (args);
    }
}