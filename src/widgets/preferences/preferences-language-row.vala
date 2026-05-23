namespace ProtonPlus.Widgets.Preferences {
    public class LanguageRow : Adw.ComboRow {
        class Language : Object {
            public string name { get; private set; }
            public int index { get; private set; }
            public string code { get; private set; }

            public Language (string name, int index, string code) {
                this.name = name;
                this.index = index;
                this.code = code;
            }
        }

        bool is_initializing = true;

        construct {
            var model = new ListStore(typeof (Language));
            foreach (var lang in Globals.LANGUAGES()) {
                model.append (new Language(_ (lang.name), lang.index, lang.code));
            }

            var expression = new Gtk.PropertyExpression(typeof (Language), null, "name");

            set_title (_ ("Language"));
            set_model (model);
            set_expression (expression);

            if (Globals.SETTINGS != null) {
                int saved_enum_value = Globals.SETTINGS.get_enum ("language");
                
                for (uint i = 0; i < Globals.LANGUAGES().length; i++) {
                    if (Globals.LANGUAGES()[i].index == saved_enum_value) {
                        set_selected (i);
                        break;
                    }
                }
            }

            notify["selected-item"].connect (selected_item_changed);
            is_initializing = false;
        }

        void selected_item_changed () {
            var language = get_selected_item () as Language;
            if (language == null || is_initializing) return;

            if (Globals.SETTINGS != null) {
                Globals.SETTINGS.set_enum ("language", language.index);
            }

            Globals.setupLanguage ();

            activate_action ("app.on_language_change", null);

        }
    }
}