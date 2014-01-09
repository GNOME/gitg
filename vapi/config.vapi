[CCode(cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
namespace Gitg.Config
{
	public const string GETTEXT_PACKAGE;
	public const string PACKAGE_NAME;
	public const string PACKAGE_VERSION;
	public const string PACKAGE_URL;
	public const string GITG_DATADIR;
	public const string GITG_LOCALEDIR;
	public const string GITG_LIBDIR;
	public const string VERSION;

	// temporary check for 3.11 to switch header bar buttons. This check can
	// be removed when we bump the gtk+ requirement to 3.12
	public const bool GTK_VERSION_AT_LEAST_3_11;
}

// ex:ts=4 noet
