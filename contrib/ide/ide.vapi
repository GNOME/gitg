// FIXME: in the future we might want to automatically generate this
[CCode (cprefix = "Ide", gir_namespace = "Ide", gir_version = "1.0", lower_case_cprefix = "ide_")]
namespace Ide {
	[CCode (cheader_filename = "ide.h", type_id = "ide_doap_get_type ()")]
	public class Doap : GLib.Object {
		[CCode (has_construct_function = false)]
		public Doap ();
		public unowned string get_bug_database ();
		public unowned string get_category ();
		public unowned string get_description ();
		public unowned string get_download_page ();
		public unowned string get_homepage ();
		[CCode (array_length = false, array_null_terminated = true)]
		public unowned string[] get_languages ();
		public unowned GLib.List<Ide.DoapPerson> get_maintainers ();
		public unowned string get_name ();
		public unowned string get_shortdesc ();
		public bool load_from_file (GLib.File file, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public bool load_from_data (string data, size_t length) throws GLib.Error;
		[NoAccessorMethod]
		public string bug_database { owned get; set; }
		[NoAccessorMethod]
		public string category { owned get; set; }
		[NoAccessorMethod]
		public string description { owned get; set; }
		[NoAccessorMethod]
		public string download_page { owned get; set; }
		[NoAccessorMethod]
		public string homepage { owned get; set; }
		[NoAccessorMethod]
		public string languages { owned get; set; }
		[NoAccessorMethod]
		public string name { owned get; set; }
		[NoAccessorMethod]
		public string shortdesc { owned get; set; }
	}
	[CCode (cheader_filename = "ide.h", type_id = "ide_doap_person_get_type ()")]
	public class DoapPerson : GLib.Object {
		[CCode (has_construct_function = false)]
		public DoapPerson ();
		public unowned string get_email ();
		public unowned string get_name ();
		public void set_email (string email);
		public void set_name (string name);
		public string email { get; set; }
		public string name { get; set; }
	}
}
