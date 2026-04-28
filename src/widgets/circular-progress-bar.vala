namespace ProtonPlus.Widgets {
    public class CircularProgressBar : Gtk.DrawingArea {
        private int _line_width;
        private double _fraction;
        private double _pulse_offset = 0;
        private bool _is_pulsing = false;
        private string _center_fill_color;
        private string _radius_fill_color;
        private string _progress_fill_color;

        public bool center_filled { set; get; default = false; }
        public bool radius_filled { set; get; default = true; }
        public bool show_text { set; get; default = false; }
        public string font { set; get; default = "Sans"; }

        public Cairo.LineCap line_cap { set; get; default = Cairo.LineCap.ROUND; }

        public string center_fill_color {
            get {
                return _center_fill_color;
            }
            set {
                var color = Gdk.RGBA ();
                if (color.parse (value)) {
                    _center_fill_color = value;
                }
            }
        }

        public string radius_fill_color {
            get {
                return _radius_fill_color;
            }
            set {
                var color = Gdk.RGBA ();
                if (color.parse (value)) {
                    _radius_fill_color = value;
                }
            }
        }

        public string progress_fill_color {
            get {
                return _progress_fill_color;
            }
            set {
                var color = Gdk.RGBA ();
                if (color.parse (value)) {
                    _progress_fill_color = value;
                }
            }
        }

        public int line_width {
            get {
                return _line_width;
            }
            set {
                if (value < 0) {
                    _line_width = 0;
                } else {
                    _line_width = value;
                }
            }
        }

        public double fraction {
            get {
                return _fraction;
            }
            set {
                _is_pulsing = false;
                if (value > 1.0) {
                    _fraction = 1.0;
                } else if (value < 0.0) {
                    _fraction = 0.0;
                } else {
                    _fraction = value;
                }
            }
        }

        public void pulse () {
            _is_pulsing = true;
            _pulse_offset += 0.05;
            if (_pulse_offset > 2.0) {
                _pulse_offset -= 2.0;
            }
            queue_draw ();
        }

        construct {
            _line_width = 4;
            _fraction = 0;
            _center_fill_color = "rgba(0, 0, 0, 0)";
            _radius_fill_color = "rgba(0, 0, 0, 0.1)";
            _progress_fill_color = "#3584e4"; // GNOME Blue
        }

        public CircularProgressBar () {
            set_draw_func (draw);
            notify.connect (() => {
                queue_draw ();
            });
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public void draw (Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
            int w, h;
            int delta;
            Gdk.RGBA color;
            Pango.Layout layout;
            Pango.FontDescription desc;

            cr.save ();

            var center_x = width / 2;
            var center_y = height / 2;
            var radius = int.min (width / 2, height / 2) - 1;

            if (radius - line_width < 0) {
                delta = 0;
            //line_width = radius;
            } else {
                delta = radius - (line_width / 2);
            }

            cr.set_line_cap (line_cap);
            cr.set_line_width (line_width);

            // Center Fill
            if (center_filled) {
                cr.arc (center_x, center_y, delta, 0, 2 * Math.PI);
                color = Gdk.RGBA ();
                color.parse (center_fill_color);
                Gdk.cairo_set_source_rgba (cr, color);
                cr.fill ();
            }

            // Radius Fill (Background circle)
            if (radius_filled) {
                cr.arc (center_x, center_y, delta, 0, 2 * Math.PI);
                color = Gdk.RGBA ();
                color.parse (radius_fill_color);
                Gdk.cairo_set_source_rgba (cr, color);
                cr.stroke ();
            }

            // Progress/Percentage Fill
            if (_is_pulsing) {
                color = Gdk.RGBA ();
                color.parse (progress_fill_color);
                Gdk.cairo_set_source_rgba (cr, color);
                cr.arc (center_x,
                        center_y,
                        delta,
                        (1.5 + _pulse_offset) * Math.PI,
                        (1.5 + _pulse_offset + 0.5) * Math.PI);
                cr.stroke ();
            } else if (fraction > 0) {
                color = Gdk.RGBA ();
                color.parse (progress_fill_color);
                Gdk.cairo_set_source_rgba (cr, color);
                if (line_width == 0) {
                    cr.move_to (center_x, center_y);
                    cr.arc (center_x,
                            center_y,
                            delta + 1,
                            1.5 * Math.PI,
                            (1.5 + fraction * 2) * Math.PI);
                    cr.fill ();
                } else {
                    cr.arc (center_x,
                            center_y,
                            delta,
                            1.5 * Math.PI,
                            (1.5 + fraction * 2) * Math.PI);
                    cr.stroke ();
                }
            }

            // Textual information
            if (show_text) {
                var style_context = get_style_context ();
                style_context.save ();

                color = style_context.get_color ();
                Gdk.cairo_set_source_rgba (cr, color);

            // Percentage
                layout = Pango.cairo_create_layout (cr);
                layout.set_text ("%d".printf ((int) (fraction * 100.0)), -1);
                desc = Pango.FontDescription.from_string (font + " " + (radius * 0.7).to_string ());
                layout.set_font_description (desc);
                Pango.cairo_update_layout (cr, layout);
                layout.get_size (out w, out h);
                cr.move_to (center_x - ((w / Pango.SCALE) / 2), center_y - (h / Pango.SCALE) / 2);
                Pango.cairo_show_layout (cr, layout);

                style_context.restore ();
            }

            cr.restore ();
        }
    }
}
