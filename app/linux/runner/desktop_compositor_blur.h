#ifndef RUNNER_DESKTOP_COMPOSITOR_BLUR_H_
#define RUNNER_DESKTOP_COMPOSITOR_BLUR_H_

#include <gtk/gtk.h>

// Request real-time background blur from the compositor (not Flutter).
//
// Wayland: ext-background-effect-v1 (full-surface blur region)
// X11:     _KDE_NET_WM_BLUR_BEHIND_REGION (KWin / compatible compositors)
//
// Flutter BackdropFilter cannot sample the desktop; only the compositor can.
// Safe to call multiple times (map / resize); Wayland effect object is reused.
void nextpili_request_compositor_blur(GtkWindow* window);

#endif  // RUNNER_DESKTOP_COMPOSITOR_BLUR_H_
