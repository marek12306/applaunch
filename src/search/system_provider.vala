using GLib;
using Gtk;

class SystemAction {
    public string id;
    public string name;
    public string icon;
    public string command;

    public SystemAction (string id, string name, string icon, string command) {
        this.id = id;
        this.name = name;
        this.icon = icon;
        this.command = command;
    }
}

class SystemMatch {
    public SystemAction action;
    public int distance;

    public SystemMatch (SystemAction action, int distance) {
        this.action = action;
        this.distance = distance;
    }
}

public class SystemProvider : Object, SearchProvider {
    public string name { get { return "System Actions"; } }

    private SystemAction[] actions;

    public SystemProvider () {
        actions = new SystemAction[] {
            new SystemAction ("poweroff", "Turn off", "system-shutdown-symbolic", "systemctl poweroff"),
            new SystemAction ("reboot", "Restart", "system-reboot-symbolic", "systemctl reboot"),
            new SystemAction ("logout", "Logout", "system-log-out-symbolic", "logout"),
            new SystemAction ("reload dock", "Reload dock", "view-refresh-symbolic", "internal:reload_dock")
        };
    }

    public async List<SearchResult> ? search_async (string query, Cancellable cancellable) {
        var results = new List<SearchResult> ();

        string q = query.strip ().down ();
        if (q.length == 0)
            return results;

        var matches = new List<SystemMatch> ();

        foreach (var action in actions) {
            if (cancellable.is_cancelled ())
                return null;

            string id_down = action.id.down ();
            string name_down = action.name.down ();

            if (Utils.fuzzy_subsequence_match (id_down, q) || Utils.fuzzy_subsequence_match (name_down, q)) {
                var icon = new ThemedIcon (action.icon);
                results.append (new SearchResult (action.id, action.name, icon, this));
            }
        }

        matches.sort ((a, b) => {
            return a.distance - b.distance;
        });

        foreach (var match in matches) {
            var icon = new ThemedIcon (match.action.icon);
            results.append (new SearchResult (match.action.id, match.action.name, icon, this));
        }

        return results;
    }

    public void activate (SearchResult result) {
        try {
            SystemAction? selected_action = null;
            foreach (var action in actions)
                if (action.id == result.id) {
                    selected_action = action;
                    break;
                }

            if (selected_action != null)
                if (selected_action.command == "internal:reload_dock") {
                    var app = GLib.Application.get_default () as AppLaunch;
                    if (app != null)
                        app.reload_dock ();
                } else if (selected_action.command != "") {
                    Process.spawn_command_line_async (selected_action.command);
                }
        } catch (Error e) {
            warning ("Error activating result: %s", e.message);
        }
    }
}