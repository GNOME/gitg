#include "gitg-js-utils.h"

#include <JavaScriptCore/JavaScript.h>

gchar *
gitg_js_utils_get_json (WebKitJavascriptResult *js_result)
{
	JSValueRef value;
	JSStringRef json;
	size_t size;
	gchar *ret;

	value = webkit_javascript_result_get_value (js_result);

	json = JSValueCreateJSONString(webkit_javascript_result_get_global_context (js_result),
	                               value,
	                               0,
	                               NULL);

	size = JSStringGetMaximumUTF8CStringSize (json);
	ret = g_new0 (gchar, size);

	JSStringGetUTF8CString (json, ret, size);
	JSStringRelease (json);

	return ret;
}

gboolean
gitg_js_utils_check (WebKitJavascriptResult *js_result)
{
	JSValueRef value;

	value = webkit_javascript_result_get_value (js_result);

	return JSValueToBoolean (webkit_javascript_result_get_global_context (js_result),
	                         value);
}

