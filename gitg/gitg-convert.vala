/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

namespace Gitg.Convert
{
	private void utf8_validate_fallback(ref string text, ssize_t size)
	{
		char *end;

		while (!text.validate(size, out end))
		{
			*end = '?';
		}
	}

	private string convert_fallback(string text, ssize_t size, string fallback)
	{
		string res = "";
		size_t read;

		var str = new StringBuilder();

		while (true)
		{
			try
			{
				res = GLib.convert(text, size, "UTF-8", "ASCII", out read);
				break;
			}
			catch
			{
				try
				{
					str.append(GLib.convert(text, (ssize_t)read, "UTF-8", "ASCII"));
				} catch {}

				str.append(fallback);

				text = (string)((uint8[])text)[(read + 1):size];
				size -= (ssize_t)read;
			}
		}

		str.append(res);

		var retval = str.str;
		Convert.utf8_validate_fallback(ref retval, str.len);

		return retval;
	}

	private bool convert_and_check(string text, ssize_t size, string from_charset, out string? ret)
	{
		size_t read, written;

		ret = null;

		try
		{
			ret = GLib.convert(text, size, "UTF-8", from_charset, out read, out written);

			if (read == size)
			{
				Convert.utf8_validate_fallback(ref ret, (ssize_t)written);
				return true;
			}
		}
		catch {}

		return false;
	}


	public string utf8(string str, ssize_t size = -1, string? from_charset = null)
	{
		if (size == -1)
		{
			size = str.length;
		}

		if (from_charset == null)
		{
			if (str.validate(size))
			{
				return str[0:size];
			}
		}
		else
		{
			string ret;

			if (from_charset.ascii_casecmp("UTF-8") == 0)
			{
				ret = str[0:size];
				Convert.utf8_validate_fallback(ref ret, size);

				return ret;
			}

			if (Convert.convert_and_check(str, size, from_charset, out ret))
			{
				return ret;
			}
		}

		string locale_charset;

		if (!GLib.get_charset(out locale_charset))
		{
			string ret;

			if (Convert.convert_and_check(str, size, locale_charset, out ret))
			{
				return ret;
			}
		}

		return Convert.convert_fallback(str, size, "?");
	}
}

/* ex:set ts=4 noet: */
