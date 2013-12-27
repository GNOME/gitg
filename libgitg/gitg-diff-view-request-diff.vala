/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
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
namespace Gitg
{
	class DiffViewRequestDiff : DiffViewRequest
	{
		private enum DiffType
		{
			DEFAULT,
			DIFF_ONLY,
			COMMIT_ONLY,
		}

		private DiffType d_diff_type;
		private Ggit.Diff? d_diff;
		private Ggit.Commit? d_commit;

		public DiffViewRequestDiff(DiffView? view, WebKit.URISchemeRequest request, Soup.URI uri)
		{
			base(view, request, uri);

			d_mimetype = "application/json";
			d_diff_type = DiffType.DEFAULT;

			if (has_view)
			{
				d_commit = d_view.commit;
				d_diff = d_view.diff;
			}

			var format = parameter("format");

			switch (format)
			{
				case "diff_only":
					d_diff_type = DiffType.DIFF_ONLY;
				break;
				case "commit_only":
					d_diff_type = DiffType.COMMIT_ONLY;
				break;
			}
		}

		private void file_to_json(Json.Builder builder, Ggit.DiffFile file)
		{
			builder.begin_object();
			{
				builder.set_member_name("path").add_string_value(file.get_path());
				builder.set_member_name("mode").add_int_value(file.get_mode());
				builder.set_member_name("size").add_int_value(file.get_size());
				builder.set_member_name("flags").add_int_value(file.get_flags());
			}
			builder.end_object();
		}

		private void range_to_json(Json.Builder builder, int start, int lines)
		{
			builder.begin_object();
			{
				builder.set_member_name("start").add_int_value(start);
				builder.set_member_name("lines").add_int_value(lines);
			}
			builder.end_object();
		}

		private class DiffState
		{
			public bool in_file;
			public bool in_hunk;
		}

		private void file_cb(Json.Builder   builder,
		                     DiffState      state,
		                     Ggit.DiffDelta delta,
		                     float          progress)
		{
			if (state.in_hunk)
			{
				builder.end_array();
				builder.end_object();

				state.in_hunk = false;
			}

			if (state.in_file)
			{
				builder.end_array();
				builder.end_object();

				state.in_file = false;
			}

			builder.begin_object();

			builder.set_member_name("file");

			builder.begin_object();
			{
				file_to_json(builder.set_member_name("old"), delta.get_old_file());
				file_to_json(builder.set_member_name("new"), delta.get_new_file());
			}
			builder.end_object();

			builder.set_member_name("status").add_int_value(delta.get_status());
			builder.set_member_name("similarity").add_int_value(delta.get_similarity());
			builder.set_member_name("binary").add_int_value((int64)((delta.get_flags() & Ggit.DiffFlag.BINARY) == 0));

			builder.set_member_name("hunks").begin_array();

			state.in_file = true;
		}

		private void hunk_cb(Json.Builder   builder,
		                     DiffState      state,
		                     Ggit.DiffDelta delta,
		                     Ggit.DiffHunk  hunk,
		                     string         header)
		{
			if (state.in_hunk)
			{
				builder.end_array();
				builder.end_object();

				state.in_hunk = false;
			}

			builder.begin_object();

			builder.set_member_name("range");

			builder.begin_object();
			{
				range_to_json(builder.set_member_name("old"),
				              hunk.get_old_start(),
				              hunk.get_old_lines());

				range_to_json(builder.set_member_name("new"),
				              hunk.get_new_start(),
				              hunk.get_new_lines());
			}
			builder.end_object();

			builder.set_member_name("header").add_string_value(header);
			builder.set_member_name("lines");

			builder.begin_array();

			state.in_hunk = true;
		}

		private void line_cb(Json.Builder   builder,
		                     Ggit.DiffDelta delta,
		                     Ggit.DiffHunk  hunk,
		                     Ggit.DiffLine  line)
		{
			builder.begin_object();
			{
				var content = line.get_content();

				builder.set_member_name("type").add_int_value((int64)line.get_origin());
				builder.set_member_name("content").add_string_value(line.get_text());
				builder.set_member_name("offset").add_int_value((int64)line.get_content_offset());
				builder.set_member_name("length").add_int_value((int64)content.length);
			}
			builder.end_object();
		}

