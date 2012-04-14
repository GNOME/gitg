namespace Gitg
{

private const string version = Config.VERSION;

public class Main
{
	public static int main(string[] args)
	{
		Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.GITG_LOCALEDIR);
		Intl.textdomain(Config.GETTEXT_PACKAGE);

		Environment.set_prgname("gitg");
		Environment.set_application_name(_("gitg"));

		Gitg.init();

		Application app = new Application();
		return app.run(args);
	}
}

}

// ex:set ts=4 noet
