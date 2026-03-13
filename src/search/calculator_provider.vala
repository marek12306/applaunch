using GLib;

public class CalculatorProvider : Object, SearchProvider {
    public string name { get { return "Calculator"; } }

    public async List<SearchResult> ? search_async (string query, Cancellable cancellable) {
        if (!query.has_prefix ("!c "))
            return null;

        string expr = query.substring (3).strip ();
        if (expr.length == 0)
            return null;

        var results = new List<SearchResult> ();

        try {
            var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE | SubprocessFlags.STDIN_PIPE);
            string[] args = { "qalc", "-f", "-", "-t" };
            var subprocess = launcher.spawnv (args);

            string stdout_buf, stderr_buf;
            string stdin_buf = expr + "\n";
            yield subprocess.communicate_utf8_async (stdin_buf, cancellable, out stdout_buf, out stderr_buf);

            if (cancellable.is_cancelled ())return null;

            string result_text = "";
            if (stdout_buf != null && stdout_buf.strip ().length > 0) {
                string[] lines = stdout_buf.strip ().split ("\n");
                result_text = lines[lines.length - 1].strip ();
            } else if (stderr_buf != null && stderr_buf.strip ().length > 0) {
                string[] lines = stderr_buf.strip ().split ("\n");
                result_text = lines[lines.length - 1].strip ();
            }

            if (result_text.length > 0) {
                var icon = new ThemedIcon ("accessories-calculator-symbolic");
                results.append (new SearchResult (result_text, result_text, icon, this));
            }
        } catch (Error e) {}

        return results;
    }

    public void activate (SearchResult result) {
        var clipboard = Gdk.Display.get_default ().get_clipboard ();
        clipboard.set_text (result.id);
    }
}