namespace ProtonPlus.Widgets {
    public class SortByToolButton : Gtk.Button {
        Gtk.ListBox game_list_box { get; set; }
        Adw.ButtonContent sort_by_tool_button_content { get; set; }

        construct {
            sort_by_tool_button_content = new Adw.ButtonContent();
            sort_by_tool_button_content.set_label (_("Sort by compatibility tool"));
            sort_by_tool_button_content.set_icon_name("sort-symbolic");

            set_hexpand (true);
            set_tooltip_text (_("Sorts the games by the compatibility tool name"));
            add_css_class("flat");
            set_child(sort_by_tool_button_content);

            clicked.connect(sort_by_tool_button_clicked);
        }

        public SortByToolButton (Gtk.ListBox game_list_box) {
            this.game_list_box = game_list_box;
        }

        void sort_by_tool_button_clicked () {
            game_list_box.set_sort_func((row1, row2) => {
                var name1 = ((GameRow)row1).game.compatibility_tool;
                var name2 = ((GameRow)row2).game.compatibility_tool;

                if (name1 == _("Undefined"))
                    name1 = "zzzz";
                    
                if (name2 == _("Undefined"))
                    name2 = "zzzz";
                
                return strcmp(name1, name2);
            });
        }
    }
}