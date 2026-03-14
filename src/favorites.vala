// Singleton for managing favorite apps
public class Favorites : Object {
    private static Favorites _instance;
    private string[] list = {};

    public signal void changed();

    private Favorites() {
        load_from_file();
    }

    public static Favorites get_default() {
        if (_instance == null)
            _instance = new Favorites();
        return _instance;
    }

    private void load_from_file() {
        list = {};
        string path = Path.build_filename(Environment.get_user_config_dir(), "applaunch", "favorites.txt");

        if (FileUtils.test(path, FileTest.EXISTS)) {
            try {
                string content;
                FileUtils.get_contents(path, out content);
                foreach (string line in content.split("\n")) {
                    string trimmed = line.strip();
                    if (trimmed.length > 0 && !is_favorite(trimmed))
                        list += trimmed;
                }
            } catch (Error e) {
                warning("Favorite loading error: %s", e.message);
            }
        }
    }

    public bool is_favorite(string app_id) {
        foreach (string item in list) {
            if (item == app_id)
                return true;
        }
        return false;
    }

    public int get_position(string app_id) {
        for (int i = 0; i < list.length; i++)
            if (list[i] == app_id)
                return i;
        return 999999;
    }

    public void toggle(string app_id) {
        if (is_favorite(app_id)) {
            string[] new_list = {};
            foreach (string item in list)
                if (item != app_id)
                    new_list += item;
            list = new_list;
        } else {
            list += app_id;
        }
        save_to_file();
        changed();
    }

    public void move_app(string dragged_id, string target_id, bool insert_after) {
        if (!is_favorite(dragged_id) || !is_favorite(target_id) || dragged_id == target_id)
            return;

        string[] temp_list = {};
        foreach (string item in list)
            if (item != dragged_id)
                temp_list += item;

        string[] final_list = {};
        foreach (string item in temp_list) {
            if (!insert_after && item == target_id)
                final_list += dragged_id;
            final_list += item;
            if (insert_after && item == target_id)
                final_list += dragged_id;
        }

        list = final_list;
        save_to_file();
        changed();
    }

    public void cleanup_uninstalled() {
        var apps = AppInfo.get_all();
        string[] valid_ids = {};

        foreach (var app in apps) {
            string id = app.get_id() != null? app.get_id() : app.get_name();

            valid_ids += id;
        }

        bool has_changes = false;
        string[] new_list = {};

        foreach (string fav in list) {
            bool found = false;
            foreach (string valid in valid_ids)
                if (fav == valid) {
                    found = true;
                    break;
                }
            if (found)
                new_list += fav;
            else
                has_changes = true;
        }

        if (has_changes) {
            list = new_list;
            save_to_file();
            changed();
        }
    }

    private void save_to_file() {
        string dir = Path.build_filename(Environment.get_user_config_dir(), "applaunch");
        if (!FileUtils.test(dir, FileTest.EXISTS))
            DirUtils.create_with_parents(dir, 0755);

        string path = Path.build_filename(dir, "favorites.txt");
        var builder = new StringBuilder();
        foreach (string key in list)
            builder.append(key).append("\n");

        try {
            FileUtils.set_contents(path, builder.str);
        } catch (Error e) {
            warning("Error saving favorites: %s", e.message);
        }
    }
}