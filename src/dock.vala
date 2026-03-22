using Gtk;
using GtkLayerShell;
using GLib;
using Json;

class DockAppButton : Button {
    public AppInfo app_info;
    public bool is_favorite;
    public NiriWindow[] open_windows;

    private Box indicator_box;
    private LauncherWindow launcher;
    private DockWindow dock;
    private Box vbox;
    private Popover? context_menu = null;
    private Popover? window_selector = null;

    public DockAppButton (AppInfo info, bool fav, LauncherWindow launcher, DockWindow dock) {
        this.app_info = info;
        this.is_favorite = fav;
        this.launcher = launcher;
        this.dock = dock;
        this.open_windows = new NiriWindow[0];

        this.add_css_class ("circular");
        this.add_css_class ("dock-btn");
        this.tooltip_text = info.get_name ();
        this.focusable = false;
        this.set_size_request (72, 72);

        vbox = new Box (Orientation.VERTICAL, 2);
        vbox.halign = Align.CENTER;
        vbox.valign = Align.CENTER;

        var top_spacer = new Box (Orientation.HORIZONTAL, 0);
        top_spacer.set_size_request (-1, 5);
        vbox.append (top_spacer);

        var image = new Image ();
        Icon? icon = app_info.get_icon ();

        if (icon != null)
            image.set_from_gicon (icon);
        else
            image.set_from_icon_name ("application-x-executable");
        image.pixel_size = 42;
        vbox.append (image);

        indicator_box = new Box (Orientation.HORIZONTAL, 2);
        indicator_box.halign = Align.CENTER;
        indicator_box.valign = Align.START;
        indicator_box.add_css_class ("dock-indicator-box");
        indicator_box.set_size_request (-1, 5);
        vbox.append (indicator_box);

        this.set_child (vbox);

        var touch_feedback = new GestureClick ();
        touch_feedback.pressed.connect ((n, x, y) => {
            this.set_state_flags (StateFlags.PRELIGHT, false);
        });

        touch_feedback.released.connect ((n, x, y) => {
            this.unset_state_flags (StateFlags.PRELIGHT);
        });

        touch_feedback.cancel.connect ((sequence) => {
            this.unset_state_flags (StateFlags.PRELIGHT);
        });

        this.add_controller (touch_feedback);

        this.clicked.connect (() => {
            this.set_state_flags (StateFlags.NORMAL, true);

            if (this.open_windows.length == 0) {
                launch_new_instance ();
                if (this.launcher.get_visible ())
                    this.launcher.set_visible (false);
            } else if (this.open_windows.length == 1) {
                uint32 wid = this.open_windows[0].id;
                NiriIpc.get_default ().action_focus_window (wid);

                if (this.launcher.get_visible ())
                    this.launcher.set_visible (false);
            } else {
                show_window_selector ();
            }
        });

        var right_click_controller = new GestureClick ();
        right_click_controller.button = Gdk.BUTTON_SECONDARY;
        right_click_controller.pressed.connect ((n, x, y) => {
            show_context_menu (x, y);
        });

        this.add_controller (right_click_controller);

        var long_press_controller = new GestureLongPress ();
        long_press_controller.pressed.connect ((x, y) => {
            show_context_menu (x, y);
        });

        this.add_controller (long_press_controller);
    }

    public void launch_new_instance () {
        try {
            app_info.launch (null, null);
        } catch (Error e) {}
    }

    public bool is_popover_open () {
        return (context_menu != null && context_menu.get_visible ()) ||
               (window_selector != null && window_selector.get_visible ());
    }

    public void hide_popover () {
        if (context_menu != null)
            context_menu.popdown ();
        if (window_selector != null)
            window_selector.popdown ();
    }

