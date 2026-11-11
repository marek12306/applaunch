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
    gtk4_wayland,
    wayland_client,
    math,
]

sources = files(
    'search/calculator_provider.vala',
    'search/file_provider.vala',
    'search/flatpak_provider.vala',
    'search/shell_provider.vala',
    'search/system_provider.vala',
    'search/unicode_provider.vala',
    'niri_ipc.vala',
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

scanner = find_program('wayland-scanner')
blur_xml = wayland_protocols.get_variable(pkgconfig: 'pkgdatadir') / 'staging/ext-background-effect/ext-background-effect-v1.xml'
blur_header = custom_target('background-effect-header', input: blur_xml,
    output: 'ext-background-effect-v1-client-protocol.h',
    command: [scanner, 'client-header', '@INPUT@', '@OUTPUT@'])
blur_code = custom_target('background-effect-code', input: blur_xml,
    output: 'ext-background-effect-v1-protocol.c',
    command: [scanner, 'private-code', '@INPUT@', '@OUTPUT@'])

executable(
    meson.project_name(),
    sources, 'dock_blur.c', blur_header, blur_code,
    dependencies: dependencies,
    c_args: '-DGETTEXT_PACKAGE="applaunch"',
    install: true
)

fuzzy_test = executable('test-fuzzy', ['test_fuzzy.vala', 'utils.vala'],
    dependencies: [gtk4, gio])
test('fuzzy', fuzzy_test)

blur_test = executable('test-blur', ['test_blur.c', 'dock_blur.c', blur_header, blur_code],
    dependencies: [gtk4_wayland, wayland_client, math])
test('blur-region', blur_test)
