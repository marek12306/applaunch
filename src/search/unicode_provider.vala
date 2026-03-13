using GLib;
using Gtk;

public class UnicodeProvider : Object, SearchProvider {
    public string name { get { return "Unicode"; } }

    private struct UnicodeEntry {
        public string character;
        public string name_down;
        public string display_name;
        public string hex; // DODANE: przechowujemy oryginalny kod HEX
    }

    private UnicodeEntry[] db;
    private bool is_loaded = false;

    public UnicodeProvider () {
        db = new UnicodeEntry[0];

        // Ładujemy plik z bazą Unicode w tle
        new Thread<void*> ("unicode-loader", () => {
            load_database ();
            return null;
        });
    }

    private void load_database () {
        // Budujemy ścieżkę do ~/.local/share/unicode/UnicodeData.txt
        string local_path = Path.build_filename (Environment.get_home_dir (), ".local", "share", "unicode", "UnicodeData.txt");
        string path = local_path;

        // Jeśli pliku nie ma w katalogu domowym, sprawdzamy ścieżki systemowe
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
                warning ("Błąd ładowania bazy Unicode: %s", e.message);
            }
        } else {
            warning ("Brak pliku UnicodeData.txt. Pobierz go i umieść w ~/.local/share/unicode/ lub zainstaluj pakiet systemowy.");
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
            int count = 0;

            string[] search_terms = term.split (" ");

            for (int i = 0; i < db.length; i++) {
                if (cancellable.is_cancelled ())
                    break;
                if (count >= 50)
                    break;

                bool matches_all = true;
                foreach (string t in search_terms) {
                    if (t.length > 0 && !db[i].name_down.contains (t)) {
                        matches_all = false;
                        break;
                    }
                }

                if (matches_all) {
                    string display = db[i].character + " (U+" + db[i].hex + ") - " + db[i].display_name;
                    local_results.append (new SearchResult (db[i].character, display, icon, this));
                    count++;
                }
            }

            thread_results = (owned) local_results;
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