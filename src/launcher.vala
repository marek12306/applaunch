using Gtk;
using GtkLayerShell;

public class LauncherWindow : ApplicationWindow {
    private Entry? search_entry;
    private Box main_box;
    private Box vbox;
    private AppGrid app_grid;
    private SearchList search_list;

    public LauncherWindow (Gtk.Application app) {
        Object (application : app);

        this.title = "applaunch";
        this.hide_on_close = true;
        this.add_css_class ("fullscreen");
        this.decorated = false;

        GtkLayerShell.init_for_window (this);
        GtkLayerShell.set_namespace (this, "launcher");
        GtkLayerShell.set_layer (this, GtkLayerShell.Layer.OVERLAY);
        GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.EXCLUSIVE);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        GtkLayerShell.set_exclusive_zone (this, -1);

        main_box = new Box (Orientation.VERTICAL, 0);
        this.set_child (main_box);

        vbox = new Box (Orientation.VERTICAL, 0);
        vbox.margin_top = 80;
        vbox.margin_bottom = 80;
        vbox.margin_start = 180;
        vbox.margin_end = 180;
        vbox.hexpand = true;
        vbox.vexpand = true;
        main_box.append (vbox);

        search_entry = new Entry ();
        search_entry.placeholder_text = GLib.dgettext ("gtk40", "Search");
        search_entry.set_icon_from_icon_name (EntryIconPosition.PRIMARY, "system-search-symbolic");
        search_entry.halign = Align.CENTER;
        search_entry.set_size_request (400, -1);
        search_entry.margin_top = 10;
        search_entry.margin_bottom = 40;
        vbox.append (search_entry);

        var scrolled_window = new ScrolledWindow ();
        scrolled_window.hscrollbar_policy = PolicyType.NEVER;
        scrolled_window.vscrollbar_policy = Config.SCROLL_BARS ? PolicyType.AUTOMATIC : PolicyType.NEVER;
        scrolled_window.vexpand = true;
        vbox.append (scrolled_window);

        app_grid = new AppGrid ();
        search_list = new SearchList ();

        app_grid.app_launched.connect (() => this.set_visible (false));
        search_list.result_activated.connect (() => this.set_visible (false));

        var content_box = new Box (Orientation.VERTICAL, 0);
        content_box.valign = Align.START;
        content_box.append (app_grid);
        content_box.append (search_list);
        scrolled_window.set_child (content_box);

        search_entry.changed.connect (() => {
            string text = search_entry.text.down ();
            bool has_apps = app_grid.filter_apps (text);
            search_list.search (search_entry.text, has_apps);
        });

        search_entry.activate.connect (() => {
            bool app_launched = app_grid.launch_selected ();
            if (!app_launched)
                search_list.launch_selected ();
        });

        var entry_key_controller = new EventControllerKey ();
        entry_key_controller.set_propagation_phase (PropagationPhase.CAPTURE);
        entry_key_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Down || keyval == Gdk.Key.Up) {
                bool focused = app_grid.grab_focus_first ();

                if (!focused)
                    search_list.grab_focus_first ();

                return true;
            }
            return false;
        });
        search_entry.add_controller (entry_key_controller);

        var bg_click_controller = new GestureClick ();
        bg_click_controller.button = 0;
        bg_click_controller.released.connect ((n_press, x, y) => {
            if (x < vbox.margin_start || x > main_box.get_width () - vbox.margin_end ||
                y < vbox.margin_top || y > main_box.get_height () - vbox.margin_bottom) {
                this.set_visible (false);
            }
        });
        main_box.add_controller (bg_click_controller);

        var vbox_click_capture = new GestureClick ();
        vbox_click_capture.button = 0;
        vbox_click_capture.set_propagation_phase (PropagationPhase.CAPTURE);
        vbox_click_capture.pressed.connect ((n_press, x, y) => {
            Widget? picked = vbox.pick (x, y, Gtk.PickFlags.DEFAULT);
            if (!Utils.has_parent_of_type (picked, typeof (AppFlowBoxChild)))
                app_grid.unselect_all ();
        });
        vbox.add_controller (vbox_click_capture);

        var window_key_controller = new EventControllerKey ();
        window_key_controller.set_propagation_phase (PropagationPhase.CAPTURE);
        window_key_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Escape) {
                this.set_visible (false);
                return true;
            }

            bool is_search_focused = Utils.is_child_of (this.get_focus (), search_entry);

            if (search_entry != null && !is_search_focused) {
                if (keyval == Gdk.Key.BackSpace) {
                    search_entry.grab_focus ();

                    int len = search_entry.get_text_length ();
                    if (len > 0)
                        search_entry.delete_text (len - 1, len);
                    search_entry.set_position (-1);
                    return true;
                }

                uint32 unicode = Gdk.keyval_to_unicode (keyval);
                bool is_ctrl_alt = (state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK)) != 0;

                if (!is_ctrl_alt && (unicode >= 0x20 && unicode != 0x7F)) {
                    search_entry.grab_focus ();
                    search_entry.set_text (search_entry.get_text () + ((unichar) unicode).to_string ());
                    search_entry.set_position (-1);
                    return true;
                }
            }
            return false;
        });
        ((Gtk.Widget) this).add_controller (window_key_controller);

        this.notify["visible"].connect (() => {
            if (this.visible && search_entry != null) {
                search_entry.set_text ("");
                search_entry.grab_focus ();
            } else if (!this.visible) {
                app_grid.unselect_all ();
                search_list.clear ();
            }
        });
    }
}