using Gtk;
using Adw;
using Gee;

const string APP_ID = "sur.deepivin.applaunch";

class AppLaunch : Adw.Application {
    private LauncherWindow? launcher_window = null;
    private ArrayList<DockWindow> active_docks = new ArrayList<DockWindow> ();
    private uint dock_timeout_id = 0;

    public AppLaunch () {
        Object (application_id : APP_ID);
    }

    // Reload the dock on all monitors
    public void reload_dock () {
        foreach (var dock in active_docks) {
            dock.cleanup ();
            dock.destroy ();
        }
        active_docks.clear ();

        var monitors = Gdk.Display.get_default ().get_monitors ();
        uint n_monitors = monitors.get_n_items ();

        for (uint i = 0; i < n_monitors; i++) {
            var monitor = monitors.get_item (i) as Gdk.Monitor;

            if (monitor == null)
                continue;

            var dock = new DockWindow (this, launcher_window, monitor);
            dock.present ();

            active_docks.add (dock);
        }
    }

    private void setup_dock () {
        var monitors = Gdk.Display.get_default ().get_monitors ();
        monitors.items_changed.connect ((pos, removed, added) => {
            stdout.printf ("Display configuration changed, reloading dock..\n");

            if (dock_timeout_id != 0)
                Source.remove (dock_timeout_id);

            dock_timeout_id = Timeout.add (500, () => {
                reload_dock ();
                dock_timeout_id = 0;
                return Source.REMOVE;
            });
        });

        Timeout.add (200, () => {
            reload_dock ();
            return Source.REMOVE;
        });
    }

    public override void activate () {
        var css_provider = new Gtk.CssProvider ();

        css_provider.load_from_string (Config.css_data);
        Gtk.StyleContext.add_provider_for_display (
                                                   Gdk.Display.get_default (),
                                                   css_provider,
                                                   Gtk.STYLE_PROVIDER_PRIORITY_USER
        );

        launcher_window = new LauncherWindow (this);

        if (Config.START_HIDDEN)
            launcher_window.set_visible (false);
        else
            launcher_window.present ();

        if (Config.DOCK_ENABLED)
            setup_dock ();

        var ipc = new IpcServer ();
        ipc.message_received.connect ((msg) => {
            switch (msg) {
                case "show":
                    launcher_window.present ();
                    break;
                case "hide":
                    launcher_window.set_visible (false);
                    break;
                case "toggle":
                    if (launcher_window.get_visible ())
                        launcher_window.set_visible (false);
                    else
                        launcher_window.present ();
                    break;
                case "reload dock":
                    reload_dock ();
                    break;
            }
        });
        ipc.start ();
    }

    public static int main (string[] args) {
        var app = new AppLaunch ();
        return app.run (args);
    }
}