		private void signature_to_json(Json.Builder builder, Ggit.Signature sig)
		{
			builder.begin_object();

			builder.set_member_name("name");
			builder.add_string_value(sig.get_name());

			builder.set_member_name("email");
			builder.add_string_value(sig.get_email());

			builder.set_member_name("email_md5");
			builder.add_string_value(Checksum.compute_for_string(ChecksumType.MD5, sig.get_email().down()));

			builder.set_member_name("time");
			builder.add_string_value(sig.get_time().to_timezone(sig.get_time_zone()).format("%x %X %z"));

			builder.end_object();
		}

		private void commit_to_json(Json.Builder builder, Ggit.Commit commit)
		{
			builder.begin_object();

			builder.set_member_name("id");
			builder.add_string_value(commit.get_id().to_string());

			builder.set_member_name("subject");
			builder.add_string_value(commit.get_subject());

			builder.set_member_name("message");
			builder.add_string_value(commit.get_message());

			builder.set_member_name("committer");
			signature_to_json(builder, commit.get_committer());

			builder.set_member_name("author");
			signature_to_json(builder, commit.get_author());

			builder.end_object();
		}

		private void build_diff(Ggit.Diff? diff, Json.Builder builder, Cancellable? cancellable) throws GLib.Error
		{
			DiffState state = new DiffState();

			builder.set_member_name("diff").begin_array();

			int64 numlines = 0;
			int64 maxlines = 0;

			diff.foreach(
				(delta, progress) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					file_cb(builder, state, delta, progress);
					return 0;
				},

				(delta, hunk) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					var maxold = hunk.get_old_start() + hunk.get_old_lines();
					var maxnew = hunk.get_new_start() + hunk.get_new_lines();

					var ml = int64.max(maxold, maxnew);

					if (ml > maxlines)
					{
						maxlines = ml;
					}

					var header = hunk.get_header();

					hunk_cb(builder, state, delta, hunk, header);
					return 0;
				},

				(delta, hunk, line) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					if ((delta.get_flags() & Ggit.DiffFlag.BINARY) == 0)
					{
						++numlines;

						line_cb(builder, delta, hunk, line);
					}

					return 0;
				}
			);

			if (cancellable != null && cancellable.is_cancelled())
			{
				throw new IOError.CANCELLED("Cancelled");
			}

			if (state.in_hunk)
			{
				builder.end_array();
				builder.end_object();
			}

			if (state.in_file)
			{
				builder.end_array();
				builder.end_object();
			}

			builder.end_array();
			builder.set_member_name("lines").add_int_value(numlines);
			builder.set_member_name("maxlines").add_int_value(maxlines);
		}

		private void build_commit(Ggit.Diff? diff, Json.Builder builder, Cancellable? cancellable)
		{
			builder.set_member_name("commit");
			commit_to_json(builder, d_commit);
		}

		private InputStream? run_diff(Ggit.Diff? diff, Cancellable? cancellable) throws GLib.Error
		{
			if (diff == null)
			{
				return null;
			}

			// create memory output stream
			var builder = new Json.Builder();

			builder.begin_object();

			if (d_commit != null && d_diff_type != DiffType.DIFF_ONLY)
			{
				build_commit(diff, builder, cancellable);
			}

			if (d_diff_type != DiffType.COMMIT_ONLY)
			{
				build_diff(diff, builder, cancellable);
			}

			builder.end_object();

			var gen = new Json.Generator();
			gen.set_root(builder.get_root());

			var stream = new MemoryOutputStream(null, realloc, free);
			gen.to_stream(stream, cancellable);

			if (cancellable != null && cancellable.is_cancelled())
			{
				throw new IOError.CANCELLED("Cancelled");
			}

			stream.close();

			uint8[] data = stream.steal_data();
			d_size = stream.get_data_size();

			data = data[0:d_size];

			return new MemoryInputStream.from_data(data, stream.destroy_function);
		}

		public override InputStream? run_async(Cancellable? cancellable) throws GLib.Error
		{
			if (!has_view)
			{
				throw new IOError.NOT_FOUND("Could not find diff view with corresponding id");
			}

			return run_diff(d_diff, cancellable);
		}
	}
}

// vi:ts=4
