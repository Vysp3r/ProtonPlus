namespace ProtonPlus.Widgets.Games.LaunchOptionsEditor {
    public class Box : Gtk.Box {
        public signal void content_changed ();

        Groups.ProtonOptionsGroup proton_options_group { get; set; }
        Groups.AudioOptionsGroup audio_group { get; set; }
        Groups.MoreOptionsGroup more_options_group { get; set; }
        Groups.GameArgumentsGroup game_arguments_group { get; set; }
        Groups.AdvancedOptionsGroup advanced_options_group { get; set; }
        Groups.CommonOptionsGroup common_group { get; set; }
        Groups.DxvkOptionsGroup dxvk_options_group { get; set; }
        Groups.Vkd3dOptionsGroup vkd3d_options_group;
        Groups.GpuVendorOptionsGroup gpu_vendor_group;
        Groups.WrapperGroup wrapper_group;
        LaunchOptionPreviewField preview_field { get; set; }
        LaunchOptionsList launch_option_handlers;
        LaunchOptionCatalog catalog;
        LaunchOptionPresentationRegistry presentations;

        Adw.EntryRow search_entry { get; set; }
        Adw.ComboRow category_filter { get; set; }
        Gee.ArrayList<LaunchOptionView> category_filter_views;
        Gtk.Label no_results_label { get; set; }
        Gtk.Box categories_box { get; set; }
        Gee.HashMap<int, Gtk.Box> category_boxes;
        Gee.HashMap<string, Adw.PreferencesGroup> subsection_groups;
        bool refreshing_controls;
        bool updating_category_filter;

        LaunchOptionCategory[] canonical_categories = {
            LaunchOptionCategory.PERFORMANCE,
            LaunchOptionCategory.DISPLAY,
            LaunchOptionCategory.PROTON,
            LaunchOptionCategory.GRAPHICS,
            LaunchOptionCategory.HARDWARE,
            LaunchOptionCategory.INPUT_AUDIO,
            LaunchOptionCategory.GAME_ARGUMENTS,
            LaunchOptionCategory.DIAGNOSTICS
        };

        construct {
            launch_option_handlers = new LaunchOptionsList ();
            catalog = new LaunchOptionCatalog ();
            presentations = new LaunchOptionPresentationRegistry (catalog);
            category_boxes = new Gee.HashMap<int, Gtk.Box> ();
            subsection_groups = new Gee.HashMap<string, Adw.PreferencesGroup> ();
            category_filter_views = new Gee.ArrayList<LaunchOptionView> ();
            refreshing_controls = true;

            set_orientation (Gtk.Orientation.VERTICAL);
            set_spacing (15);

            preview_field = new LaunchOptionPreviewField (_("Command preview"));
            append (create_navigation ());

            common_group = new Groups.CommonOptionsGroup (launch_option_handlers, presentations);
            common_group.changed.connect (standard_control_changed);
            wrapper_group = new Groups.WrapperGroup (launch_option_handlers, presentations);
            wrapper_group.changed.connect (standard_control_changed);
            gpu_vendor_group = new Groups.GpuVendorOptionsGroup (launch_option_handlers, presentations);
            gpu_vendor_group.changed.connect (standard_control_changed);
            dxvk_options_group = new Groups.DxvkOptionsGroup (launch_option_handlers, presentations);
            dxvk_options_group.changed.connect (standard_control_changed);
            vkd3d_options_group = new Groups.Vkd3dOptionsGroup (launch_option_handlers, presentations);
            vkd3d_options_group.changed.connect (standard_control_changed);
            more_options_group = new Groups.MoreOptionsGroup (launch_option_handlers, presentations);
            more_options_group.changed.connect (standard_control_changed);
            proton_options_group = new Groups.ProtonOptionsGroup (launch_option_handlers, presentations);
            proton_options_group.changed.connect (standard_control_changed);
            audio_group = new Groups.AudioOptionsGroup (launch_option_handlers, presentations);
            audio_group.changed.connect (standard_control_changed);
            game_arguments_group = new Groups.GameArgumentsGroup (launch_option_handlers, presentations);
            game_arguments_group.changed.connect (standard_control_changed);
            advanced_options_group = new Groups.AdvancedOptionsGroup (launch_option_handlers, presentations);
            advanced_options_group.changed.connect (standard_control_changed);

            var raw_content_row = new Adw.ActionRow () {
                title = _("Preserved unrecognized launch options"),
                subtitle = _("Quoted, opaque, and unknown shell content is retained exactly as loaded.")
            };
            presentations.register ("raw-launch-options", raw_content_row, advanced_options_group.raw_arguments_binding);

            categories_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
            build_task_categories ();
            append (categories_box);

            no_results_label = new Gtk.Label (_("No matching launch options.")) {
                halign = Gtk.Align.CENTER,
                margin_top = 12,
                margin_bottom = 12,
                css_classes = { "dim-label" }
            };
            append (no_results_label);

            gpu_vendor_group.set_advanced_visible (true);
            refresh_filters ();
            refreshing_controls = false;
            refresh_preview ();
        }

        Gtk.Widget create_navigation () {
            var group = new Adw.PreferencesGroup () {
                title = _("Launch options")
            };

            search_entry = new Adw.EntryRow () {
                title = _("Search all options")
            };
            search_entry.set_tooltip_text (_("Search launch options"));
            search_entry.changed.connect (refresh_filters);
            group.add (search_entry);

            category_filter = new Adw.ComboRow () {
                title = _("Browse") ,
                model = new Gtk.StringList ({ _("Quick settings"), _("Active options"), _("All options") }),
                selected = 0
            };
            category_filter_views.add (LaunchOptionView.QUICK);
            category_filter_views.add (LaunchOptionView.ACTIVE);
            category_filter_views.add (LaunchOptionView.ALL);
            foreach (var category in canonical_categories)
                category_filter_views.add (LaunchOptionCatalog.category_view (category));
            var category_factory = new Gtk.SignalListItemFactory ();
            category_factory.setup.connect ((object) => {
                var list_item = object as Gtk.ListItem;
                var label = new Gtk.Label (null);
                label.set_xalign (0);
                label.set_ellipsize (Pango.EllipsizeMode.END);
                label.set_hexpand (true);
                object.set_data ("category-label", label);
                list_item.set_child (label);
            });
            category_factory.bind.connect ((object) => {
                var list_item = object as Gtk.ListItem;
                var category = list_item.get_item () as Gtk.StringObject;
                var label = object.get_data<Gtk.Label> ("category-label");
                if (category == null || label == null)
                    return;

                label.set_label (category.string);
                label.set_tooltip_text (category.string);
            });
            category_filter.set_list_factory (category_factory);
            category_filter.set_tooltip_text (category_filter.title);
            category_filter.notify["selected"].connect (() => {
                if (!updating_category_filter)
                    refresh_filters ();
            });
            group.add (category_filter);
            group.add (preview_field);
            return group;
        }

        void build_task_categories () {
            foreach (var category in canonical_categories)
                categories_box.append (create_category_box (category));

            foreach (var presentation in presentations.get_ordered ()) {
                if (!presentation.movable)
                    continue;

                var section = get_subsection_group (presentation.metadata.category, presentation.metadata.subsection);
                foreach (var widget in presentation.widgets) {
                    widget.unparent ();
                    section.add (widget);
                }
            }

            move_display_rows_into_backend_group ();
            collapse_raw_command_control ();

            /* The specialized backend and hardware widgets preserve their
             * own dependency state; they are placed in task categories rather
             * than being reclassified by their implementation details. */
            category_boxes.get ((int) LaunchOptionCategory.DISPLAY).insert_child_after (wrapper_group, category_boxes.get ((int) LaunchOptionCategory.DISPLAY).get_first_child ());
            category_boxes.get ((int) LaunchOptionCategory.HARDWARE).append (gpu_vendor_group);
        }

        void move_display_rows_into_backend_group () {
            string[] display_rows = { "native-wayland", "desktop-game-profile", "vkbasalt" };
            foreach (var id in display_rows) {
                var presentation = presentations.lookup (id);
                if (presentation == null)
                    continue;
                foreach (var widget in presentation.widgets) {
                    widget.unparent ();
                    wrapper_group.insert_before_backend_options (widget);
                }
            }
        }

        void collapse_raw_command_control () {
            var command = presentations.lookup ("steam-command");
            if (command == null)
                return;

            var disclosure = new Adw.ExpanderRow () {
                title = _("Raw command controls"),
                subtitle = _("Change the Steam command placeholder only when a game requires it."),
                expanded = false
            };
            disclosure.set_tooltip_text (disclosure.subtitle);
            foreach (var widget in command.widgets) {
                widget.unparent ();
                disclosure.add_row (widget);
            }
            presentations.register ("steam-command", disclosure, null);
            get_subsection_group (LaunchOptionCategory.DIAGNOSTICS, "").add (disclosure);
        }

        Gtk.Box create_category_box (LaunchOptionCategory category) {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            var header = new Gtk.Label (LaunchOptionCatalog.category_title (category)) {
                halign = Gtk.Align.START,
                xalign = 0,
                css_classes = { "title-3" }
            };
            box.append (header);
            category_boxes.set ((int) category, box);
            return box;
        }

        Adw.PreferencesGroup get_subsection_group (LaunchOptionCategory category, string subsection) {
            var key = "%d:%s".printf ((int) category, subsection);
            var group = subsection_groups.get (key);
            if (group != null)
                return group;

            group = new Adw.PreferencesGroup ();
            if (subsection != "")
                group.title = subsection;
            group.set_data<string> ("launch-options-subsection-key", key);
            subsection_groups.set (key, group);
            category_boxes.get ((int) category).append (group);
            return group;
        }

        public void clear () {
            set_text ("");
        }

        public bool has_clearable_state () {
            foreach (var handler in launch_option_handlers) {
                if (handler.is_active ())
                    return true;
            }
            return false;
        }

        public string get_text () {
            return launch_option_handlers.to_launch_line ();
        }

        public void set_text (string launch_options) {
            refreshing_controls = true;
            gpu_vendor_group.reset_controls ();
            launch_option_handlers.load_from_string (launch_options);
            gpu_vendor_group.normalize_dependencies ();
            refresh_filters ();
            refreshing_controls = false;
            refresh_preview ();
        }

        void standard_control_changed () {
            if (!refreshing_controls)
                launch_option_handlers.mark_modified ();
            refresh_filters ();
            refresh_preview ();
            if (!refreshing_controls)
                content_changed ();
        }

        void refresh_filters () {
            var query = search_entry.text.strip ();
            var view = get_selected_view ();
            presentations.apply_filter (view, query);

            foreach (var group in subsection_groups.values) {
                var parts = group.get_data<string> ("launch-options-subsection-key").split (":", 2);
                var category = (LaunchOptionCategory) int.parse (parts[0]);
                group.visible = presentations.has_visible_in_subsection (category, parts[1]);
            }

            var display_visible = presentations.has_visible_in_category (LaunchOptionCategory.DISPLAY)
                                  || wrapper_group.has_active_non_default_backend ();
            wrapper_group.set_presentation_visible (display_visible);
            gpu_vendor_group.set_presentation_visible (
                presentations.has_visible_in_category (LaunchOptionCategory.HARDWARE)
            );

            var any_visible = false;
            foreach (var category in canonical_categories) {
                var category_box = category_boxes.get ((int) category);
                var visible = presentations.has_visible_in_category (category);
                if (category == LaunchOptionCategory.DISPLAY)
                    visible = wrapper_group.visible;
                category_box.visible = visible;
                any_visible = any_visible || visible;
            }
            no_results_label.visible = !any_visible;

            if (update_category_filter_options (view))
                refresh_filters ();
        }

        LaunchOptionView get_selected_view () {
            if (category_filter.selected < category_filter_views.size)
                return category_filter_views.get ((int) category_filter.selected);
            return LaunchOptionView.QUICK;
        }

        bool update_category_filter_options (LaunchOptionView preferred_view) {
            var labels = new Gee.ArrayList<string> ();
            var views = new Gee.ArrayList<LaunchOptionView> ();
            labels.add (_("Quick settings"));
            views.add (LaunchOptionView.QUICK);
            labels.add (_("Active options"));
            views.add (LaunchOptionView.ACTIVE);
            labels.add (_("All options"));
            views.add (LaunchOptionView.ALL);

            foreach (var category in canonical_categories) {
                if (!category_has_dropdown_content (category))
                    continue;
                labels.add (LaunchOptionCatalog.category_title (category));
                views.add (LaunchOptionCatalog.category_view (category));
            }

            if (views_equal (category_filter_views, views))
                return false;

            uint selected = 0;
            for (var index = 0; index < views.size; index++) {
                if (views.get (index) == preferred_view) {
                    selected = (uint) index;
                    break;
                }
            }

            updating_category_filter = true;
            category_filter_views = views;
            category_filter.model = new Gtk.StringList (labels.to_array ());
            category_filter.selected = selected;
            updating_category_filter = false;
            return get_selected_view () != preferred_view;
        }

        bool category_has_dropdown_content (LaunchOptionCategory category) {
            if (category == LaunchOptionCategory.DISPLAY) {
                return Groups.WrapperGroup.should_show_backend_chrome (
                    Globals.GAMESCOPE_INSTALLED,
                    Globals.SCOPEBUDDY_INSTALLED,
                    wrapper_group.has_active_non_default_backend ()
                );
            }
            return presentations.has_registered_in_category (category);
        }

        bool views_equal (Gee.List<LaunchOptionView> first, Gee.List<LaunchOptionView> second) {
            if (first.size != second.size)
                return false;
            for (var index = 0; index < first.size; index++) {
                if (first.get (index) != second.get (index))
                    return false;
            }
            return true;
        }

        void refresh_preview () {
            preview_field.preview_label.set_markup (launch_option_handlers.build_preview_markup ());
            preview_field.set_empty (!launch_option_handlers.has_preview_content ());
            preview_field.set_attention_required (launch_option_handlers.has_unrecognized_or_opaque_content ());
        }
    }
}
