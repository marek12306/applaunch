using Gtk;

class AppFlowBoxChild : FlowBoxChild {
    public AppInfo app_info { get; private set; }
    public Popover? context_menu { get; set; }

    public int match_score = 0;

    public AppFlowBoxChild(AppInfo info) {
        this.app_info = info;
    }
}

public class AppGrid : Box {
    public FlowBox favorites_flowbox;
    public FlowBox all_apps_flowbox;
    private Separator separator;
    private AppInfoMonitor monitor;
    private Overlay overlay;
    private Box main_vbox;
    private Box drop_indicator;
    private string currently_dragged_id = "";
    private bool is_searching = false;

    public signal void app_launched();

    private bool get_coords(Widget src, Widget dest, out double out_x, out double out_y) {
        Graphene.Point p = Graphene.Point();
        p.x = 0.0f;
        p.y = 0.0f;

        Graphene.Point res;
        if (src.compute_point(dest, p, out res)) {
            out_x = res.x;
            out_y = res.y;
            return true;
        }

        out_x = 0.0;
        out_y = 0.0;
        return false;
    }

    // Find best gap to drop the icon based on distance
    private void find_best_gap(double x, double y, out int best_gap, out double best_gap_x, out double best_gap_y, out double min_dist) {
        best_gap = -1;
        min_dist = 999999.0;
        best_gap_x = 0;
        best_gap_y = 0;

        int n_children = 0;
        while (favorites_flowbox.get_child_at_index(n_children) != null)
            n_children++;
        if (n_children == 0)
            return;

        double spacing = Config.ITEM_SPACING;

        for (int i = 0; i <= n_children; i++) {
            if (i == 0) {
                var curr = favorites_flowbox.get_child_at_index(0);
                double cx, cy;
                get_coords(curr, overlay, out cx, out cy);
                double gap_x = cx - spacing / 2.0;
                double gap_y = cy;
                double center_gap_y = gap_y + curr.get_height() / 2.0;

                double dx = x - gap_x;
                double dy = y - center_gap_y;
                double dist = (dx * dx) * 1.5 + (dy * dy);
                if (dist < min_dist) {
                    min_dist =
                        dist;
                    best_gap = i;
                    best_gap_x = gap_x;
                    best_gap_y = gap_y;
                }
            } else if (i == n_children) {
                var prev = favorites_flowbox.get_child_at_index(n_children - 1);
                double px, py;
                get_coords(prev, overlay, out px, out py);
                double gap_x = px + prev.get_width() + spacing / 2.0;
                double gap_y = py;
                double center_gap_y = gap_y + prev.get_height() / 2.0;

                double dx = x - gap_x;
                double dy = y - center_gap_y;
                double dist = (dx * dx) * 1.5 + (dy * dy);
                if (dist < min_dist) {
                    min_dist = dist;
                    best_gap = i;
                    best_gap_x = gap_x;
                    best_gap_y = gap_y;
                }
            } else {
                var prev = favorites_flowbox.get_child_at_index(i - 1);
                var curr = favorites_flowbox.get_child_at_index(i);
                double px, py, cx, cy;
                get_coords(prev, overlay, out px, out py);
                get_coords(curr, overlay, out cx, out cy);

                double y_diff = py - cy;
                if (y_diff < 0)
                    y_diff = -y_diff;

                if (y_diff < 5.0) {
                    double gap_x = px + prev.get_width() + (cx - (px + prev.get_width())) / 2.0;
                    double gap_y = cy;
                    double center_gap_y = gap_y + curr.get_height() / 2.0;

                    double dx = x - gap_x;
                    double dy = y - center_gap_y;
                    double dist = (dx * dx) * 1.5 + (dy * dy);
                    if (dist < min_dist) {
                        min_dist = dist;
                        best_gap = i;
                        best_gap_x = gap_x;
                        best_gap_y = gap_y;
                    }
                } else {
                    double gap_x_a = px + prev.get_width() + spacing / 2.0;
                    double gap_y_a = py;
                    double center_gap_y_a = gap_y_a + prev.get_height() / 2.0;
                    double dx_a = x - gap_x_a;
                    double dy_a = y - center_gap_y_a;
                    double dist_a = (dx_a * dx_a) * 1.5 + (dy_a * dy_a);
                    if (dist_a < min_dist) {
                        min_dist = dist_a;
                        best_gap = i;
                        best_gap_x = gap_x_a;
                        best_gap_y = gap_y_a;
                    }

                    double gap_x_b = cx - spacing / 2.0;
                    double gap_y_b = cy;
                    double center_gap_y_b = gap_y_b + curr.get_height() / 2.0;
                    double dx_b = x - gap_x_b;
                    double dy_b = y - center_gap_y_b;
                    double dist_b = (dx_b * dx_b) * 1.5 + (dy_b * dy_b);
                    if (dist_b < min_dist) {
                        min_dist = dist_b;
                        best_gap = i;
                        best_gap_x = gap_x_b;
                        best_gap_y = gap_y_b;
                    }
                }
            }
        }
    }

