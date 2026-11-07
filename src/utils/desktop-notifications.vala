namespace ProtonPlus.Utils {
    public delegate void DesktopNotificationDispatch (string title, string body, Icon icon) throws Error;

    public static void send_desktop_notification (string title, string body, Icon icon) throws Error {
        var application = GLib.Application.get_default ();
        if (application == null || !application.is_registered)
            throw new IOError.NOT_INITIALIZED ("The application is not registered for desktop notifications.");

        var notification = new GLib.Notification (title);
        notification.set_body (body);
        notification.set_icon (icon);
        application.send_notification (null, notification);
    }
}
