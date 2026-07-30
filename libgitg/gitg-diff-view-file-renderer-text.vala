/*
 * This file is part of gitg
 *
 * Copyright (C) 2016 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-file-renderer-text.ui")]
class Gitg.DiffViewFileRendererText : Gtk.SourceView, DiffSelectable, DiffViewFileRenderer, DiffViewFileRendererTextable
{
	private enum RegionType
	{
		ADDED,
		REMOVED,
		CONTEXT
	}

	public enum Style
	{
		ONE,
		OLD,
		NEW
	}

	private struct Region
	{
		public RegionType type;
		public int buffer_line_start;
		public int source_line_start;
		public int length;
	}

	public struct FoldRegion
	{
		public int buffer_line_start;
		public int buffer_line_end;
		public bool folded;
	}

	public uint added { get; set; }
	public uint removed { get; set; }

	private int64 d_doffset;

	private Gee.HashMap<int, PatchSet.Patch?> d_lines;

	private DiffViewFileSelectable d_selectable;
	private DiffViewLinesRenderer d_old_lines;
	private DiffViewLinesRenderer d_new_lines;
	private DiffViewLinesRenderer d_sym_lines;

	private bool d_highlight;

	private Cancellable? d_higlight_cancellable;
	private Gtk.SourceBuffer? d_old_highlight_buffer;
	private Gtk.SourceBuffer? d_new_highlight_buffer;
	private bool d_old_highlight_ready;
	private bool d_new_highlight_ready;

	private Region[] d_regions;
	private bool d_constructed;

	private FoldRegion[] d_fold_regions;
	private Gtk.TextTag? d_folded_tag;

	private Settings? d_stylesettings;

	private FontManager d_font_manager;
	private bool d_has_selection;

	public Style d_style { get; construct set; }

	public bool new_is_workdir { get; construct set; }

	public bool wrap_lines
	{
		get { return this.wrap_mode != Gtk.WrapMode.NONE; }
		set
		{
			if (value)
			{
				this.wrap_mode = Gtk.WrapMode.WORD_CHAR;
			}
			else
			{
				this.wrap_mode = Gtk.WrapMode.NONE;
			}
		}
	}

	public new int tab_width
	{
		get { return (int)get_tab_width(); }
		set { set_tab_width((uint)value); }
	}

	public int maxlines { get; set; }
	public bool show_full_file { get; set; }
	private int d_visible_context = 3;
	public int visible_context
	{
		get { return d_visible_context; }
		set
		{
			if (d_visible_context != value)
			{
				d_visible_context = value;
				if (show_full_file && d_fold_regions.length > 0)
				{
					reapply_folds();
				}
			}
		}
	}

	public DiffViewFileInfo info { get; construct set; }

	public Ggit.DiffDelta? delta
	{
		get { return info.delta; }
	}

	public Repository? repository
	{
		get { return info.repository; }
	}

	public bool highlight
	{
		get { return d_highlight; }

		construct set
		{
			if (d_highlight != value)
			{
				d_highlight = value;
				update_highlight();
			}
		}
	}

	public void clear_selection()
	{
		d_has_selection = false;
	}

	public bool has_selection
	{
		get { return d_has_selection; }
	}

	public bool can_select { get; construct set; }

	public PatchSet selection
	{
		owned get
		{
			var ret = new PatchSet();

			ret.filename = delta.get_new_file().get_path();

			var patches = new PatchSet.Patch[0];

			if (!can_select)
			{
				return ret;
			}

			var selected = d_selectable.get_selected_lines();

			for (var i = 0; i < selected.length; i++)
			{
				var line = selected[i];
				var pset = d_lines[line];

				if (i == 0)
				{
					patches += pset;
					continue;
				}

				var last = patches[patches.length - 1];

				if (last.new_offset + last.length == pset.new_offset &&
				    last.type == pset.type)
				{
					last.length += pset.length;
					patches[patches.length - 1] = last;
				}
				else
				{
					patches += pset;
				}
			}

			ret.patches = patches;
			return ret;
		}
	}

	public DiffViewFileRendererText(DiffViewFileInfo info, bool can_select, Style style)
	{
		Object(info: info, can_select: can_select, d_style: style);
		Hdy.StyleManager.get_default ().notify["dark"].connect (() => {
			Gitg.Utils.update_style_by_theme(d_stylesettings);
		});
	}

	construct
	{
		var gutter = this.get_gutter(Gtk.TextWindowType.LEFT);

		if (d_style == Style.ONE)
		{
			d_old_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.OLD);
			d_new_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.NEW);
			d_sym_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.SYMBOL);

			this.bind_property("maxlines", d_old_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
			this.bind_property("maxlines", d_new_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

			d_old_lines.xpad = 8;
			d_new_lines.xpad = 8;
			d_sym_lines.xpad = 6;

			gutter.insert(d_old_lines, 0);
			gutter.insert(d_new_lines, 1);
			gutter.insert(d_sym_lines, 2);

			d_old_lines.fold_toggled.connect(toggle_fold);
			d_new_lines.fold_toggled.connect(toggle_fold);
			d_sym_lines.fold_toggled.connect(toggle_fold);
		}
		else if (d_style == Style.OLD)
		{
			d_old_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.OLD);
			d_sym_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.SYMBOL_OLD);

			this.bind_property("maxlines", d_old_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

			d_old_lines.xpad = 8;
			d_sym_lines.xpad = 6;

			gutter.insert(d_old_lines, 0);
			gutter.insert(d_sym_lines, 1);

			d_old_lines.fold_toggled.connect(toggle_fold);
			d_sym_lines.fold_toggled.connect(toggle_fold);
		}
		else if (d_style == Style.NEW)
		{
			d_new_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.NEW);
			d_sym_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.SYMBOL_NEW);

			this.bind_property("maxlines", d_new_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

			d_new_lines.xpad = 8;
			d_sym_lines.xpad = 6;

			gutter.insert(d_new_lines, 0);
			gutter.insert(d_sym_lines, 1);

			d_new_lines.fold_toggled.connect(toggle_fold);
			d_sym_lines.fold_toggled.connect(toggle_fold);
		}

		this.set_border_window_size(Gtk.TextWindowType.TOP, 1);

		var settings = Gtk.Settings.get_default();
		settings.notify["gtk-application-prefer-dark-theme"].connect(update_theme);

		d_font_manager = new FontManager(this, true);

		update_theme();

		if (can_select)
		{
			d_selectable = new DiffViewFileSelectable(this);

			d_selectable.notify["has-selection"].connect(() => {
				d_has_selection = d_selectable.has_selection;
				notify_property("has-selection");
			});
		}

		d_lines = new Gee.HashMap<int, PatchSet.Patch?>();

		highlight = true;
	}

	public signal void fold_changed(int fold_index, bool folded);

	protected override void dispose()
	{
		base.dispose();

		if (d_higlight_cancellable != null)
		{
			d_higlight_cancellable.cancel();
			d_higlight_cancellable = null;
		}
	}

	private void update_highlight()
	{
		if (!d_constructed)
		{
			return;
		}

		if (d_higlight_cancellable != null)
		{
			d_higlight_cancellable.cancel();
			d_higlight_cancellable = null;
		}

		d_old_highlight_buffer = null;
		d_new_highlight_buffer = null;

		d_old_highlight_ready = false;
		d_new_highlight_ready = false;

		if (highlight && repository != null && delta != null)
		{
			var cancellable = new Cancellable();
			d_higlight_cancellable = cancellable;

			init_highlighting_buffer_old.begin(cancellable, (obj, res) => {
				init_highlighting_buffer_old.end(res);
			});

			init_highlighting_buffer_new.begin(cancellable, (obj, res) => {
				init_highlighting_buffer_new.end(res);
			});
		}
		else
		{
			update_highlighting_ready();
		}
	}

	private async void init_highlighting_buffer_old(Cancellable cancellable)
	{
		var buffer = yield init_highlighting_buffer(delta.get_old_file(), false, cancellable);

		if (!cancellable.is_cancelled())
		{
			d_old_highlight_buffer = buffer;
			d_old_highlight_ready = true;

			update_highlighting_ready();
		}
	}

	private File? get_file_location(Ggit.DiffFile file)
	{
		var path = file.get_path();

		if (path == null)
		{
			return null;
		}

		var workdir = repository.get_workdir();

		if (workdir == null)
		{
			return null;
		}

		return workdir.get_child(path);
	}

	private async void init_highlighting_buffer_new(Cancellable cancellable)
	{
		Gtk.SourceBuffer? buffer;

		var file = delta.get_new_file();

		if (info.new_file_input_stream != null)
		{
			// Use once
			var stream = info.new_file_input_stream;
			info.new_file_input_stream = null;

			buffer = yield init_highlighting_buffer_from_stream(delta.get_new_file(),
			                                                    get_file_location(file),
			                                                    stream,
			                                                    info.new_file_content_type,
			                                                    cancellable);
		}
		else
		{
			buffer = yield init_highlighting_buffer(delta.get_new_file(), info.from_workdir, cancellable);
		}

		if (!cancellable.is_cancelled())
		{
			d_new_highlight_buffer = buffer;
			d_new_highlight_ready = true;

			update_highlighting_ready();
		}
	}

	private async Gtk.SourceBuffer? init_highlighting_buffer(Ggit.DiffFile file, bool from_workdir, Cancellable cancellable)
	{
		var id = file.get_oid();
		var location = get_file_location(file);

		if ((id.is_zero() && !from_workdir) || (location == null && from_workdir))
		{
			return null;
		}

		uint8[] content;

		if (!from_workdir)
		{
			Ggit.Blob blob;

			try
			{
				blob = repository.lookup<Ggit.Blob>(id);
			}
			catch
			{
				return null;
			}

			if (TextConv.has_textconv_command(repository, file))
				content = TextConv.get_textconv_content(repository, file);
			else
				content = blob.get_raw_content();
		}
		else
		{
			// Try to read from disk
			try
			{
				// Read it all into a buffer so we can guess the content type from
				// it. This isn't really nice, but it's simple.
				yield location.load_contents_async(cancellable, out content, null);
				if (TextConv.has_textconv_command(repository, file))
					content = TextConv.get_textconv_content_from_raw(repository, file, content);
			}
			catch
			{
				return null;
			}
		}

		bool uncertain;
		var content_type = GLib.ContentType.guess(location.get_basename(), content, out uncertain);

		var stream = new GLib.MemoryInputStream.from_bytes(new Bytes(content));

		return yield init_highlighting_buffer_from_stream(file, location, stream, content_type, cancellable);
	}

	private async Gtk.SourceBuffer? init_highlighting_buffer_from_stream(Ggit.DiffFile file, File location, InputStream stream, string content_type, Cancellable cancellable)
	{
		var manager = Gtk.SourceLanguageManager.get_default();
		var language = manager.guess_language(location != null ? location.get_basename() : null, content_type);

		var buffer = new Gtk.SourceBuffer(this.buffer.tag_table);

		if (language != null)
		{
			buffer.language = language;
		}

		var style_scheme_manager = Gitg.Utils.get_source_style_manager();

		buffer.highlight_syntax = true;

		d_stylesettings = try_settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
		if (d_stylesettings != null)
		{
			d_stylesettings.changed["style-scheme"].connect(update_style);

			update_style();
		} else {
			buffer.style_scheme = style_scheme_manager.get_scheme("classic");
		}

		var sfile = new Gtk.SourceFile();
		sfile.location = location;

		var loader = new Gtk.SourceFileLoader.from_stream(buffer, sfile, stream);

		try
		{
			yield loader.load_async(GLib.Priority.LOW, cancellable, null);
			this.strip_carriage_returns(buffer);
		}
		catch (Error e)
		{
			if (!cancellable.is_cancelled())
			{
				stderr.printf(@"ERROR: failed to load $(file.get_path()) for highlighting: $(e.message)\n");
			}
		}

		return buffer;
	}

	private void update_style() {
		Gitg.Utils.update_buffer_style(d_stylesettings, (Gtk.SourceBuffer)buffer);
	}

	private Settings? try_settings(string schema_id)
	{
		var source = SettingsSchemaSource.get_default();

		if (source == null)
		{
			return null;
		}

		if (source.lookup(schema_id, true) != null)
		{
			return new Settings(schema_id);
		}

		return null;
	}

	private void strip_carriage_returns(Gtk.SourceBuffer buffer)
	{
		var search_settings = new Gtk.SourceSearchSettings();

		search_settings.regex_enabled = true;
		search_settings.search_text = "\\r";

		var search_context = new Gtk.SourceSearchContext(buffer, search_settings);

		try
		{
			search_context.replace_all("", 0);
		} catch (Error e) {}
	}

	private void update_highlighting_ready()
	{
		if (!d_old_highlight_ready && !d_new_highlight_ready)
		{
			// Remove highlights
			return;
		}
		else if (!d_old_highlight_ready || !d_new_highlight_ready)
		{
			// Both need to be loaded
			return;
		}

		var buffer = this.buffer;

		// Go over all the source chunks and match up to old/new buffer. Then,
		// apply the tags that are applied to the highlighted source buffers.
		foreach (var region in d_regions)
		{
			Gtk.SourceBuffer? source;

			if (region.type == RegionType.REMOVED)
			{
				source = d_old_highlight_buffer;
			}
			else
			{
				source = d_new_highlight_buffer;
			}

			if (source == null)
			{
				continue;
			}

			Gtk.TextIter buffer_iter, source_iter;

			buffer.get_iter_at_line(out buffer_iter, region.buffer_line_start);
			source.get_iter_at_line(out source_iter, region.source_line_start);

			var source_end_iter = source_iter;
			source_end_iter.forward_lines(region.length);

			source.ensure_highlight(source_iter, source_end_iter);

			var buffer_end_iter = buffer_iter;
			buffer_end_iter.forward_lines(region.length);

			var source_next_iter = source_iter;
			var tags = source_iter.get_tags();

			while (source_next_iter.forward_to_tag_toggle(null) && source_next_iter.compare(source_end_iter) < 0)
			{
				var buffer_next_iter = buffer_iter;
				buffer_next_iter.forward_chars(source_next_iter.get_offset() - source_iter.get_offset());

				foreach (var tag in tags)
				{
					buffer.apply_tag(tag, buffer_iter, buffer_next_iter);
				}

				source_iter = source_next_iter;
				buffer_iter = buffer_next_iter;

				tags = source_iter.get_tags();
			}

			foreach (var tag in tags)
			{
				buffer.apply_tag(tag, buffer_iter, buffer_end_iter);
			}
		}
	}

	protected override bool draw(Cairo.Context cr)
	{
		base.draw(cr);

		var win = this.get_window(Gtk.TextWindowType.LEFT);

		if (!Gtk.cairo_should_draw_window(cr, win))
		{
			return false;
		}

		var ctx = this.get_style_context();

		var old_lines_width = 0;
		var new_lines_width = 0;

		switch (d_style)
		{
		case Style.ONE:
			old_lines_width = d_old_lines.size + d_old_lines.xpad * 2;
			new_lines_width = d_new_lines.size + d_new_lines.xpad * 2;
			break;

		case Style.OLD:
			old_lines_width = d_old_lines.size + d_old_lines.xpad * 2;
			break;

		case Style.NEW:
			new_lines_width = d_new_lines.size + d_new_lines.xpad * 2;
			break;
		}

		var sym_lines_width = d_sym_lines.size + d_sym_lines.xpad * 2;

		if (d_style == Style.ONE)
		{
			ctx.save();
			Gtk.cairo_transform_to_window(cr, this, win);
			ctx.add_class("diff-lines-separator");
			ctx.render_frame(cr, 0, 0, old_lines_width, win.get_height());
			ctx.restore();
		}

		ctx.save();
		Gtk.cairo_transform_to_window(cr, this, win);
		ctx.add_class("diff-lines-gutter-border");
		ctx.render_frame(cr, old_lines_width + new_lines_width, 0, sym_lines_width, win.get_height());
		ctx.restore();

		return false;
	}

	private void update_theme()
	{
		var header_attributes = new Gtk.SourceMarkAttributes();
		var added_attributes = new Gtk.SourceMarkAttributes();
		var removed_attributes = new Gtk.SourceMarkAttributes();

		var dark = new Theme().is_theme_dark();

		if (dark)
		{
			header_attributes.background = Gdk.RGBA() { red = 88.0 / 255.0, green = 88.0 / 255.0, blue = 88.0 / 255.0, alpha = 1.0 };
			added_attributes.background = Gdk.RGBA() { red = 32.0 / 255.0, green = 68.0 / 255.0, blue = 21.0 / 255.0, alpha = 1.0 };
			removed_attributes.background = Gdk.RGBA() { red = 130.0 / 255.0, green = 55.0 / 255.0, blue = 53.0 / 255.0, alpha = 1.0 };
		}
		else
		{
			header_attributes.background = Gdk.RGBA() { red = 244.0 / 255.0, green = 247.0 / 255.0, blue = 251.0 / 255.0, alpha = 1.0 };
			added_attributes.background = Gdk.RGBA() { red = 220.0 / 255.0, green = 1.0, blue = 220.0 / 255.0, alpha = 1.0 };
			removed_attributes.background = Gdk.RGBA() { red = 1.0, green = 220.0 / 255.0, blue = 220.0 / 255.0, alpha = 1.0 };
		}

		this.set_mark_attributes("header", header_attributes, 0);
		this.set_mark_attributes("added", added_attributes, 0);
		this.set_mark_attributes("removed", removed_attributes, 0);
	}

	protected override void constructed()
	{
		base.constructed();

		d_constructed = true;
		update_highlight();
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		var buffer = this.buffer as Gtk.SourceBuffer;

		/* Diff hunk */
		var h = hunk.get_header();
		var pos = h.last_index_of("@@");

		if (pos >= 0)
		{
			h = h.substring(pos + 2).chug();
		}

		h = h.chomp();

		Gtk.TextIter iter;
		buffer.get_end_iter(out iter);

		if (!show_full_file)
		{
			if (!iter.is_start())
			{
				buffer.insert(ref iter, "\n", 1);
			}

			iter.set_line_offset(0);
			buffer.create_source_mark(null, "header", iter);

			var header = @"@@ -$(hunk.get_old_start()),$(hunk.get_old_lines()) +$(hunk.get_new_start()),$(hunk.get_new_lines()) @@ $h\n";
			buffer.insert(ref iter, header, -1);
		}

		int buffer_line = iter.get_line();

		int line_hunk_start = iter.get_line();

		var region = Region() {
			type = RegionType.CONTEXT,
			buffer_line_start = 0,
			source_line_start = 0,
			length = 0
		};

		this.freeze_notify();

		var add_line_num = 0;
		var remove_line_num = 0;
		var in_change_line = false;
		for (var i = 0; i < lines.size; i++)
		{
			var line = lines[i];
			var text = line.get_text().replace("\r", "");
			var added = false;
			var removed = false;
			var origin = line.get_origin();

			var rtype = RegionType.CONTEXT;

			switch (origin)
			{
				case Ggit.DiffLineType.ADDITION:
					added = true;
					this.added++;

					rtype = RegionType.ADDED;
					break;
				case Ggit.DiffLineType.DELETION:
					removed = true;
					this.removed++;

					rtype = RegionType.REMOVED;
					break;
				case Ggit.DiffLineType.CONTEXT_EOFNL:
				case Ggit.DiffLineType.ADD_EOFNL:
				case Ggit.DiffLineType.DEL_EOFNL:
					text = text.substring(1);
					break;
				case Ggit.DiffLineType.HUNK_HDR:
				case Ggit.DiffLineType.BINARY:
				case Ggit.DiffLineType.CONTEXT:
				case Ggit.DiffLineType.FILE_HDR:
					break;
			}

			if (i == 0 || rtype != region.type)
			{
				if (i != 0)
				{
					d_regions += region;
				}

				int source_line_start;

				if (rtype == RegionType.REMOVED)
				{
					source_line_start = line.get_old_lineno() - 1;
				}
				else
				{
					source_line_start = line.get_new_lineno() - 1;
				}

				region = Region() {
					type = rtype,
					buffer_line_start = buffer_line,
					source_line_start = source_line_start,
					length = 0
				};
			}

			if (d_style == Style.ONE)
				region.length++;

			if (added || removed)
			{
				var offset = (size_t)line.get_content_offset();
				var bytes = line.get_content();

				var pset = PatchSet.Patch() {
					type = added ? PatchSet.Type.ADD : PatchSet.Type.REMOVE,
					old_offset = offset,
					new_offset = offset,
					length = bytes.length
				};

				if (added)
				{
					pset.old_offset = (size_t)((int64)pset.old_offset - d_doffset);
				}
				else
				{
					pset.new_offset = (size_t)((int64)pset.new_offset + d_doffset);
				}

				d_lines[buffer_line] = pset;
				d_doffset += added ? (int64)bytes.length : -(int64)bytes.length;
			}

			if (i == lines.size - 1 && text.length > 0 && text[text.length - 1] == '\n')
			{
				text = text.slice(0, text.length - 1);
			}

			if (rtype == RegionType.CONTEXT)
			{
				if (d_style == Style.OLD || d_style == Style.NEW)
				{
					if (in_change_line == true)
					{
						bool check = d_style == Style.OLD ? add_line_num > remove_line_num : remove_line_num > add_line_num;
						if (check)
						{
							int end = d_style == Style.OLD ? add_line_num - remove_line_num : remove_line_num - add_line_num;
							for (var l = 0; l < end; l++)
							{
								Gtk.TextIter t_iter;
								buffer.get_end_iter(out t_iter);
								buffer.create_source_mark(null, "empty", t_iter);

								buffer.insert(ref iter, "\n", -1);
								buffer_line++;
								region.buffer_line_start = buffer_line;
							}
						}

						add_line_num = 0;
						remove_line_num = 0;
					}

					in_change_line = false;
				}

				buffer.insert(ref iter, text, -1);
				buffer_line++;
				if (d_style == Style.OLD || d_style == Style.NEW)
				{
					region.length++;
				}
			}

			RegionType? rtype_check = null;
			string mark = null;
			switch (d_style)
			{
			case Style.ONE:
			case Style.OLD:
				rtype_check = RegionType.REMOVED;
				mark = "removed";
				break;
			case Style.NEW:
				rtype_check = RegionType.ADDED;
				mark = "added";
				break;
			}

			if (rtype == rtype_check)
			{
				Gtk.TextIter t_iter;
				buffer.get_end_iter(out t_iter);
				buffer.create_source_mark(null, mark, t_iter);

				buffer.insert(ref iter, text, -1);
				buffer_line++;
				if (d_style == Style.OLD || d_style == Style.NEW)
				{
					region.length++;

					if (d_style == Style.OLD)
						remove_line_num++;
					else
						add_line_num++;
					in_change_line = true;
				}
			}

			switch (d_style)
			{
			case Style.ONE:
			case Style.OLD:
				rtype_check = RegionType.ADDED;
				break;
			case Style.NEW:
				rtype_check = RegionType.REMOVED;
				break;
			}
			if (rtype == rtype_check)
			{
				if (d_style == Style.OLD || d_style == Style.NEW)
				{
					if (d_style == Style.OLD)
						add_line_num++;
					else
						remove_line_num++;
					in_change_line = true;
				} else if (d_style == Style.ONE) {
					Gtk.TextIter t_iter;
					buffer.get_end_iter(out t_iter);
					buffer.create_source_mark(null, "added", t_iter);

					buffer.insert(ref iter, text, -1);
					buffer_line++;
				}
			}
		}

		if (lines.size != 0)
		{
			d_regions += region;
		}

		if (d_style == Style.ONE || d_style == Style.OLD)
		{
			d_old_lines.add_hunk(line_hunk_start, iter.get_line(), hunk, buffer);
		}
		if (d_style == Style.ONE || d_style == Style.NEW)
		{
			d_new_lines.add_hunk(line_hunk_start, iter.get_line(), hunk, buffer);
		}
		d_sym_lines.add_hunk(line_hunk_start, iter.get_line(), hunk, buffer);

		this.thaw_notify();

		sensitive = true;
	}

	public void finish_hunks()
	{
		if (show_full_file)
		{
			apply_folds();
		}
	}

	private void reapply_folds()
	{
		var buffer = this.buffer as Gtk.SourceBuffer;
		if (buffer == null) return;

		if (d_folded_tag != null)
		{
			Gtk.TextIter start, end;
			buffer.get_start_iter(out start);
			buffer.get_end_iter(out end);
			buffer.remove_tag(d_folded_tag, start, end);
		}

		apply_folds();
	}

	private void apply_folds()
	{
		var buffer = this.buffer as Gtk.SourceBuffer;

		if (d_folded_tag == null)
		{
			d_folded_tag = buffer.create_tag("folded");
			d_folded_tag.invisible = true;
		}

		d_fold_regions = {};

		var ctx = visible_context;

		var change_lines = new bool[buffer.get_line_count()];

		foreach (var region in d_regions)
		{
			if (region.type != RegionType.CONTEXT)
			{
				for (var i = 0; i < region.length; i++)
				{
					var line = region.buffer_line_start + i;
					if (line >= 0 && line < change_lines.length)
					{
						change_lines[line] = true;
					}
				}
			}
		}

		var near_change = new bool[change_lines.length];
		for (var i = 0; i < change_lines.length; i++)
		{
			if (change_lines[i])
			{
				for (var j = int.max(0, i - ctx); j <= int.min(change_lines.length - 1, i + ctx); j++)
				{
					near_change[j] = true;
				}
			}
		}

		int fold_start = -1;
		for (var i = 0; i < near_change.length; i++)
		{
			bool is_header = false;
			var marks = buffer.get_source_marks_at_line(i, "header");
			if (marks != null && marks.length() > 0)
			{
				is_header = true;
			}

			if (!near_change[i] && !is_header && !change_lines[i])
			{
				if (fold_start < 0)
				{
					fold_start = i;
				}
			}
			else
			{
				if (fold_start >= 0 && (i - fold_start) >= 2)
				{
					var fr = FoldRegion() {
						buffer_line_start = fold_start,
						buffer_line_end = i - 1,
						folded = true
					};
					d_fold_regions += fr;
					fold_tag_region(buffer, fold_start, i - 1);
				}
				fold_start = -1;
			}
		}

		if (fold_start >= 0 && (near_change.length - fold_start) >= 2)
		{
			var fr = FoldRegion() {
				buffer_line_start = fold_start,
				buffer_line_end = near_change.length - 1,
				folded = true
			};
			d_fold_regions += fr;
			fold_tag_region(buffer, fold_start, near_change.length - 1);
		}

		if (d_old_lines != null)
		{
			d_old_lines.fold_regions = d_fold_regions;
		}
		if (d_new_lines != null)
		{
			d_new_lines.fold_regions = d_fold_regions;
		}
		d_sym_lines.fold_regions = d_fold_regions;
	}

	private void fold_tag_region(Gtk.SourceBuffer buffer, int start_line, int end_line)
	{
		if (start_line + 1 > end_line)
		{
			return;
		}

		Gtk.TextIter start_iter;
		Gtk.TextIter end_iter;

		buffer.get_iter_at_line(out start_iter, start_line + 1);
		buffer.get_iter_at_line(out end_iter, end_line);
		end_iter.forward_to_line_end();

		buffer.apply_tag(d_folded_tag, start_iter, end_iter);
	}

	public void toggle_fold(int buffer_line)
	{
		for (var i = 0; i < d_fold_regions.length; i++)
		{
			if (buffer_line >= d_fold_regions[i].buffer_line_start && buffer_line <= d_fold_regions[i].buffer_line_end)
			{
				set_fold_state(i, !d_fold_regions[i].folded);
				fold_changed(i, d_fold_regions[i].folded);
				break;
			}
		}
	}

	public void set_fold_state(int fold_index, bool folded)
	{
		if (d_folded_tag == null || d_fold_regions == null)
		{
			return;
		}

		if (fold_index < 0 || fold_index >= d_fold_regions.length)
		{
			return;
		}

		var fr = d_fold_regions[fold_index];

		if (fr.folded == folded || fr.buffer_line_start + 1 > fr.buffer_line_end)
		{
			return;
		}

		var buffer = this.buffer as Gtk.SourceBuffer;
		Gtk.TextIter start_iter;
		Gtk.TextIter end_iter;

		buffer.get_iter_at_line(out start_iter, fr.buffer_line_start + 1);
		buffer.get_iter_at_line(out end_iter, fr.buffer_line_end);
		end_iter.forward_to_line_end();

		if (folded)
		{
			buffer.apply_tag(d_folded_tag, start_iter, end_iter);
		}
		else
		{
			buffer.remove_tag(d_folded_tag, start_iter, end_iter);
		}

		d_fold_regions[fold_index].folded = folded;
		update_gutter_fold_regions();
	}

	public void fold_all()
	{
		var buffer = this.buffer as Gtk.SourceBuffer;

		if (d_folded_tag == null || d_fold_regions == null)
		{
			return;
		}

		for (var i = 0; i < d_fold_regions.length; i++)
		{
			if (!d_fold_regions[i].folded && d_fold_regions[i].buffer_line_start + 1 <= d_fold_regions[i].buffer_line_end)
			{
				Gtk.TextIter start_iter;
				Gtk.TextIter end_iter;

				buffer.get_iter_at_line(out start_iter, d_fold_regions[i].buffer_line_start + 1);
				buffer.get_iter_at_line(out end_iter, d_fold_regions[i].buffer_line_end);
				end_iter.forward_to_line_end();

				buffer.apply_tag(d_folded_tag, start_iter, end_iter);
				d_fold_regions[i].folded = true;
			}
		}

		update_gutter_fold_regions();
	}

	public void unfold_all()
	{
		var buffer = this.buffer as Gtk.SourceBuffer;

		if (d_folded_tag == null || d_fold_regions == null)
		{
			return;
		}

		for (var i = 0; i < d_fold_regions.length; i++)
		{
			if (d_fold_regions[i].folded && d_fold_regions[i].buffer_line_start + 1 <= d_fold_regions[i].buffer_line_end)
			{
				Gtk.TextIter start_iter;
				Gtk.TextIter end_iter;

				buffer.get_iter_at_line(out start_iter, d_fold_regions[i].buffer_line_start + 1);
				buffer.get_iter_at_line(out end_iter, d_fold_regions[i].buffer_line_end);
				end_iter.forward_to_line_end();

				buffer.remove_tag(d_folded_tag, start_iter, end_iter);
				d_fold_regions[i].folded = false;
			}
		}

		update_gutter_fold_regions();
	}

	private void update_gutter_fold_regions()
	{
		if (d_old_lines != null)
		{
			d_old_lines.fold_regions = d_fold_regions;
		}
		if (d_new_lines != null)
		{
			d_new_lines.fold_regions = d_fold_regions;
		}
		d_sym_lines.fold_regions = d_fold_regions;
	}
}

// ex:ts=4 noet