    public AppGrid() {
        Object(orientation: Orientation.VERTICAL, spacing: 10);
        this.valign = Align.START;

        overlay = new Overlay();
        overlay.add_css_class("no-drop-highlight");
        this.append(overlay);

        main_vbox = new Box(Orientation.VERTICAL, 10);
        overlay.set_child(main_vbox);

        favorites_flowbox = create_flowbox(true);
        main_vbox.append(favorites_flowbox);

        separator = new Separator(Orientation.HORIZONTAL);
        separator.margin_top = 30;
        separator.margin_bottom = 30;
        separator.margin_start = 30;
        separator.margin_end = 30;
        main_vbox.append(separator);

        all_apps_flowbox = create_flowbox(false);
        main_vbox.append(all_apps_flowbox);

        drop_indicator = new Box(Orientation.VERTICAL, 0);
        drop_indicator.add_css_class("drop-indicator");
        drop_indicator.set_size_request(4, Config.ITEM_SIZE);
        drop_indicator.halign = Align.START;
        drop_indicator.valign = Align.START;
        drop_indicator.can_target = false;
        drop_indicator.set_visible(false);
        overlay.add_overlay(drop_indicator);

        var drop_target = new DropTarget(typeof (string), Gdk.DragAction.MOVE);

        drop_target.motion.connect((x, y) => {
            double fav_x, fav_y;
            if (!get_coords(favorites_flowbox, overlay, out fav_x, out fav_y))
                return 0;

            double rel_y = y - fav_y;

            if (rel_y < -40 || rel_y > favorites_flowbox.get_height() + 40) {
                drop_indicator.set_visible(false);
                return 0;
            }

            int n_children = 0;
            while (favorites_flowbox.get_child_at_index(n_children) != null)n_children++;

            int current_index = -1;
            for (int j = 0; j < n_children; j++) {
                var c = favorites_flowbox.get_child_at_index(j) as AppFlowBoxChild;
                string id = c.app_info.get_id() != null ? c.app_info.get_id() : c.app_info.get_name();
                if (id == currently_dragged_id) {
                    current_index = j;
                    break;
                }
            }

            int best_gap;
            double best_gap_x, best_gap_y, min_dist;

            find_best_gap(x, y, out best_gap, out best_gap_x, out best_gap_y, out min_dist);

            if (current_index != -1 && (best_gap == current_index || best_gap == current_index + 1)) {
                drop_indicator.set_visible(false);
                return Gdk.DragAction.MOVE;
            }

            if (best_gap != -1 && min_dist < 15000.0) {
                int ind_x = (int) (best_gap_x - 2);
                if (ind_x < 0)
                    ind_x = 0;

                drop_indicator.margin_start = ind_x;
                drop_indicator.margin_top = (int) best_gap_y;
                drop_indicator.set_visible(true);
            } else {
                drop_indicator.set_visible(false);
            }

            return Gdk.DragAction.MOVE;
        });

        drop_target.leave.connect(() => {
            drop_indicator.set_visible(false);
        });

        drop_target.drop.connect((val, x, y) => {
            bool was_visible = drop_indicator.get_visible();
            drop_indicator.set_visible(false);

            if (!was_visible)
                return false;

            int n_children = 0;
            while (favorites_flowbox.get_child_at_index(n_children) != null)
                n_children++;

            int best_gap;
            double best_gap_x, best_gap_y, min_dist;

            find_best_gap(x, y, out best_gap, out best_gap_x, out best_gap_y, out min_dist);

            if (best_gap != -1 && min_dist < 15000.0) {
                string dragged_id = val.get_string();
                string target_id = "";
                bool insert_after = false;

                if (best_gap < n_children) {
                    var c = favorites_flowbox.get_child_at_index(best_gap) as AppFlowBoxChild;
                    target_id = c.app_info.get_id() != null ? c.app_info.get_id() : c.app_info.get_name();
                    insert_after = false;
                } else {
                    var c = favorites_flowbox.get_child_at_index(best_gap - 1) as AppFlowBoxChild;
                    target_id = c.app_info.get_id() != null ? c.app_info.get_id() : c.app_info.get_name();
                    insert_after = true;
                }

                if (dragged_id != target_id) {
                    Favorites.get_default().move_app(dragged_id, target_id, insert_after);
                    favorites_flowbox.invalidate_sort();
                }
                return true;
            }
            return false;
        });

        overlay.add_controller(drop_target);

        favorites_flowbox.selected_children_changed.connect(() => {
            var selected = favorites_flowbox.get_selected_children();
            if (selected != null && selected.data != null)
                all_apps_flowbox.unselect_all();
        });

        all_apps_flowbox.selected_children_changed.connect(() => {
            var selected = all_apps_flowbox.get_selected_children();
            if (selected != null && selected.data != null)
                favorites_flowbox.unselect_all();
        });

        favorites_flowbox.child_activated.connect((child) => {
            if (child is AppFlowBoxChild)
                launch_app(((AppFlowBoxChild) child).app_info);
        });

        all_apps_flowbox.child_activated.connect((child) => {
            if (child is AppFlowBoxChild)
                launch_app(((AppFlowBoxChild) child).app_info);
        });

        reload_apps();
        monitor = AppInfoMonitor.get();
        monitor.changed.connect(() => {
            Favorites.get_default().cleanup_uninstalled();
            reload_apps();
        });
    }

