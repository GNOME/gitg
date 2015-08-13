[CCode (cprefix = "Gitg", lower_case_prefix = "gitg_", cheader_filename = "gitg-assert.h")]
namespace Gitg.Test.Assert
{
	public static void assert_no_error(GLib.Error e);
	public static void assert_streq(string a, string b);
	public static void assert_inteq(int a, int b);
	public static void assert_booleq(bool a, bool b);
	public static void assert_uinteq(uint a, uint b);
	public static void assert_floateq(float a, float b);
	public static void assert_datetime(GLib.DateTime a, GLib.DateTime b);
}
