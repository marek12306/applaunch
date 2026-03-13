using GLib;
using Gtk;
using AppStream;

public class FlatpakProvider : Object, SearchProvider {
    public string name { get { return "Flatpak"; } }

    private AppStream.Pool? pool = null;
    private HashTable<string, List<SearchResult>> cache;

    public FlatpakProvider () {
        cache = new HashTable<string, List<SearchResult>> (str_hash, str_equal);

        new Thread<void*> ("appstream-loader", () => {
            var temp_pool = new AppStream.Pool ();
            try {
                temp_pool.load ();
                this.pool = temp_pool;
            } catch (Error e) {
                warning ("AppStream error: %s", e.message);
            }
            return null;
        });
    }

    private List<SearchResult> clone_list (List<SearchResult> original) {
        var clone = new List<SearchResult> ();
        foreach (var item in original) {
            clone.append (item);
        }
        return clone;
    }

    private GLib.Icon get_flatpak_icon (string app_id) {
        string[] cache_paths = {
            "/var/lib/flatpak/appstream/flathub/x86_64/active/icons/128x128/%s.png".printf (app_id),
            "/var/lib/flatpak/appstream/flathub/x86_64/active/icons/64x64/%s.png".printf (app_id),
            Path.build_filename (Environment.get_home_dir (), ".local/share/flatpak/appstream/flathub/x86_64/active/icons/128x128", "%s.png".printf (app_id)),
            Path.build_filename (Environment.get_home_dir (), ".local/share/flatpak/appstream/flathub/x86_64/active/icons/64x64", "%s.png".printf (app_id))
        };

        foreach (string path in cache_paths)
            if (FileUtils.test (path, FileTest.EXISTS))
                return new FileIcon (File.new_for_path (path));

        var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
        if (theme.has_icon (app_id))
            return new ThemedIcon (app_id);

        return new ThemedIcon ("system-software-install-symbolic");
    }

    public async List<SearchResult> ? search_async (string query, Cancellable cancellable) {
        if (!query.has_prefix ("!s "))
            return null;
        if (this.pool == null)
            return null;

        string search_term = query.substring (3).strip ();
        if (search_term.length < 3)
            return null;

        if (cache.contains (search_term))
            return clone_list (cache.get (search_term));

        SourceFunc callback = search_async.callback;
        List<SearchResult>? thread_results = null;

        new Thread<void*> ("appstream-search", () => {
            var local_results = new List<SearchResult> ();

            var components = this.pool.search (search_term);

            int count = 0;
            for (uint i = 0; i < components.get_size (); i++) {
                if (cancellable.is_cancelled ())break;
                if (count >= 10)break;

                var comp = components.index_safe (i);
                if (comp.get_kind () != AppStream.ComponentKind.DESKTOP_APP)continue;

                string app_id = comp.get_id ();
                if (app_id.has_suffix (".desktop")) {
                    app_id = app_id.substring (0, app_id.length - 8);
                }

                string app_name = comp.get_name ();
                var icon = get_flatpak_icon (app_id);

                local_results.append (new SearchResult (app_id, app_name, icon, this));
                count++;
            }

            thread_results = (owned) local_results;

            // Wake up the main thread to process results
            Idle.add ((owned) callback);
            return null;
        });

        yield;

        if (cancellable.is_cancelled ())
            return null;

        cache.insert (search_term, clone_list (thread_results));
        return (owned) thread_results;
    }

    public void activate (SearchResult result) {
        Utils.launch_detached ("xdg-open", "appstream://" + result.id);
    }
}