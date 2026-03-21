using GLib;
using Json;

public class NiriWorkspaceJson : GLib.Object {
    public uint32 id { get; set; }
    public string? output { get; set; }
}

public class NiriWindowJson : GLib.Object {
    public uint32 id { get; set; }
    public string? title { get; set; }
    public string? app_id { get; set; }
    public uint32 workspace_id { get; set; }
}

public class NiriWindow : GLib.Object {
    public uint32 id;
    public string app_id;
    public string output;
    public string title;

    public NiriWindow (uint32 id, string app_id, string output, string title) {
        this.id = id;
        this.app_id = app_id;
        this.output = output;
        this.title = title;
    }
}

public class AppWindowList : GLib.Object {
    public NiriWindow[] windows = new NiriWindow[0];
}

public class NiriIpc : GLib.Object {
    private static NiriIpc? _instance = null;
    private string? socket_path;

    private NiriIpc () {
        socket_path = Environment.get_variable ("NIRI_SOCKET");
        if (socket_path == null)
            stderr.printf ("NIRI_SOCKET is not set\n");
    }

    public static NiriIpc get_default () {
        if (_instance == null)
            _instance = new NiriIpc ();
        return _instance;
    }

    private async string ? send_request_async (string request) {
        if (socket_path == null)
            return null;

        try {
            var client = new SocketClient ();
            var address = new UnixSocketAddress (socket_path);
            var connection = yield client.connect_async (address);

            var output = connection.get_output_stream ();
            size_t bytes_written;

            string payload = request + "\n";
            yield output.write_all_async (payload.data, Priority.DEFAULT, null, out bytes_written);

            var input = new DataInputStream (connection.get_input_stream ());
            size_t length;
            string? response = yield input.read_line_async (Priority.DEFAULT, null, out length);

            return response;
        } catch (Error e) {
            stderr.printf ("niri IPC error: %s\n", e.message);
            return null;
        }
    }

    public void action_focus_window (uint32 id) {
        send_request_async.begin ("{\"Action\":{\"FocusWindow\":{\"id\":" + id.to_string () + "}}}");
    }

    public void action_close_window (uint32 id) {
        send_request_async.begin ("{\"Action\":{\"CloseWindow\":{\"id\":" + id.to_string () + "}}}");
    }

    public void action_toggle_overview () {
        send_request_async.begin ("{\"Action\":{\"ToggleOverview\":{}}}");
    }

    private async Json.Node? request_json_node_async (string request) {
        string? response = yield send_request_async (request);

        if (response == null || response.strip () == "")
            return null;

        try {
            var parser = new Json.Parser ();
            parser.load_from_data (response, -1);
            unowned Json.Node root = parser.get_root ();

            if (root != null && root.get_node_type () == Json.NodeType.OBJECT) {
                unowned Json.Object obj = root.get_object ();
                if (obj.has_member ("Ok"))
                    return obj.get_member ("Ok").copy ();
                else if (obj.has_member ("Err"))
                    stderr.printf ("niri IPC returned error for %s: %s\n", request, response);
            }
        } catch (Error e) {
            stderr.printf ("JSON parsing error: %s\n", e.message);
        }
        return null;
    }

    public async Json.Node? request_windows_async () {
        var ok_node = yield request_json_node_async ("\"Windows\"");

        if (ok_node != null && ok_node.get_node_type () == Json.NodeType.OBJECT) {
            unowned Json.Object obj = ok_node.get_object ();
            if (obj.has_member ("Windows"))
                return obj.get_member ("Windows").copy ();
        }
        return null;
    }

    public async Json.Node? request_workspaces_async () {
        var ok_node = yield request_json_node_async ("\"Workspaces\"");

        if (ok_node != null && ok_node.get_node_type () == Json.NodeType.OBJECT) {
            unowned Json.Object obj = ok_node.get_object ();
            if (obj.has_member ("Workspaces"))
                return obj.get_member ("Workspaces").copy ();
        }
        return null;
    }

