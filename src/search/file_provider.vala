using GLib;

public class FileProvider : Object, SearchProvider {
    public string name { get { return "Files"; } }

    public async List<SearchResult> ? search_async (string query, Cancellable cancellable) {
        string text_no_ws = query.replace (" ", "").replace ("\t", "");
        if (text_no_ws.char_count () <= 2)
            return null;

        if (Environment.find_program_in_path ("plocate") == null)
            return null;

        var results = new List<SearchResult> ();
        try {
            var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE);
            string[] args = { "plocate", "-l", "1000", "-i", query.strip () };
            var subprocess = launcher.spawnv (args);

            string stdout_buf;
            yield subprocess.communicate_utf8_async (null, cancellable, out stdout_buf, null);

            if (cancellable.is_cancelled () || stdout_buf == null || stdout_buf.strip ().length == 0)
                return null;

            string[] lines = stdout_buf.strip ().split ("\n");
            string[] home_visible = {}, system_visible = {}, home_hidden = {}, system_hidden = {};
            bool search_for_hidden = query.has_prefix (".");

            foreach (string line in lines) {
                string path = line.strip ();
                if (path.length == 0)
                    continue;

                bool is_home = Utils.is_in_home_dir (path);
                bool is_hidden = path.contains ("/.") && !search_for_hidden;

                if (is_home && !is_hidden)
                    home_visible += path;
                else if (!is_home && !is_hidden)
                    system_visible += path;
                else if (is_home && is_hidden)
                    home_hidden += path;
                else 
                    system_hidden += path;
            }

            string[] final_results = {};
            foreach (string p in home_visible)
                final_results += p;
            foreach (string p in system_visible)
                final_results += p;
            foreach (string p in home_hidden)
                final_results += p;
            foreach (string p in system_hidden)
                final_results += p;

            int count = 0;
            foreach (string path in final_results) {
                if (count >= 20)
                    break;
                var icon = Utils.get_icon_for_file (path, "text-x-generic");
                results.append (new SearchResult (path, path, icon, this));
                count++;
            }
        } catch (Error e) {}

        return results;
    }

    public void activate (SearchResult result) {
        Utils.launch_detached ("xdg-open", result.id);
    }
}