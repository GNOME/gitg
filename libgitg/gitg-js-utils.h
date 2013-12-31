#ifndef __GITG_JS_UTILS_H__
#define __GITG_JS_UTILS_H__

#include <webkit2/webkit2.h>

gchar    *gitg_js_utils_get_json (WebKitJavascriptResult *js_result);
gboolean  gitg_js_utils_check    (WebKitJavascriptResult *js_result);

#endif /* __GITG_JS_UTILS_H__ */

