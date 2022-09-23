int main (string[] args) {
    if (Thread.supported () == false) {
        stderr.printf ("Threads are not supported!\n");
        return -1;
    }

    var app = new ProtonPlus.Application ();
    return app.run (args);
}