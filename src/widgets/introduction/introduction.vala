namespace ProtonPlus.Widgets.Introduction {
    using Adw;
    using Gtk;

    class Introduction : Adw.Dialog {
        Adw.HeaderBar header_bar { get; set; }
        Adw.WindowTitle window_title { get; set; }
        Gtk.Box content_box { get; set; }
        Adw.ToolbarView toolbar_view { get; set; }

        Adw.Carousel car;
        private Gtk.Button prev_button;
        private Gtk.Button next_button;
        private Gee.ArrayList<Gtk.Widget> pages;

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

            var carousel_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            carousel_row.set_hexpand (true);
            carousel_row.set_vexpand (true);

            car = new Adw.Carousel ();
            car.set_hexpand (true);
            car.set_vexpand (true);

            pages = new Gee.ArrayList<Gtk.Widget> ();
            pages.add (new Application ());
            pages.add (new Wine ());
            pages.add (new Proton ());
            pages.add (new Forks ());
            pages.add (new HowToUse ());

            foreach (var page in pages) {
                car.append (page);
            }

            prev_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
            prev_button.add_css_class ("circular");
            prev_button.valign = Gtk.Align.CENTER;
            prev_button.clicked.connect (on_prev_clicked);

            next_button = new Gtk.Button.from_icon_name ("go-next-symbolic");
            next_button.add_css_class ("circular");
            next_button.valign = Gtk.Align.CENTER;
            next_button.clicked.connect (on_next_clicked);

            carousel_row.append (prev_button);
            carousel_row.append (car);
            carousel_row.append (next_button);
            content_box.append (carousel_row);

            var dots = new Adw.CarouselIndicatorDots ();
            dots.set_carousel (car);
            dots.set_halign (Gtk.Align.CENTER);
            content_box.append (dots);

            car.notify["position"].connect (update_buttons_visibility);

            update_buttons_visibility ();

            toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (content_box);

            set_content_width (600);
            set_content_height (400);
            set_can_close (true);
            set_child (toolbar_view);
        }

        private void on_prev_clicked () {
            uint current_page = (uint) Math.round (car.position);
            if (current_page > 0) {
                car.scroll_to (pages.get ((int) current_page - 1), true);
            }
        }

        private void on_next_clicked () {
            uint current_page = (uint) Math.round (car.position);
            if (current_page < pages.size - 1) {
                car.scroll_to (pages.get ((int) current_page + 1), true);
            }
        }

        private void update_buttons_visibility () {
            uint current_page = (uint) Math.round (car.position);

            prev_button.sensitive = (current_page > 0);
            next_button.sensitive = (current_page < pages.size - 1);
        }
    }
}