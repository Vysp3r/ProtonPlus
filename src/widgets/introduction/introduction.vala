namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Introduction : Adw.Dialog {
        Adw.HeaderBar header_bar { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Gtk.Box content_box { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }

        public Introduction () {
            window_title = new Adw.WindowTitle (_("Introduction"), "");

            header_bar = new Adw.HeaderBar ();
            header_bar.set_title_widget (window_title);
            header_bar.set_show_end_title_buttons (true);

            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            content_box.set_margin_start (12);
            content_box.set_margin_end (12);
            content_box.set_margin_bottom (12);
            content_box.set_margin_top (12);

            var car = new Adw.Carousel ();
            car.set_hexpand (true);
            car.set_vexpand (true);

            var application = new Application ();
            var forks = new Forks ();
            var how_to_use = new HowToUse ();
            var proton = new Proton ();
            var wine = new Wine ();

            car.append (application);
            car.append (wine);
            car.append (proton);
            car.append (forks);
            car.append (how_to_use);

            content_box.append (car);

            var dots = new Adw.CarouselIndicatorDots ();
            dots.set_carousel (car);
            dots.set_halign (Gtk.Align.CENTER);
            content_box.append (dots);

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content_box);

            set_content_width (600);
            set_content_height (400);
            set_can_close (true);
            set_child (toolbar_view);
        }
    }
}