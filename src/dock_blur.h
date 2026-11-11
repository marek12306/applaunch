#pragma once

#include <gtk/gtk.h>

cairo_region_t *dock_blur_region(const GdkRectangle *bounds, int radius);
void dock_blur_update(GtkNative *native, GtkWidget *dock, int radius, gboolean visible);
