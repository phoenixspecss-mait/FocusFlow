#ifndef FLUTTER_FocusFlowLICATION_H_
#define FLUTTER_FocusFlowLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication, FocusFlowlication, MY, APPLICATION,
                     GtkApplication)

/**
 * FocusFlowlication_new:
 *
 * Creates a new Flutter-based application.
 *
 * Returns: a new #MyApplication.
 */
MyApplication* FocusFlowlication_new();

#endif  // FLUTTER_FocusFlowLICATION_H_