    public bool filter_apps(string text) {
        bool was_searching = is_searching;
        is_searching = (text != "");

        if (is_searching && !was_searching) {
            // Move all favorites to the main flowbox
            // so we have everything in one place when searching
            Widget? child;
            while ((child = favorites_flowbox.get_first_child()) != null) {
                favorites_flowbox.remove(child);
                all_apps_flowbox.insert(child, -1);
            }
        } else if (!is_searching && was_searching) {
            // Revert to original state: move favorites back to the top if they are still favorites
            Widget? child = all_apps_flowbox.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                var app_child = child as AppFlowBoxChild;
                if (app_child != null) {
                    string id = app_child.app_info.get_id() != null? app_child.app_info.get_id() : app_child.app_info.get_name();

                    if (Favorites.get_default().is_favorite(id)) {
                        all_apps_flowbox.remove(child);
                        favorites_flowbox.insert(child, -1);
                    }
                }
                child = next;
            }
        }

        if (!is_searching) {
            // Reset state of all items
            favorites_flowbox.set_filter_func((child) => { ((AppFlowBoxChild) child).match_score = 0; return true; });
            all_apps_flowbox.set_filter_func((child) => { ((AppFlowBoxChild) child).match_score = 0; return true; });

            favorites_flowbox.invalidate_filter();
            all_apps_flowbox.invalidate_filter();
            favorites_flowbox.invalidate_sort();
            all_apps_flowbox.invalidate_sort();

            unselect_all();
            update_section_visibility();

            return (favorites_flowbox.get_child_at_index(0) != null) || (all_apps_flowbox.get_child_at_index(0) != null);
        }

        all_apps_flowbox.set_filter_func((child) => is_app_matching(child as AppFlowBoxChild, text));
        all_apps_flowbox.invalidate_filter();
        all_apps_flowbox.invalidate_sort();

        unselect_all();

        favorites_flowbox.set_visible(false);
        separator.set_visible(false);

        bool has_visible_all = false;
        for (int i = 0; ; i++) {
            var child = all_apps_flowbox.get_child_at_index(i) as AppFlowBoxChild;
            if (child == null)
                break;

            if (child.match_score > 0) {
                has_visible_all = true;
                all_apps_flowbox.select_child(child);
                break;
            }
        }

