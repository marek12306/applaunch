using GLib;
using Gtk;

namespace Utils {
    public static void launch_detached(string command, string target) {
        try {
            string cmd = "setsid %s %s".printf(command, Shell.quote(target));
            Process.spawn_command_line_async(cmd);
        } catch (Error e) {
            warning("Could not launch command: %s", e.message);
        }
    }

    // Get the icon for a file, with a fallback to a default icon if it fails
    public static Icon get_icon_for_file(string path, string default_icon = "text-x-generic") {
        var file = File.new_for_path(path);
        Icon icon = new ThemedIcon(default_icon);
        try {
            var info = file.query_info("standard::icon", FileQueryInfoFlags.NONE, null);
            if (info.get_icon() != null)
                icon = info.get_icon();
        } catch (Error e) {
            warning("Could not get icon for file: %s", e.message);
        }
        return icon;
    }

    public static bool is_in_home_dir(string path) {
        return path.has_prefix(Environment.get_home_dir());
    }

    // Check if a widget is a child of another widget
    public static bool is_child_of(Widget? child, Widget? parent_to_find) {
        Widget? current = child;
        while (current != null) {
            if (current == parent_to_find)
                return true;
            current = current.get_parent();
        }
        return false;
    }

    // Check if a widget has a parent of a specific type
    public static bool has_parent_of_type(Widget? child, Type type_to_find) {
        Widget? current = child;
        while (current != null) {
            if (current.get_type().is_a(type_to_find))
                return true;
            current = current.get_parent();
        }
        return false;
    }

    public static bool fuzzy_subsequence_match(string text, string query) {
        if (query.length == 0)
            return true;
        if (text.length == 0)
            return false;

        int t_len = text.char_count();
        int q_len = query.char_count();
        if (q_len > t_len)
            return false;

        int q_idx = 0;

        for (int t_idx = 0; t_idx < t_len && q_idx < q_len; t_idx++) {
            unichar t_char = text.get_char(text.index_of_nth_char(t_idx));
            unichar q_char = query.get_char(query.index_of_nth_char(q_idx));

            if (t_char == q_char)
                q_idx++;
        }

        return q_idx == q_len;
    }
}