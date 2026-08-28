#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlView* view;
  FlMethodChannel* display_frame_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {

constexpr char kWindowDisplayFrameChannelName[] =
    "fly_narwhal/window_display_frame";
constexpr char kGetCurrentDisplayFrameMethod[] = "getCurrentDisplayFrame";
constexpr char kGetAllDisplaysMethod[] = "getAllDisplays";

GtkWindow* get_window(MyApplication* self) {
  if (self->view == nullptr) {
    return nullptr;
  }

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(self->view)));
}

FlValue* build_display_frame_value(MyApplication* self) {
  GtkWindow* window = get_window(self);
  if (window == nullptr) {
    return nullptr;
  }

  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == nullptr) {
    return nullptr;
  }

  GdkDisplay* display = gdk_window_get_display(gdk_window);
  GdkMonitor* monitor = gdk_display_get_monitor_at_window(display, gdk_window);
  if (monitor == nullptr) {
    monitor = gdk_display_get_primary_monitor(display);
  }
  if (monitor == nullptr) {
    return nullptr;
  }

  GdkRectangle geometry;
  gdk_monitor_get_geometry(monitor, &geometry);

  FlValue* frame = fl_value_new_map();
  fl_value_set_string_take(frame, "x", fl_value_new_float(geometry.x));
  fl_value_set_string_take(frame, "y", fl_value_new_float(geometry.y));
  fl_value_set_string_take(frame, "width", fl_value_new_float(geometry.width));
  fl_value_set_string_take(frame, "height",
                           fl_value_new_float(geometry.height));
  return frame;
}

static FlMethodResponse* get_current_display_frame(MyApplication* self) {
  g_autoptr(FlValue) result = build_display_frame_value(self);
  if (result == nullptr) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("display-frame-error",
                                     "Current display frame is unavailable.",
                                     nullptr));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlValue* build_rect_value(const GdkRectangle* rectangle) {
  FlValue* rect = fl_value_new_map();
  fl_value_set_string_take(rect, "x", fl_value_new_float(rectangle->x));
  fl_value_set_string_take(rect, "y", fl_value_new_float(rectangle->y));
  fl_value_set_string_take(rect, "width", fl_value_new_float(rectangle->width));
  fl_value_set_string_take(rect, "height",
                           fl_value_new_float(rectangle->height));
  return rect;
}

static FlMethodResponse* get_all_displays(MyApplication* self) {
  GdkDisplay* display = nullptr;
  GtkWindow* window = get_window(self);
  if (window != nullptr) {
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_window != nullptr) {
      display = gdk_window_get_display(gdk_window);
    }
  }
  if (display == nullptr) {
    display = gdk_display_get_default();
  }
  if (display == nullptr) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("display-enumeration-error",
                                     "No display is available.", nullptr));
  }

  g_autoptr(FlValue) displays = fl_value_new_list();
  const int monitor_count = gdk_display_get_n_monitors(display);
  for (int index = 0; index < monitor_count; index++) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, index);
    if (monitor == nullptr) {
      continue;
    }

    GdkRectangle geometry;
    gdk_monitor_get_geometry(monitor, &geometry);
    GdkRectangle workarea;
    gdk_monitor_get_workarea(monitor, &workarea);

    g_autofree gchar* id = g_strdup_printf("gdk-monitor-%d", index);
    FlValue* entry = fl_value_new_map();
    fl_value_set_string_take(entry, "id", fl_value_new_string(id));
    fl_value_set_string_take(entry, "monitorBounds",
                             build_rect_value(&geometry));
    fl_value_set_string_take(entry, "workArea", build_rect_value(&workarea));
    fl_value_set_string_take(entry, "isPrimary",
                             fl_value_new_bool(gdk_monitor_is_primary(monitor)));
    fl_value_set_string_take(
        entry, "scaleFactor",
        fl_value_new_float(
            static_cast<double>(gdk_monitor_get_scale_factor(monitor))));
    fl_value_append_take(displays, entry);
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(displays));
}

static void display_frame_method_call_cb(FlMethodChannel* channel,
                                         FlMethodCall* method_call,
                                         gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);

  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, kGetCurrentDisplayFrameMethod) == 0) {
    response = get_current_display_frame(self);
  } else if (strcmp(method, kGetAllDisplaysMethod) == 0) {
    response = get_all_displays(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

}  // namespace

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar so GTK takes ownership of the decorations (CSD).
  // Without it on Wayland, compositors such as KDE's KWin draw their own
  // server-side title bar, which ignores both gtk_window_set_decorated(FALSE)
  // and TitleBarStyle.hidden from window_manager. The header bar itself is
  // hidden by TitleBarStyle.hidden in app.dart before the window is shown.
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling; the
  // undecorated request is honored there.
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "fly_narwhal");
    // The app draws its own caption buttons (WindowCaption); never show the
    // GTK ones in case this bar becomes visible.
    gtk_header_bar_set_show_close_button(header_bar, FALSE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "fly_narwhal");
    gtk_window_set_decorated(window, FALSE);
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  self->view = view;
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  // Expose the full monitor frame so Dart can build non-exclusive fullscreen.
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->display_frame_channel =
      fl_method_channel_new(messenger, kWindowDisplayFrameChannelName,
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->display_frame_channel, display_frame_method_call_cb,
      g_object_ref(self), g_object_unref);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->display_frame_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->view = nullptr;
  self->display_frame_channel = nullptr;
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
