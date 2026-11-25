namespace ProtonPlus.Widgets.Tools {
    internal class BuildDropdown : Object {
        public static Gtk.DropDown create () {
            var expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");
            var dropdown = new Gtk.DropDown (null, expression) {
                valign = Gtk.Align.CENTER
            };
            dropdown.update_property (Gtk.AccessibleProperty.LABEL, _("Build"), -1);

            var selected_factory = new Gtk.SignalListItemFactory ();
            selected_factory.setup.connect ((object) => {
                ((Gtk.ListItem) object).child = new Gtk.Label (null) {
                    ellipsize = Pango.EllipsizeMode.END,
                    max_width_chars = 16,
                    xalign = 0
                };
            });
            selected_factory.bind.connect ((object) => {
                var item = (Gtk.ListItem) object;
                ((Gtk.Label) item.child).label = ((Gtk.StringObject) item.item).string;
            });
            dropdown.factory = selected_factory;

            var dropdown_ref = WeakRef (dropdown);
            var list_factory = new Gtk.SignalListItemFactory ();
            list_factory.setup.connect ((object) => {
                var item = (Gtk.ListItem) object;
                var title = new Gtk.Label (null) { xalign = 0 };
                var description = new Gtk.Label (null) {
                    xalign = 0,
                    wrap = true,
                    wrap_mode = Pango.WrapMode.WORD_CHAR,
                    max_width_chars = 36,
                    css_classes = { "dim-label" }
                };
                var labels = new Gtk.Box (Gtk.Orientation.VERTICAL, 3) { hexpand = true };
                labels.append (title);
                labels.append (description);
                var checkmark = new Gtk.Image.from_icon_name ("object-select-symbolic") {
                    valign = Gtk.Align.START
                };
                var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
                    margin_top = 6,
                    margin_bottom = 6,
                    margin_start = 12,
                    margin_end = 12
                };
                row.append (labels);
                row.append (checkmark);
                item.set_data ("build-title", title);
                item.set_data ("build-description", description);
                item.set_data ("build-checkmark", checkmark);
                item.child = row;
            });
            list_factory.bind.connect ((object) => {
                var item = (Gtk.ListItem) object;
                var variant = (Gtk.StringObject) item.item;
                var name = variant.string;
                item.get_data<Gtk.Label> ("build-title").label = name;
                item.get_data<Gtk.Label> ("build-description").label = describe_build (name);
                var current = dropdown_ref.get () as Gtk.DropDown;
                if (current != null) {
                    var checkmark = item.get_data<Gtk.Image> ("build-checkmark");
                    var binding = current.bind_property ("selected-item", checkmark, "visible", BindingFlags.SYNC_CREATE,
                        (binding, source, ref target) => {
                            target.set_boolean (source.get_object () == variant);
                            return true;
                        });
                    item.set_data ("build-checkmark-binding", binding);
                }
            });
            list_factory.unbind.connect ((object) => {
                var item = (Gtk.ListItem) object;
                item.get_data<Binding> ("build-checkmark-binding")?.unbind ();
                item.set_data<Binding?> ("build-checkmark-binding", null);
            });
            dropdown.list_factory = list_factory;
            return dropdown;
        }

        static string describe_build (string name) {
            if (name == _("Async"))
                return _("Build with asynchronous shader compilation.");
            if (name == _("Standard"))
                return _("Standard build for this release.");
            switch (name) {
            case "x86_64":
                return _("Standard 64-bit build for most Intel and AMD PCs.");
            case "x86_64_v3":
                return _("Optimized 64-bit build for Intel and AMD CPUs that support the x86-64-v3 instruction set.");
            case "arm64":
            case "aarch64":
                return _("64-bit ARM build. Choose this only on ARM64 hardware.");
            case "x86":
                return _("32-bit x86 build. Choose this only when a 32-bit runner is required.");
            case "wow64":
            case "x86_64_wow64":
                return _("64-bit build with WoW64 support for running 32-bit Windows applications.");
            default:
                if (name == "default" || name == _("Default"))
                    return _("The provider's recommended build for most systems.");
                return _("An alternate build provided for this release.");
            }
        }
    }
}
