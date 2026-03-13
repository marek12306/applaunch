using GLib;

public class IpcServer {
    Thread<void*> thread;

    public signal void message_received(string msg);

    private void * ipc_thread() {
        string socket_path = "/tmp/applaunch.sock";

        if (FileUtils.test(socket_path, FileTest.EXISTS))
            FileUtils.remove(socket_path);

        try {
            var socket = new Socket(SocketFamily.UNIX, SocketType.DATAGRAM, SocketProtocol.DEFAULT);
            var address = new GLib.UnixSocketAddress(socket_path);
            socket.bind(address, true);

            uint8 buffer[1024];
            while (true) {
                ssize_t size = socket.receive(buffer);
                if (size > 0) {
                    buffer[size] = 0; // EOF
                    string msg = ((string) buffer).strip();

                    Idle.add(() => {
                        message_received(msg);
                        return Source.REMOVE;
                    });
                }
            }
        } catch (Error e) {
            stderr.printf("IPC error: %s\n", e.message);
        }
        return null;
    }

    public void start() {
        thread = new Thread<void*> ("ipc-thread", ipc_thread);
    }
}