using GLib;
using Gtk;

public class ShellProvider : Object, SearchProvider {
    public string name { get { return "Terminal"; } }

    public async List<SearchResult> ? search_async (string query, Cancellable cancellable) {
        if (!query.has_prefix ("$"))
            return null;

        string cmd = query.substring (1).strip ();

        if (cmd.length == 0)
            return null;

        var results = new List<SearchResult> ();
        var icon = new ThemedIcon ("utilities-terminal-symbolic");

        string display = "Run command: " + cmd;

        results.append (new SearchResult (cmd, display, icon, this));

        return results;
    }

    public void activate (SearchResult result) {
        try {
            var app_info = AppInfo.create_from_commandline (
                                                            result.id,
                                                            "Terminal Command",
                                                            AppInfoCreateFlags.NEEDS_TERMINAL
            );

            app_info.launch (null, new AppLaunchContext ());
        } catch (Error e) {
            stderr.printf ("Failed to launch command '%s' in terminal: %s\n", result.id, e.message);
        }
    }
}