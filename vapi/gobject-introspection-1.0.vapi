[CCode (cprefix = "GI", lower_case_cprefix = "g_i", cheader_filename = "girepository.h")]
namespace Introspection
{
	[CCode (cprefix = "G_IREPOSITORY_ERROR_")]
	public errordomain RepositoryError {
		TYPELIB_NOT_FOUND,
		NAMESPACE_MISMATCH,
		NAMESPACE_VERSION_CONFLICT,
		LIBRARY_NOT_FOUND
	}

	[CCode (cname="int", cprefix = "G_IREPOSITORY_LOAD_FLAG_")]
	public enum RepositoryLoadFlags {
		LAZY = 1
	}

	[CCode (ref_function = "", unref_function = "")]
	public class Repository {
		public static unowned Repository get_default();
		public static void prepend_search_path(string directory);
		public static unowned GLib.SList<string> get_search_path();

		public unowned Typelib? require(string namespace_, string? version = null, RepositoryLoadFlags flags = 0) throws RepositoryError;
	}

	[Compact]
	[CCode (cname = "GTypelib", cprefix = "g_typelib_", free_function = "g_typelib_free")]
	public class Typelib {
		public unowned string get_namespace();
	}
}
