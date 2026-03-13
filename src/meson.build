dependencies = [
    glib,
    gobject,
    gtk4,
    libadwaita,
    gtk4_layer_shell,
    gio_unix,
    gio,
    appstream,
    json_glib,
    gee,
]

sources = files(
    'search/calculator_provider.vala',
    'search/file_provider.vala',
    'search/flatpak_provider.vala',
    'search/shell_provider.vala',
    'search/system_provider.vala',
    'search/unicode_provider.vala',
    'app_grid.vala',
    'config.vala',
    'dock.vala',
    'favorites.vala',
    'ipc.vala',
    'main.vala',
    'search_list.vala',
    'launcher.vala',
    'utils.vala',
)

executable(
    meson.project_name(),
    sources,
    dependencies: dependencies,
    c_args: '-DGETTEXT_PACKAGE="applaunch"',
)
