using Gtk;
using GLib;

public class SearchResult : Object {
    public string id { get; set; }
    public string display_name { get; set; }
    public Icon icon { get; set; }
    public SearchProvider provider { get; set; }

    public SearchResult(string id, string display_name, Icon icon, SearchProvider provider) {
        this.id = id;
        this.display_name = display_name;
        this.icon = icon;
        this.provider = provider;
    }
}

public interface SearchProvider : Object {
    public abstract string name { get; }
    public abstract async List<SearchResult> ? search_async(string query, Cancellable cancellable);
    public abstract void activate(SearchResult result);
}

class SearchResultRow : ListBoxRow {
    public SearchResult result { get; private set; }

    public SearchResultRow(SearchResult result) {
        this.result = result;
        var box = new Box(Orientation.HORIZONTAL, 12);
        box.margin_top = 8;
        box.margin_bottom = 8;
        box.margin_start = 12;
        box.margin_end = 12;

        var image = new Image.from_gicon(result.icon);
        image.pixel_size = 32;
        box.append(image);

        var label = new Label(result.display_name);
        label.halign = Align.START;
        label.hexpand = true;
        label.ellipsize = Pango.EllipsizeMode.START;
        box.append(label);

        this.set_child(box);
    }
}

public class SearchList : Box {
    private ListBox listbox;
    private Separator separator;
    private Cancellable? search_cancellable = null;
    private bool apps_visible = true;

    private uint search_timeout_id = 0;

    private List<SearchProvider> providers;

    public signal void result_activated();

    public SearchList() {
        Object(orientation : Orientation.VERTICAL, spacing: 0);

        providers = new List<SearchProvider> ();

        providers = new List<SearchProvider> ();
        providers.append(new SystemProvider());
        providers.append(new CalculatorProvider());
        providers.append(new FlatpakProvider());
        providers.append(new FileProvider());
        providers.append(new ShellProvider());
        providers.append(new UnicodeProvider());

        separator = new Separator(Orientation.HORIZONTAL);
        separator.margin_top = 30;
        separator.margin_bottom = 30;
        separator.margin_start = 30;
        separator.margin_end = 30;
        separator.set_visible(false);
        this.append(separator);

        listbox = new ListBox();
        listbox.selection_mode = SelectionMode.SINGLE;
        listbox.set_visible(false);
        listbox.add_css_class("boxed-list");
        this.append(listbox);

        listbox.row_activated.connect((row) => {
            var search_row = row as SearchResultRow;
            if (search_row != null && search_row.result != null) {
                // Search result triggered
                search_row.result.provider.activate(search_row.result);
                result_activated();
            }
        });
    }

    public void clear() {
        if (search_timeout_id != 0) {
            Source.remove(search_timeout_id);
            search_timeout_id = 0;
        }

        if (search_cancellable != null) {
            search_cancellable.cancel();
            search_cancellable = null;
        }

        listbox.set_visible(false);
        separator.set_visible(false);

        Widget? child;
        while ((child = listbox.get_first_child()) != null)
            listbox.remove(child);
    }

    public void search(string query, bool apps_visible) {
        this.apps_visible = apps_visible;

        // Debouncing timer reset
        if (search_timeout_id != 0) {
            Source.remove(search_timeout_id);
            search_timeout_id = 0;
        }

        if (search_cancellable != null) {
            search_cancellable.cancel();
            search_cancellable = null;
        }

        var query_cleaned = query.strip().down();

        if (query_cleaned.length == 0) {
            clear();
            return;
        }

        // Set up a new timer for debouncing
        search_timeout_id = Timeout.add(100, () => {
            search_cancellable = new Cancellable();
            run_providers_async.begin(query_cleaned, search_cancellable);

            search_timeout_id = 0; // ID reset after timer callback is executed
            return Source.REMOVE; // Don't repeat the timer
        });
    }

    private async void run_providers_async(string query, Cancellable cancellable) {
        var all_results = new List<SearchResult> ();

        // Collect results from all providers
        foreach (var provider in providers) {
            if (cancellable.is_cancelled())
                return;
            var results = yield provider.search_async(query, cancellable);

            if (results != null)
                foreach (var res in results)
                    all_results.append(res);
        }

        if (cancellable.is_cancelled())
            return;

        // Clear previous results
        clear();

        // Populate listbox with new results
        ListBoxRow? first_row = null;
        foreach (var res in all_results) {
            var row = new SearchResultRow(res);
            listbox.append(row);
            if (first_row == null)
                first_row = row;
        }

        separator.set_visible(apps_visible);
        listbox.set_visible(true);

        // Auto-select the first result
        if (!apps_visible && first_row != null)
            listbox.select_row(first_row);
        else
            listbox.unselect_all();
    }

    public void launch_selected() {
        var row = listbox.get_selected_row();
        if (row != null)
            row.activate();
    }

    // Try to grab focus on the first result, return true if successful
    public bool grab_focus_first() {
        if (listbox.get_visible() && listbox.get_first_child() != null) {
            var first_row = listbox.get_first_child() as ListBoxRow;
            if (first_row != null) {
                first_row.grab_focus();
                listbox.select_row(first_row);
                return true;
            }
        }
        return false;
    }
}