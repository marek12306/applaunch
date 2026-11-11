#include "dock_blur.h"
#include "ext-background-effect-v1-client-protocol.h"
#include <gdk/wayland/gdkwayland.h>
#include <math.h>
#include <string.h>

/* Cairo merges adjacent scanlines, keeping the Wayland region small. */
cairo_region_t *dock_blur_region(const GdkRectangle *bounds, int radius) {
    cairo_region_t *region = cairo_region_create();
    if (bounds->width <= 0 || bounds->height <= 0)
        return region;

    radius = CLAMP(radius, 0, MIN(bounds->width, bounds->height) / 2);
    cairo_rectangle_int_t row = { bounds->x, bounds->y + radius,
                                 bounds->width, bounds->height - 2 * radius };
    cairo_region_union_rectangle(region, &row);
    for (int y = 0; y < radius; y++) {
        double dy = radius - y - 0.5;
        int inset = (int)ceil(radius - sqrt(radius * radius - dy * dy));
        row = (cairo_rectangle_int_t){ bounds->x + inset, bounds->y + y,
                                      bounds->width - 2 * inset, 1 };
        cairo_region_union_rectangle(region, &row);
        row.y = bounds->y + bounds->height - y - 1;
        cairo_region_union_rectangle(region, &row);
    }
    return region;
}

typedef struct {
    struct ext_background_effect_manager_v1 *manager;
    struct ext_background_effect_surface_v1 *effect;
    GdkRectangle bounds;
    int radius;
    gboolean initialized;
} DockBlur;

static void capabilities(void *data, struct ext_background_effect_manager_v1 *manager,
                         uint32_t flags) {
    (void)data;
    (void)manager;
    (void)flags;
}

static void registry_global(void *data, struct wl_registry *registry, uint32_t name,
                            const char *interface, uint32_t version) {
    (void)version;
    DockBlur *blur = data;
    if (strcmp(interface, ext_background_effect_manager_v1_interface.name) == 0) {
        static const struct ext_background_effect_manager_v1_listener listener = { capabilities };
        blur->manager = wl_registry_bind(registry, name,
                                        &ext_background_effect_manager_v1_interface, 1);
        ext_background_effect_manager_v1_add_listener(blur->manager, &listener, NULL);
    }
}

static void registry_remove(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data;
    (void)registry;
    (void)name;
}

static void dock_blur_free(gpointer data) {
    DockBlur *blur = data;
    if (blur->effect)
        ext_background_effect_surface_v1_destroy(blur->effect);
    g_free(blur);
}

static DockBlur *dock_blur_get(GdkSurface *surface) {
    DockBlur *blur = g_object_get_data(G_OBJECT(surface), "applaunch-dock-blur");
    if (blur)
        return blur;

    blur = g_new0(DockBlur, 1);
    g_object_set_data_full(G_OBJECT(surface), "applaunch-dock-blur", blur, dock_blur_free);
    struct wl_display *display = gdk_wayland_display_get_wl_display(gdk_surface_get_display(surface));
    struct wl_event_queue *queue = wl_display_create_queue(display);
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_proxy_set_queue((struct wl_proxy *)registry, queue);
    static const struct wl_registry_listener listener = { registry_global, registry_remove };
    wl_registry_add_listener(registry, &listener, blur);

    /* Do not dispatch GTK's event queue while a widget is being snapshotted. */
    if (wl_display_roundtrip_queue(display, queue) >= 0 && blur->manager) {
        blur->effect = ext_background_effect_manager_v1_get_background_effect(
            blur->manager, gdk_wayland_surface_get_wl_surface(surface));
        wl_proxy_set_queue((struct wl_proxy *)blur->effect, NULL);
    }
    if (blur->manager) {
        ext_background_effect_manager_v1_destroy(blur->manager);
        blur->manager = NULL;
    }
    wl_registry_destroy(registry);
    wl_event_queue_destroy(queue);
    return blur;
}

void dock_blur_update(GtkNative *native, GtkWidget *dock, int radius, gboolean visible) {
    GdkSurface *surface = gtk_native_get_surface(native);
    if (!GDK_IS_WAYLAND_SURFACE(surface))
        return;
    DockBlur *blur = dock_blur_get(surface);
    if (!blur->effect)
        return; /* Background effects are optional on older compositors. */

    GdkRectangle bounds = { 0 };
    graphene_rect_t rect;
    if (visible && gtk_widget_compute_bounds(dock, GTK_WIDGET(native), &rect)) {
        double dx, dy;
        gtk_native_get_surface_transform(native, &dx, &dy);
        bounds.x = (int)floor(rect.origin.x - dx);
        bounds.y = (int)floor(rect.origin.y - dy);
        bounds.width = (int)ceil(rect.origin.x + rect.size.width - dx) - bounds.x;
        bounds.height = (int)ceil(rect.origin.y + rect.size.height - dy) - bounds.y;
    }
    if (blur->initialized && gdk_rectangle_equal(&bounds, &blur->bounds) && radius == blur->radius)
        return;
    blur->bounds = bounds;
    blur->radius = radius;
    blur->initialized = TRUE;

    cairo_region_t *region = dock_blur_region(&bounds, radius);
    struct wl_compositor *compositor = gdk_wayland_display_get_wl_compositor(gdk_surface_get_display(surface));
    struct wl_region *wl_region = wl_compositor_create_region(compositor);
    for (int i = 0; i < cairo_region_num_rectangles(region); i++) {
        cairo_rectangle_int_t part;
        cairo_region_get_rectangle(region, i, &part);
        wl_region_add(wl_region, part.x, part.y, part.width, part.height);
    }
    ext_background_effect_surface_v1_set_blur_region(blur->effect, wl_region);
    wl_region_destroy(wl_region);
    cairo_region_destroy(region);
    gdk_wayland_surface_force_next_commit(surface);
}
