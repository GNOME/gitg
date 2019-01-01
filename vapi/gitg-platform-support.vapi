namespace Gitg
{
	[CCode(cprefix = "GitgPlatformSupport", lower_case_cprefix = "gitg_platform_support_", cheader_filename = "libgitg/gitg-platform-support.h")]
	public class PlatformSupport
	{
		public static bool use_native_window_controls(Gdk.Display? display = null);
		public static async GLib.InputStream http_get(GLib.File url, GLib.Cancellable? cancellable = null) throws GLib.IOError;

		public static Cairo.Surface create_cursor_surface(Gdk.Display? display,
		                                                  Gdk.CursorType cursor_type,
		                                                  out double hot_x = null,
		                                                  out double hot_y = null,
		                                                  out double width = null,
		                                                  out double height = null);

		public static GLib.InputStream new_input_stream_from_fd(int fd, bool close_fd);

		public static string get_lib_dir();
		public static string get_locale_dir();
		public static string get_data_dir();
		public static string? get_user_home_dir(string? user = null);
		public static void application_support_prepare_startup();
	}
}