    private void show_window_selector () {
        if (window_selector != null) {
            vbox.remove (window_selector);
            window_selector = null;
        }

        window_selector = new Popover ();
        window_selector.closed.connect (() => {
            dock.schedule_check_hide ();
        });

        var listbox = new ListBox ();
        listbox.selection_mode = SelectionMode.NONE;

        foreach (var win in this.open_windows) {
            string display_title = win.title != "" ? win.title : "Application window";
            if (display_title.char_count () > 40)
                display_title = display_title.substring (0, 37) + "...";

            var row = new ListBoxRow ();

            var row_box = new Box (Orientation.HORIZONTAL, 8);
            row_box.margin_start = 8;
            row_box.margin_end = 4;
            row_box.margin_top = 4;
            row_box.margin_bottom = 4;

            var label = new Label (display_title);
            label.hexpand = true;
            label.halign = Align.START;

            var close_btn = new Button.from_icon_name ("window-close-symbolic");
            close_btn.add_css_class ("flat");
            close_btn.add_css_class ("circular");
            close_btn.tooltip_text = "Close window";
            close_btn.valign = Align.CENTER;

            uint32 wid = win.id;

            close_btn.clicked.connect (() => {
                window_selector.popdown ();
                NiriIpc.get_default ().action_close_window (wid);
                if (this.launcher.get_visible ())
                    this.launcher.set_visible (false);
            });

            row_box.append (label);
            row_box.append (close_btn);
            row.set_child (row_box);

            listbox.append (row);
        }

        listbox.row_activated.connect ((row) => {
            int index = row.get_index ();
            if (index >= 0 && index < this.open_windows.length) {
                uint32 wid = this.open_windows[index].id;
                window_selector.popdown ();

                NiriIpc.get_default ().action_focus_window (wid);

                if (this.launcher.get_visible ())
                    this.launcher.set_visible (false);
            }
        });

        window_selector.set_child (listbox);
        vbox.append (window_selector);
        window_selector.popup ();
    }

    private void show_context_menu (double x, double y) {
        if (context_menu != null) {
            vbox.remove (context_menu);
            context_menu = null;
        }

        context_menu = new Popover ();

        context_menu.closed.connect (() => {
            dock.schedule_check_hide ();
        });

        var box = new Box (Orientation.VERTICAL, 0);

        var new_win_btn = new Button.with_label ("New window");
        new_win_btn.add_css_class ("flat");

        new_win_btn.clicked.connect (() => {
            context_menu.popdown ();
            launch_new_instance ();
            if (this.launcher.get_visible ())
                this.launcher.set_visible (false);
        });

        box.append (new_win_btn);

        if (this.open_windows.length > 0) {
            string label = this.open_windows.length > 1 ?
                "Close all windows" : "Close window";
            var close_btn = new Button.with_label (label);
            close_btn.add_css_class ("flat");
            close_btn.clicked.connect (() => {
                context_menu.popdown ();
                foreach (var win in this.open_windows)
                    NiriIpc.get_default ().action_close_window (win.id);

                if (this.launcher.get_visible ())
                    this.launcher.set_visible (false);
            });
            box.append (close_btn);
        }

        var desktop_info = app_info as DesktopAppInfo;
        if (desktop_info != null) {
            string[] actions = desktop_info.list_actions ();
            if (actions.length > 0) {
                var sep = new Separator (Orientation.HORIZONTAL);
                sep.margin_top = 4;
                sep.margin_bottom = 4;
                box.append (sep);

                foreach (string action_name in actions) {
                    string readable_name = desktop_info.get_action_name (action_name);
                    var action_btn = new Button.with_label (readable_name);
                    action_btn.add_css_class ("flat");

                    action_btn.clicked.connect (() => {
                        context_menu.popdown ();
                        if (desktop_info.get_filename () != null) {
                            try {
                                var keyfile = new KeyFile ();
                                keyfile.load_from_file (desktop_info.get_filename (), KeyFileFlags.NONE);
                                string group_name = "Desktop Action " + action_name;
                                string exec_cmd = keyfile.get_string (group_name, "Exec");

                                string clean_cmd = exec_cmd;
                                try {
                                    var regex = new Regex ("%[a-zA-Z]");
                                    clean_cmd = regex.replace (exec_cmd, -1, 0, "");
                                } catch (Error e) {}

                                string cmd = "setsid " + clean_cmd.strip ();
                                Process.spawn_command_line_async (cmd);
                            } catch (Error e) {}
                        }
                        if (this.launcher.get_visible ())
                            this.launcher.set_visible (false);
                    });

                    box.append (action_btn);
                }
            }
        }

        context_menu.set_child (box);
        vbox.append (context_menu);

        Gdk.Rectangle rect = { (int) x, (int) y, 1, 1 };
        context_menu.set_pointing_to (rect);
        context_menu.popup ();
    }

    public void set_windows (int count) {
        Widget? child;
        while ((child = indicator_box.get_first_child ()) != null)
            indicator_box.remove (child);

        if (count == 0)
            return;

        if (count <= 5) {
            for (int i = 0; i < count; i++) {
                var dot = new Box (Orientation.HORIZONTAL, 0);
                dot.add_css_class ("dock-dot");
                indicator_box.append (dot);
            }
        } else {
            var line = new Box (Orientation.HORIZONTAL, 0);
            line.add_css_class ("dock-line");
            indicator_box.append (line);
        }
    }
}

