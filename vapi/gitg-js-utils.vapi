[CCode(cprefix = "GitgJsUtils", lower_case_cprefix = "gitg_js_utils_", cheader_filename = "libgitg/gitg-js-utils.h")]
namespace GitgJsUtils
{
	public string get_json(WebKit.JavascriptResult result);
	public bool check(WebKit.JavascriptResult result);
}
