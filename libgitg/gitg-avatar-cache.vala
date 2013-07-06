/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

public class Gitg.AvatarCache : Object
{
	private Gee.HashMap<string, Gdk.Pixbuf?> d_cache;
	private static AvatarCache? s_instance;

	construct
	{
		d_cache = new Gee.HashMap<string, Gdk.Pixbuf>();
	}

	private AvatarCache()
	{
		Object();
	}

	public static AvatarCache @default()
	{
		if (s_instance == null)
		{
			s_instance = new AvatarCache();
		}

		return s_instance;
	}

	public async Gdk.Pixbuf? load(string email, Cancellable? cancellable = null)
	{
		var id = Checksum.compute_for_string(ChecksumType.MD5, email.down());

		if (d_cache.has_key(id))
		{
			return d_cache[id];
		}

		var gravatar = @"http://www.gravatar.com/avatar/$(id)?d=404&s=50";
		var gfile = File.new_for_uri(gravatar);

		var pixbuf = yield read_avatar_from_file(id, gfile, cancellable);

		if (pixbuf == null && (cancellable == null || !cancellable.is_cancelled()))
		{
			gravatar = @"http://robohash.org/$(id).png?size=50x50";
			gfile = File.new_for_uri(gravatar);

			pixbuf = yield read_avatar_from_file(id, gfile, cancellable);
		}

		d_cache[id] = pixbuf;
		return pixbuf;
	}

	private async Gdk.Pixbuf? read_avatar_from_file(string       id,
	                                                File         file,
	                                                Cancellable? cancellable)
	{
		InputStream stream;

		try
		{
			stream = yield file.read_async(Priority.LOW, cancellable);
		}
		catch
		{
			return null;
		}

		uint8[] buffer = new uint8[4096];
		var loader = new Gdk.PixbufLoader();

		loader.set_size(50, 50);

		return yield read_avatar(id, stream, buffer, loader, cancellable);
	}

	private async Gdk.Pixbuf? read_avatar(string           id,
	                                      InputStream      stream,
	                                      uint8[]          buffer,
	                                      Gdk.PixbufLoader loader,
	                                      Cancellable?     cancellable)
	{
		ssize_t n;

		try
		{
			n = yield stream.read_async(buffer, Priority.LOW, cancellable);
		}
		catch { return null; }

		if (n != 0)
		{
			try
			{
				loader.write(buffer[0:n]);
			}
			catch { return null; }

			return yield read_avatar(id, stream, buffer, loader, cancellable);
		}
		else
		{
			// Finished reading
			try
			{
				loader.close();
			} catch { return null; }

			return loader.get_pixbuf();
		}
	}
}

// ex: ts=4 noet
