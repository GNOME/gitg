[CCode (cprefix = "G", lower_case_cprefix = "g_")]
namespace GLib {
	[CCode (cheader_filename = "gio/gwin32inputstream.h")]
	public class Win32InputStream : GLib.InputStream {
		[CCode (has_construct_function = false, type = "GInputStream*")]
		public Win32InputStream (int handle, bool close_fd);
		public bool get_close_handle ();
		public void set_close_handle (bool close_fd);
		public bool close_handle { get; set; }
		public int handle { get; construct; }
	}
	[CCode (cheader_filename = "gio/gwin32outputstream.h")]
	public class Win32OutputStream : GLib.OutputStream {
		[CCode (has_construct_function = false, type = "GOutputStream*")]
		public Win32OutputStream (int handle, bool close_fd);
		public bool get_close_handle ();
		public void set_close_handle (bool close_fd);
		public bool close_handle { get; set; }
		public int handle { get; construct; }
	}
}