        all_apps_flowbox.set_visible(has_visible_all);
        return has_visible_all;
    }

    public void unselect_all() {
        favorites_flowbox.unselect_all();
        all_apps_flowbox.unselect_all();
    }

    public bool launch_selected() {
        var selected_fav = favorites_flowbox.get_selected_children();
        var selected_all = all_apps_flowbox.get_selected_children();

        if (selected_fav != null && selected_fav.data != null) {
            launch_app(((AppFlowBoxChild) selected_fav.data).app_info);
            return true;
        } else if (selected_all != null && selected_all.data != null) {
            launch_app(((AppFlowBoxChild) selected_all.data).app_info);
            return true;
        }

        return false;
    }

    public bool grab_focus_first() {
        if (favorites_flowbox.get_visible() && favorites_flowbox.get_child_at_index(0) != null) {
            favorites_flowbox.get_child_at_index(0).grab_focus();
            return true;
        } else if (all_apps_flowbox.get_visible() && all_apps_flowbox.get_child_at_index(0) != null) {
            all_apps_flowbox.get_child_at_index(0).grab_focus();
            return true;
        }
        return false;
    }

    private FlowBox create_flowbox(bool is_favorites = false) {
        var flowbox = new FlowBox();
        flowbox.valign = Align.START;
        flowbox.max_children_per_line = Config.ITEMS_PER_ROW;
        flowbox.min_children_per_line = Config.ITEMS_PER_ROW;
        flowbox.homogeneous = true;
        flowbox.selection_mode = SelectionMode.SINGLE;
        flowbox.activate_on_single_click = false;
        flowbox.row_spacing = Config.ITEM_SPACING;
        flowbox.column_spacing = Config.ITEM_SPACING;

        flowbox.set_sort_func((child1, child2) => {
            var app1 = child1 as AppFlowBoxChild;
            var app2 = child2 as AppFlowBoxChild;
            if (app1 == null || app2 == null)
                return 0;

            // Sort by match score
            if (app1.match_score > 0 || app2.match_score > 0)
                if (app1.match_score != app2.match_score)
                    return app2.match_score - app1.match_score;

            // Sort by favorites order or alphabetically
            if (is_favorites) {
                string id1 = app1.app_info.get_id() != null ? app1.app_info.get_id() : app1.app_info.get_name();
                string id2 = app2.app_info.get_id() != null ? app2.app_info.get_id() : app2.app_info.get_name();
                return Favorites.get_default().get_position(id1) - Favorites.get_default().get_position(id2);
            } else {
                string name1 = app1.app_info.get_name() != null ? app1.app_info.get_name() : "";
                string name2 = app2.app_info.get_name() != null ? app2.app_info.get_name() : "";
                return name1.down().collate(name2.down());
            }
        });

        return flowbox;
    }

    private void update_section_visibility() {
        bool has_favs = favorites_flowbox.get_child_at_index(0) != null;
        bool has_all = all_apps_flowbox.get_child_at_index(0) != null;

        favorites_flowbox.set_visible(has_favs);
        all_apps_flowbox.set_visible(has_all);

        // Separator is visible only if both sections have items, to visually separate them
        separator.set_visible(has_favs && has_all);

        if (has_favs)
            favorites_flowbox.select_child(favorites_flowbox.get_child_at_index(0));
        else if (has_all)
            all_apps_flowbox.select_child(all_apps_flowbox.get_child_at_index(0));
    }

    private void launch_app(AppInfo app_info) {
        try {
            var desktop_info = app_info as DesktopAppInfo;
            if (desktop_info != null && desktop_info.get_filename() != null)
                Utils.launch_detached("gio launch", desktop_info.get_filename());
            else
                app_info.launch(null, new AppLaunchContext());
            app_launched();
        } catch (Error e) {
            stderr.printf("Launch error: %s\n", e.message);
        }
    }

    private bool is_app_matching(AppFlowBoxChild? app_child, string text) {
        if (app_child == null || app_child.app_info == null)return false;

        if (text == "") {
            app_child.match_score = 0;
            return true;
        }

        var info = app_child.app_info;

        string name = info.get_name() != null? info.get_name().down() : "";

        string display_name = info.get_display_name() != null? info.get_display_name().down() : "";

        string desc = info.get_description() != null? info.get_description().down() : "";

        string exec = info.get_executable() != null? info.get_executable().down() : "";

        string id = info.get_id() != null? info.get_id().down() : "";

        string original_name = "";
        string keywords = "";

        var desktop_info = info as DesktopAppInfo;
        if (desktop_info != null) {
            string? raw_name = desktop_info.get_string("Name");
            if (raw_name != null)
                original_name = raw_name.down();

            string? raw_keywords = desktop_info.get_string("Keywords");
            if (raw_keywords != null)
                keywords = raw_keywords.down();
        }

        int score = 0;

        // 100 score - name starts with text
        if (name.has_prefix(text) || original_name.has_prefix(text))
            score = 100;
        // 80 score - name contains text
        else if (name.contains(text) || original_name.contains(text) || exec.contains(text) || display_name.contains(text) || id.contains(text))
            score = 80;
        // 60 score - fuzzy match (subsequence)
        else if (Utils.fuzzy_subsequence_match(name, text) || Utils.fuzzy_subsequence_match(exec, text) || Utils.fuzzy_subsequence_match(original_name, text))
            score = 60;
        // 40 score - keywords contain text
        else if (keywords.contains(text) || desc.contains(text))
            score = 40;
        // 10 score - supported mime types contain text
        else {
            string[] ? supported_types = info.get_supported_types();
            if (supported_types != null)
                foreach (string mime_type in supported_types)
                    if (mime_type.down().contains(text)) {
                        score = 10;
                        break;
                    }
        }

        app_child.match_score = score;

        return score > 0;
    }

    private void show_context_menu(AppFlowBoxChild flowbox_child, Box app_box, string app_id, double x, double y) {
        if (flowbox_child.context_menu == null) {
            var context_menu = new Popover();
            flowbox_child.context_menu = context_menu;
            app_box.append(context_menu);

            context_menu.closed.connect(() => {
                favorites_flowbox.unselect_all();
                all_apps_flowbox.unselect_all();
            });

            var popover_box = new Box(Orientation.VERTICAL, 0);

            var fav_btn = new Button();
            fav_btn.add_css_class("flat");

            fav_btn.clicked.connect(() => {
                context_menu.popdown();

                Favorites.get_default().toggle(app_id);
                var parent = flowbox_child.get_parent();
                if (parent is FlowBox)
                    ((FlowBox) parent).remove(flowbox_child);

                if (is_searching) {
                    all_apps_flowbox.insert(flowbox_child, -1);
                    all_apps_flowbox.invalidate_sort();
                } else {
                    if (Favorites.get_default().is_favorite(app_id))
                        favorites_flowbox.insert(flowbox_child, -1);
                    else
                        all_apps_flowbox.insert(flowbox_child, -1);
                    update_section_visibility();
                }
            });

            popover_box.append(fav_btn);

            var desktop_info = flowbox_child.app_info as DesktopAppInfo;
            if (desktop_info != null) {
                string[] actions = desktop_info.list_actions();

                if (actions.length > 0) {
                    var sep = new Separator(Orientation.HORIZONTAL);
                    sep.margin_top = 4;
                    sep.margin_bottom = 4;
                    popover_box.append(sep);

                    foreach (string action_name in actions) {
                        string readable_name = desktop_info.get_action_name(action_name);

                        var action_btn = new Button.with_label(readable_name);
                        action_btn.add_css_class("flat");

                        action_btn.clicked.connect(() => {
                            context_menu.popdown();

                            if (desktop_info.get_filename() != null) {
                                try {
                                    var keyfile = new KeyFile();
                                    keyfile.load_from_file(desktop_info.get_filename(), KeyFileFlags.NONE);

                                    string group_name = "Desktop Action " + action_name;
                                    string exec_cmd = keyfile.get_string(group_name, "Exec");

                                    string clean_cmd = exec_cmd;
                                    try {
                                        var regex = new Regex("%[a-zA-Z]");
                                        clean_cmd = regex.replace(exec_cmd, -1, 0, "");
                                    } catch (Error e) {}

                                    string cmd = "setsid " + clean_cmd.strip();
                                    Process.spawn_command_line_async(cmd);
                                } catch (Error e) {
                                    stderr.printf("Error launching action '%s': %s\n", readable_name, e.message);
                                }
                            }
                            this.set_visible(false);
                        });

                        popover_box.append(action_btn);
                    }
                }
            }

            context_menu.set_child(popover_box);
        }

        var btn = (Button) ((Box) flowbox_child.context_menu.get_child()).get_first_child();
        btn.label = Favorites.get_default().is_favorite(app_id) ? "Remove from favorites" : "Add to favorites";

        Gdk.Rectangle rect = { (int) x, (int) y, 1, 1 };
        flowbox_child.context_menu.set_pointing_to(rect);
        flowbox_child.context_menu.popup();
    }

    private void reload_apps() {
        Widget? child;
        while ((child = favorites_flowbox.get_first_child()) != null)
            favorites_flowbox.remove(child);
        while ((child = all_apps_flowbox.get_first_child()) != null)
            all_apps_flowbox.remove(child);

        var apps = AppInfo.get_all();
        foreach (var app_info in apps) {
            if (!app_info.should_show())
                continue;

            var flowbox_child = new AppFlowBoxChild(app_info);
            flowbox_child.set_size_request(Config.ITEM_SIZE, Config.ITEM_SIZE);
            flowbox_child.halign = Align.CENTER;
            flowbox_child.valign = Align.START;

            var app_box = new Box(Orientation.VERTICAL, 8);
            app_box.margin_top = Config.APP_MARGIN;
            app_box.margin_bottom = Config.APP_MARGIN;
            app_box.margin_start = Config.APP_MARGIN;
            app_box.margin_end = Config.APP_MARGIN;
            app_box.halign = Align.CENTER;
            app_box.valign = Align.START;

            var image = new Image();
            Icon? icon = app_info.get_icon();
            if (icon != null)
                image.set_from_gicon(icon);
            else
                image.set_from_icon_name("application-x-executable");

            image.pixel_size = Config.ICON_SIZE;
            image.margin_top = 10;

            app_box.append(image);

            var label = new Label(app_info.get_name());
            label.halign = Align.CENTER;
            label.valign = Align.START;
            label.ellipsize = Pango.EllipsizeMode.END;
            label.wrap = true;
            label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            label.lines = 1;
            label.set_size_request(-1, 55);
            label.justify = Justification.CENTER;
            app_box.append(label);

            flowbox_child.set_child(app_box);

            var hover_controller = new EventControllerMotion();
            hover_controller.enter.connect((x, y) => { label.lines = 3; });
            hover_controller.leave.connect(() => { label.lines = 1; });
            flowbox_child.add_controller(hover_controller);

            string app_id = app_info.get_id() != null? app_info.get_id() : app_info.get_name();

            var right_click_controller = new GestureClick();
            right_click_controller.button = Gdk.BUTTON_SECONDARY;
            right_click_controller.pressed.connect((n, x, y) => show_context_menu(flowbox_child, app_box, app_id, x, y));
            app_box.add_controller(right_click_controller);

            var long_press_controller = new GestureLongPress();
            long_press_controller.pressed.connect((x, y) => show_context_menu(flowbox_child, app_box, app_id, x, y));
            app_box.add_controller(long_press_controller);

            var left_click_controller = new GestureClick();
            left_click_controller.button = 0;
            left_click_controller.pressed.connect((n, x, y) => {
                var parent = flowbox_child.get_parent();
                if (parent is FlowBox)
                    ((FlowBox) parent).select_child(flowbox_child);
            });

            left_click_controller.released.connect((n, x, y) => {
                if (left_click_controller.get_current_button() == Gdk.BUTTON_SECONDARY)
                    return;

                double tolerance = 30.0;
                if (x >= -tolerance && x <= flowbox_child.get_width() + tolerance &&
                    y >= -tolerance && y <= flowbox_child.get_height() + tolerance) {
                    launch_app(app_info);
                } else {
                    favorites_flowbox.unselect_all();
                    all_apps_flowbox.unselect_all();
                }
            });
            left_click_controller.cancel.connect((sequence) => {
                favorites_flowbox.unselect_all();
                all_apps_flowbox.unselect_all();
            });
            flowbox_child.add_controller(left_click_controller);

            var drag_source = new DragSource();
            drag_source.actions = Gdk.DragAction.MOVE;
            drag_source.prepare.connect((x, y) => {
                // Only favorite icons are allowed to be dragged
                // and rearranged
                if (!Favorites.get_default().is_favorite(app_id))
                    return null;

                Value val = Value(typeof (string));
                val.set_string(app_id);
                return new Gdk.ContentProvider.for_value(val);
            });

            drag_source.drag_begin.connect((drag) => {
                currently_dragged_id = app_id;

                var drag_widget = new Image();
                Icon? ic = app_info.get_icon();
                if (ic != null)
                    drag_widget.set_from_gicon(ic);
                else drag_widget.set_from_icon_name("application-x-executable");

                drag_widget.pixel_size = Config.ICON_SIZE;
                var drag_icon = Gtk.DragIcon.get_for_drag(drag) as Gtk.DragIcon;
                if (drag_icon != null)
                    drag_icon.set_child(drag_widget);
            });

            drag_source.drag_end.connect((drag, delete_data) => {
                currently_dragged_id = "";
                if (drop_indicator != null)
                    drop_indicator.set_visible(false);
            });

            flowbox_child.add_controller(drag_source);

            if (is_searching) {
                all_apps_flowbox.insert(flowbox_child, -1);
            } else {
                if (Favorites.get_default().is_favorite(app_id))
                    favorites_flowbox.insert(flowbox_child, -1);
                else
                    all_apps_flowbox.insert(flowbox_child, -1);
            }
        }

        if (!is_searching)
            update_section_visibility();
        favorites_flowbox.invalidate_filter();
        all_apps_flowbox.invalidate_filter();
    }
}