namespace Gitg
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-add-remote-action-dialog.ui")]
class AddRemoteActionDialog : Gtk.Dialog
{
	[GtkChild]
	private Gtk.Button d_button_create;

	[GtkChild]
	private Gtk.Entry d_entry_remote_name;

	[GtkChild]
	private Gtk.Entry d_entry_remote_url;

	construct
	{
		d_entry_remote_name.changed.connect(() => {
			var is_name_valid = (d_entry_remote_name.text != "");

			d_entry_remote_url.changed.connect((e) => {
				var is_url_valid = (d_entry_remote_url.text != "");

				set_response_sensitive(Gtk.ResponseType.OK, is_name_valid && is_url_valid);
			});
		});

		set_default(d_button_create);
		set_default_response(Gtk.ResponseType.OK);
	}

	public AddRemoteActionDialog(Gtk.Window? parent)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
	}

	public string remote_name
	{
		owned get
		{
			return d_entry_remote_name.text.strip();
		}

		set
		{
		   d_entry_remote_name.text = value.strip();
		}
	}

	public string remote_url
	{
		owned get
		{
			return d_entry_remote_url.text.strip();
		}

		set
		{
		   d_entry_remote_url.text = value.strip();
		}
	}
}

}

// ex: ts=4 noet
