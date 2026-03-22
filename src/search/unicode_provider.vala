using GLib;
using Gtk;

public class UnicodeProvider : Object, SearchProvider {
    public string name { get { return "Unicode"; } }

    private struct UnicodeEntry {
        public string character;
        public string name_down;
        public string display_name;
        public string hex;
    }

    private class UnicodeMatch {
        public int index;
        public int score;
        public UnicodeMatch (int index, int score) {
            this.index = index;
            this.score = score;
        }
    }

    private UnicodeEntry[] db;
    private bool is_loaded = false;

    public UnicodeProvider () {
        db = new UnicodeEntry[0];

        new Thread<void*> ("unicode-loader", () => {
            load_database ();
            return null;
        });
    }

    private void load_database () {
        string local_path = Path.build_filename (Environment.get_home_dir (), ".local", "share", "unicode", "UnicodeData.txt");
        string path = local_path;

        if (!FileUtils.test (path, FileTest.EXISTS))
            path = "/usr/share/unicode/UnicodeData.txt";
        if (!FileUtils.test (path, FileTest.EXISTS))
            path = "/usr/share/unicode-data/UnicodeData.txt";

        if (FileUtils.test (path, FileTest.EXISTS)) {
            try {
                string content;
                FileUtils.get_contents (path, out content);
                string[] lines = content.split ("\n");

                var temp_db = new UnicodeEntry[lines.length];
                int count = 0;

                foreach (string line in lines) {
                    if (line.strip ().length == 0)
                        continue;

                    // HexCode;Name;General_Category;...
                    string[] parts = line.split (";");
                    if (parts.length >= 2) {
                        string hex = parts[0];
                        string name = parts[1];

                        // Ignore entries with names like "<control>" or "<reserved>"
                        if (name.has_prefix ("<") && name.has_suffix (">"))
                            continue;

                        uint64 code_point = 0;
                        unowned string unparsed;

                        if (uint64.try_parse (hex, out code_point, out unparsed, 16)) {
                            unichar uc = (unichar) code_point;
                            if (uc.validate ())
                                temp_db[count++] = {
                                    uc.to_string (),
                                    name.down (),
                                    name,
                                    hex
                                };
                        }
                    }
                }

                temp_db.resize (count);
                db = temp_db;
                is_loaded = true;
            } catch (Error e) {
                warning ("Error loading Unicode database: %s", e.message);
            }
        } else {
            warning ("UnicodeData.txt not found in standard locations. Unicode search will be unavailable.");
        }
    }

    public async List<SearchResult> ? search_async (string query, Cancellable cancellable) {
        if (!query.has_prefix ("!u "))
            return null;
        if (!is_loaded)
            return null;

        string term = query.substring (3).strip ().down ();
        if (term.length < 2)
            return null;

        SourceFunc callback = search_async.callback;
        List<SearchResult>? thread_results = null;

        new Thread<void*> ("unicode-search", () => {
            var local_results = new List<SearchResult> ();
            var icon = new ThemedIcon ("insert-text-symbolic");

            var matches = new List<UnicodeMatch> ();
            string[] search_terms = term.split (" ");

            for (int i = 0; i < db.length; i++) {
                if (cancellable.is_cancelled ())
                    break;

                bool matches_all = true;
                int total_score = 0;

                foreach (string t in search_terms) {
                    if (t.length == 0)
                        continue;

                    if (db[i].name_down.contains (t)) {
                        if (db[i].name_down.has_prefix (t))
                            // Prefix match gets 100 points
                            total_score += 100;
                        else
                            // Substring match gets 50 points
                            total_score += 50;
                    } else if (Utils.fuzzy_subsequence_match (db[i].name_down, t)) {
                        // Fuzzy match gets 10 points
                        total_score += 10;
                    } else {
                        matches_all = false;
                        break;
                    }
                }

                if (matches_all) {
                    total_score -= db[i].name_down.length;

                    if (db[i].hex.length >= 5)
                        total_score += 20;

                    matches.append (new UnicodeMatch (i, total_score));
                }
            }

            if (!cancellable.is_cancelled ()) {
                matches.sort ((a, b) => { return b.score - a.score; });

                int count = 0;
                foreach (var m in matches) {
                    if (count >= 50)
                        break;

                    int i = m.index;
                    string display = db[i].character + " (U+" + db[i].hex + ") - " + db[i].display_name;
                    local_results.append (new SearchResult (db[i].character, display, icon, this));
                    count++;
                }

                thread_results = (owned) local_results;
            }

            Idle.add ((owned) callback);
            return null;
        });

        yield;

        if (cancellable.is_cancelled ())
            return null;

        return (owned) thread_results;
    }

    public void activate (SearchResult result) {
        var clipboard = Gdk.Display.get_default ().get_clipboard ();
        clipboard.set_text (result.id);
    }
}