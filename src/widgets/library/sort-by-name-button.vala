namespace ProtonPlus.Widgets {
    public class SortByNameButton : Gtk.Button {
        Gtk.ListBox game_list_box { get; set; }
        Adw.ButtonContent sort_by_name_button_content { get; set; }

        construct {
            sort_by_name_button_content = new Adw.ButtonContent();
            sort_by_name_button_content.set_label (_("Sort by name"));
            sort_by_name_button_content.set_icon_name("sort-symbolic");

            set_hexpand (true);
            set_tooltip_text (_("Sorts the games by their name"));
            add_css_class("flat");
            set_child(sort_by_name_button_content);

            clicked.connect(sort_by_name_button_clicked);
        }

        public SortByNameButton (Gtk.ListBox game_list_box) {
            this.game_list_box = game_list_box;
        }

        void sort_by_name_button_clicked () {
            game_list_box.set_sort_func((row1, row2) => {
                var name1 = ((GameRow)row1).game.name;
                var name2 = ((GameRow)row2).game.name;
                
                return strcmp(name1, name2);
            });
        }
    }
}