public class DockWindow : ApplicationWindow {
    private static int global_dock_id = 0;

    private Box apps_box;
    private LauncherWindow launcher;
    private Box wrapper;
    private double current_offset = -100.0;
    private double current_target = -100.0;
    private uint anim_tick_id = 0;
    private double drag_start_offset = 0.0;
    private uint hide_timeout_id = 0;

    private string? monitor_connector = null;
    private HashTable<string, DockAppButton> active_app_buttons;
    private Separator open_apps_separator;

    private ulong favorites_changed_id = 0;
    private ulong windows_changed_id = 0;
    private bool is_cleaned_up = false;

    public bool is_hovering = false;

    public DockWindow (Gtk.Application app, LauncherWindow launcher, Gdk.Monitor? monitor = null) {
        GLib.Object (application : app);
        this.launcher = launcher;
        this.title = "applaunch-dock";
        this.add_css_class ("dock-window");

        active_app_buttons = new HashTable<string, DockAppButton> (str_hash, str_equal);

        GtkLayerShell.init_for_window (this);

        global_dock_id++;
        string conn_name = "monitor-" + global_dock_id.to_string ();

        if (monitor != null) {
            this.monitor_connector = monitor.get_connector ();
            if (this.monitor_connector != null)
                conn_name = this.monitor_connector;
            GtkLayerShell.set_monitor (this, monitor);
        }

        GtkLayerShell.set_namespace (this, "dock-" + conn_name);
        GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
        GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.NONE);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
        GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, 0);

        wrapper = new Box (Orientation.VERTICAL, 0);
        wrapper.valign = Align.END;
        wrapper.halign = Align.CENTER;
        wrapper.set_opacity (0.0);
        this.set_child (wrapper);

        var top_trigger = new Box (Orientation.HORIZONTAL, 0);
        top_trigger.set_size_request (-1, 5);
        top_trigger.add_css_class ("invisible-trigger");
        wrapper.append (top_trigger);

        var main_box = new Box (Orientation.HORIZONTAL, 8);
        main_box.add_css_class ("dock-container");
        main_box.margin_top = 0;
        main_box.margin_bottom = 10;
        main_box.margin_start = 8;
        main_box.margin_end = 8;
        main_box.halign = Align.CENTER;
        wrapper.append (main_box);

        var size_group = new SizeGroup (SizeGroupMode.HORIZONTAL);
        size_group.add_widget (main_box);
        size_group.add_widget (top_trigger);

        var motion_controller = new EventControllerMotion ();

        motion_controller.enter.connect ((x, y) => {
            is_hovering = true;
            if (hide_timeout_id != 0) {
                Source.remove (hide_timeout_id);
                hide_timeout_id = 0;
            }
            animate_to (0.0);
        });

        motion_controller.leave.connect (() => {
            is_hovering = false;
            check_hide ();
        });

        wrapper.add_controller (motion_controller);

        var drag_gesture = new GestureDrag ();
        drag_gesture.set_propagation_phase (PropagationPhase.CAPTURE);

        drag_gesture.drag_begin.connect ((start_x, start_y) => {
            if (anim_tick_id != 0) {
                this.remove_tick_callback (anim_tick_id);
                anim_tick_id = 0;
            }
            drag_start_offset = current_offset;

            if (hide_timeout_id != 0) {
                Source.remove (hide_timeout_id);
                hide_timeout_id = 0;
            }
        });

        drag_gesture.drag_update.connect ((offset_x, offset_y) => {
            if (offset_y > 20 || offset_y < -20)
                drag_gesture.set_state (EventSequenceState.CLAIMED);
            current_offset = drag_start_offset - offset_y;
            double hidden_off = get_hidden_offset ();
            if (current_offset > 0)
                current_offset = 0;
            if (current_offset < hidden_off)
                current_offset = hidden_off;

            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, (int) current_offset);
        });

        drag_gesture.drag_end.connect ((offset_x, offset_y) => { snap_to_target (); });
        drag_gesture.cancel.connect ((sequence) => { snap_to_target (); });
        wrapper.add_controller (drag_gesture);

        var swipe_gesture = new GestureSwipe ();
        swipe_gesture.set_propagation_phase (PropagationPhase.CAPTURE);
        swipe_gesture.swipe.connect ((vx, vy) => {
            if (vy < -100)
                animate_to (0.0);
            else if (vy > 100)
                animate_to (get_hidden_offset ());
        });

        wrapper.add_controller (swipe_gesture);

        apps_box = new Box (Orientation.HORIZONTAL, 6);
        main_box.append (apps_box);

        favorites_changed_id = Favorites.get_default ().changed.connect (reload_dock);
        reload_dock ();

        Timeout.add (50, () => {
            int h = wrapper.get_height ();
            if (h <= 0)
                return Source.CONTINUE;

            current_offset = get_hidden_offset ();
            current_target = current_offset;
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, (int) current_offset);

            wrapper.set_opacity (1.0);
            return Source.REMOVE;
        });

        windows_changed_id = NiriWindowManager.get_default ().windows_changed.connect (update_windows_ui);

        update_windows_ui ();
    }

    public void cleanup () {
        is_cleaned_up = true;

        if (favorites_changed_id != 0) {
            Favorites.get_default ().disconnect (favorites_changed_id);
            favorites_changed_id = 0;
        }
        if (windows_changed_id != 0) {
            NiriWindowManager.get_default ().disconnect (windows_changed_id);
            windows_changed_id = 0;
        }
        if (hide_timeout_id != 0) {
            Source.remove (hide_timeout_id);
            hide_timeout_id = 0;
        }
        if (anim_tick_id != 0) {
            this.remove_tick_callback (anim_tick_id);
            anim_tick_id = 0;
        }
    }

    public bool is_any_popover_open () {
        foreach (var btn in active_app_buttons.get_values ())
            if (btn.is_popover_open ())
                return true;
        return false;
    }

    public void check_hide () {
        if (!is_hovering && !is_any_popover_open ()) {
            if (hide_timeout_id == 0) {
                hide_timeout_id = Timeout.add (300, () => {
                    animate_to (get_hidden_offset ());
                    hide_timeout_id = 0;
                    return Source.REMOVE;
                });
            }
        }
    }

    public void schedule_check_hide () {
        Timeout.add (50, () => {
            check_hide ();
            return Source.REMOVE;
        });
    }

    private void add_static_buttons () {
        var launcher_btn = new Button ();
        launcher_btn.add_css_class ("circular");
        launcher_btn.add_css_class ("dock-btn");
        launcher_btn.tooltip_text = "Launcher";
        launcher_btn.focusable = false;
        launcher_btn.set_size_request (72, 72);
        var launcher_icon = new Image.from_icon_name ("view-app-grid-symbolic");
        launcher_icon.pixel_size = 42;

        launcher_btn.set_child (launcher_icon);
        launcher_btn.clicked.connect (() => {
            launcher_btn.set_state_flags (StateFlags.NORMAL, true);
            if (this.launcher.get_visible ())
                this.launcher.set_visible (false);
            else
                this.launcher.present ();
        });

        apps_box.append (launcher_btn);

        var overview_btn = new Button ();
        overview_btn.add_css_class ("circular");
        overview_btn.add_css_class ("dock-btn");
        overview_btn.tooltip_text = "Overview";
        overview_btn.focusable = false;
        overview_btn.set_size_request (72, 72);

        var overview_icon = new Image.from_icon_name ("view-continuous-symbolic");
        overview_icon.pixel_size = 34;
        overview_btn.set_child (overview_icon);

        overview_btn.clicked.connect (() => {
            overview_btn.set_state_flags (StateFlags.NORMAL, true);
            NiriIpc.get_default ().action_toggle_overview ();
        });
        apps_box.append (overview_btn);
    }

    private void snap_to_target () {
        double hidden_off = get_hidden_offset ();
        if (current_offset > hidden_off / 2.0)
            animate_to (0.0);
        else
            animate_to (hidden_off);
    }

    private double get_hidden_offset () {
        int h = wrapper.get_height ();
        if (h <= 0)
            return -100.0;
        return -(h - 5.0);
    }

    private void close_all_popovers () {
        foreach (var btn in active_app_buttons.get_values ())
            btn.hide_popover ();
    }

    private void animate_to (double target) {
        current_target = target;

        if (current_target == get_hidden_offset ())
            close_all_popovers ();

        if (anim_tick_id != 0)return;

        anim_tick_id = this.add_tick_callback ((widget, frame_clock) => {
            double diff = current_target - current_offset;
            if (diff > -0.5 && diff < 0.5) {
                current_offset = current_target;
                GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, (int) current_offset);
                anim_tick_id = 0;
                return false;
            }

            current_offset += diff * 0.25;
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, (int) current_offset);

            return true;
        });
    }

    private void reload_dock () {
        Widget? child;
        while ((child = apps_box.get_first_child ()) != null)
            apps_box.remove (child);

        active_app_buttons.remove_all ();
        add_static_buttons ();
        load_favorites ();

        open_apps_separator = new Separator (Orientation.VERTICAL);
        open_apps_separator.add_css_class ("dock-separator");
        open_apps_separator.margin_top = 8;
        open_apps_separator.margin_bottom = 8;

        open_apps_separator.set_visible (false);
        apps_box.append (open_apps_separator);
    }

    private void load_favorites () {
        var all_apps = AppInfo.get_all ();
        var fav_apps = new List<AppInfo> ();

        foreach (var app_info in all_apps) {
            if (!app_info.should_show ())
                continue;
            string app_id = app_info.get_id () != null? app_info.get_id () : app_info.get_name ();

            if (Favorites.get_default ().is_favorite (app_id))
                fav_apps.append (app_info);
        }

        fav_apps.sort ((a, b) => {
            string id1 = a.get_id () != null ? a.get_id () : a.get_name ();
            string id2 = b.get_id () != null ? b.get_id () : b.get_name ();
            return Favorites.get_default ().get_position (id1) - Favorites.get_default ().get_position (id2);
        });

        int count = 0;
        foreach (var app_info in fav_apps) {
            if (count >= Config.MAX_DOCK_ITEMS)
                break;

            var btn = new DockAppButton (app_info, true, this.launcher, this);
            apps_box.append (btn);

            string app_id = app_info.get_id () != null? app_info.get_id () : app_info.get_name ();

            active_app_buttons.insert (app_id, btn);
            count++;
        }
    }

    private AppInfo ? find_app_by_id (string search_id) {
        string s = search_id.down ();
        foreach (var app in AppInfo.get_all ()) {
            string id = app.get_id () != null? app.get_id ().down () : "";

            string name = app.get_name () != null? app.get_name ().down () : "";

            if (id == s || id == s + ".desktop" || id.has_prefix (s + ".") || name == s)
                return app;
        }
        return null;
    }

    private void update_windows_ui () {
        if (is_cleaned_up)return;
        var mgr = NiriWindowManager.get_default ();
        var windows_on_this_monitor = new HashTable<string, AppWindowList> (str_hash, str_equal);

        foreach (var win in mgr.windows) {
            if (this.monitor_connector != null && win.output != this.monitor_connector)
                continue;

            var app = find_app_by_id (win.app_id);
            if (app != null) {
                string final_id = app.get_id () != null? app.get_id () : app.get_name ();

                AppWindowList app_wins;
                if (windows_on_this_monitor.contains (final_id)) {
                    app_wins = windows_on_this_monitor.lookup (final_id);
                } else {
                    app_wins = new AppWindowList ();
                    windows_on_this_monitor.insert (final_id, app_wins);
                }

                NiriWindow[] temp_wins = app_wins.windows;
                temp_wins += win;
                app_wins.windows = temp_wins;
            }
        }

        var keys_to_remove = new List<string> ();
        bool has_extra = false;

        foreach (var key in active_app_buttons.get_keys ()) {
            var btn = active_app_buttons.get (key);
            if (windows_on_this_monitor.contains (key)) {
                var app_wins = windows_on_this_monitor.lookup (key);
                btn.open_windows = app_wins.windows;
                btn.set_windows (app_wins.windows.length);
                if (!btn.is_favorite)
                    has_extra = true;
            } else {
                btn.open_windows = new NiriWindow[0];
                btn.set_windows (0);
                if (!btn.is_favorite)
                    keys_to_remove.append (key);
            }
        }

        foreach (var key in keys_to_remove) {
            var btn = active_app_buttons.get (key);
            apps_box.remove (btn);
            active_app_buttons.remove (key);
        }

        foreach (var key in windows_on_this_monitor.get_keys ()) {
            if (!active_app_buttons.contains (key)) {
                AppInfo? app_to_add = null;
                foreach (var a in AppInfo.get_all ()) {
                    string id = a.get_id () != null? a.get_id () : a.get_name ();

                    if (id == key) {
                        app_to_add = a;
                        break;
                    }
                }

                if (app_to_add != null && app_to_add.should_show ()) {
                    var btn = new DockAppButton (app_to_add, false, this.launcher, this);
                    var app_wins = windows_on_this_monitor.lookup (key);
                    btn.open_windows = app_wins.windows;
                    btn.set_windows (btn.open_windows.length);

                    apps_box.append (btn);
                    active_app_buttons.insert (key, btn);
                    has_extra = true;
                }
            }
        }

        if (open_apps_separator != null)
            open_apps_separator.set_visible (has_extra);
    }
}