    public async void listen_event_stream (SourceFunc callback) {
        if (socket_path == null)
            return;

        try {
            var client = new SocketClient ();
            var address = new UnixSocketAddress (socket_path);
            var connection = yield client.connect_async (address);

            var output = connection.get_output_stream ();
            size_t bytes_written;
            yield output.write_all_async ("\"EventStream\"\n".data, Priority.DEFAULT, null, out bytes_written);

            var input = new DataInputStream (connection.get_input_stream ());
            while (true) {
                size_t length;
                string? response = yield input.read_line_async (Priority.DEFAULT, null, out length);

                if (response == null)break;

                Idle.add (() => {
                    callback ();
                    return Source.REMOVE;
                });
            }
        } catch (Error e) {
            stderr.printf ("niri event stream error: %s\n", e.message);
        }
    }
}

public class NiriWindowManager : GLib.Object {
    private static NiriWindowManager? _instance = null;
    private bool is_fetching = false;
    private bool needs_refetch = false;

    public signal void windows_changed ();

    public HashTable<string, string> ws_map;
    public List<NiriWindow> windows;

    private NiriWindowManager () {
        ws_map = new HashTable<string, string> (str_hash, str_equal);
        windows = new List<NiriWindow> ();

        fetch_data_async.begin ();

        NiriIpc.get_default ().listen_event_stream.begin (() => {
            if (!is_fetching)
                fetch_data_async.begin ();
            else
                needs_refetch = true;
            return Source.REMOVE;
        });
    }

    public static NiriWindowManager get_default () {
        if (_instance == null)
            _instance = new NiriWindowManager ();
        return _instance;
    }

    private async void fetch_data_async () {
        is_fetching = true;
        needs_refetch = false;

        var new_ws_map = yield get_workspace_outputs_async ();

        var new_windows = yield get_niri_windows_async (new_ws_map);

        this.ws_map = new_ws_map;
        this.windows = (owned) new_windows;

        windows_changed ();
        is_fetching = false;
        if (needs_refetch)
            fetch_data_async.begin ();
    }

    private async HashTable<string, string> get_workspace_outputs_async () {
        var map = new HashTable<string, string> (str_hash, str_equal);
        var array_node = yield NiriIpc.get_default ().request_workspaces_async ();

        if (array_node != null && array_node.get_node_type () == Json.NodeType.ARRAY) {
            unowned Json.Array array = array_node.get_array ();

            for (uint i = 0; i < array.get_length (); i++) {
                unowned Json.Node element = array.get_element (i);

                var ws_dto = Json.gobject_deserialize (typeof (NiriWorkspaceJson), element) as NiriWorkspaceJson;

                if (ws_dto != null && ws_dto.output != null)
                    map.insert (ws_dto.id.to_string (), ws_dto.output);
            }
        }
        return map;
    }

    private async List<NiriWindow> get_niri_windows_async (HashTable<string, string> ws_map) {
        var list = new List<NiriWindow> ();
        var array_node = yield NiriIpc.get_default ().request_windows_async ();

        if (array_node != null && array_node.get_node_type () == Json.NodeType.ARRAY) {
            unowned Json.Array array = array_node.get_array ();
            uint length = array.get_length ();

            for (uint i = 0; i < length; i++) {
                unowned Json.Node element = array.get_element (i);

                var win_dto = Json.gobject_deserialize (typeof (NiriWindowJson), element) as NiriWindowJson;

                if (win_dto != null && win_dto.app_id != null && win_dto.id != 0) {
                    string output = "";
                    string ws_id = win_dto.workspace_id.to_string ();

                    if (ws_map.contains (ws_id))
                        output = ws_map.lookup (ws_id);

                    string title = win_dto.title != null ? win_dto.title : "";

                    list.append (new NiriWindow ((uint32) win_dto.id, win_dto.app_id, output, title));
                }
            }
        }
        return list;
    }
}