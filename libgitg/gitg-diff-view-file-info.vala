class Gitg.DiffViewFileInfo : Object
{
	public Ggit.DiffDelta delta { get; construct set; }
	public bool from_workdir { get; construct set; }
	public Repository? repository { get; construct set; }

	public InputStream? new_file_input_stream { get; set; }
	public string? new_file_content_type { get; private set; }

	public DiffViewFileInfo(Repository? repository, Ggit.DiffDelta delta, bool from_workdir)
	{
		Object(repository: repository, delta: delta, from_workdir: from_workdir);
	}

	public async void query(Cancellable? cancellable)
	{
		yield query_content(cancellable);
	}

	private async void query_content(Cancellable? cancellable)
	{
		var file = delta.get_new_file();
		var id = file.get_oid();
		var path = file.get_path();

		if (repository == null || (id.is_zero() && !from_workdir) || (path == null && from_workdir))
		{
			return;
		}

		var workdir = repository.get_workdir();
		File location = workdir != null ? workdir.get_child(path) : null;

		if (!from_workdir)
		{
			Ggit.Blob blob;

			try
			{
				blob = repository.lookup<Ggit.Blob>(id);
			}
			catch (Error e)
			{
				return;
			}

			uint8[]? raw_content = blob.get_raw_content();
			if (TextConv.has_textconv_command(repository, file))
				raw_content = TextConv.get_textconv_content_from_raw(repository, file, raw_content);
			var bytes = new Bytes(raw_content);
			new_file_input_stream = new GLib.MemoryInputStream.from_bytes(bytes);
		}
		else if (location != null)
		{
			// Try to read from disk
			try
			{
				if (TextConv.has_textconv_command(repository, file))
				{
					uint8[]? content = null;
					yield location.load_contents_async(cancellable, out content, null);
					content = TextConv.get_textconv_content_from_raw(repository, file, content);
					var bytes = new Bytes(content);
					new_file_input_stream = new GLib.MemoryInputStream.from_bytes(bytes);
				}
				else
				{
					new_file_input_stream = yield location.read_async(Priority.DEFAULT, cancellable);
				}
			}
			catch
			{
				return;
			}
		}

		var seekable = new_file_input_stream as Seekable;

		if (seekable != null && seekable.can_seek())
		{
			// Read a little bit of content to guess the type
			yield guess_content_type(new_file_input_stream, location != null ? location.get_basename() : null, cancellable);

			try
			{
				seekable.seek(0, SeekType.SET, cancellable);
			}
			catch (Error e)
			{
				stderr.printf("Failed to seek back to beginning of stream...\n");
				new_file_input_stream = null;
			}
		}
	}

	private async void guess_content_type(InputStream stream, string basename, Cancellable? cancellable)
	{
		var buffer = new uint8[4096];
		size_t bytes_read = 0;

		try
		{
			yield stream.read_all_async(buffer, Priority.DEFAULT, cancellable, out bytes_read);
		}
		catch (Error e)
		{
			if (bytes_read <= 0)
			{
				return;
			}
		}

		buffer.length = (int)bytes_read;

		bool uncertain;
		new_file_content_type = GLib.ContentType.guess(basename, buffer, out uncertain);

	}
}
