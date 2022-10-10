
/*
 * This file is part of gitg
 *
 * Copyright (C) 2022 - Alberto Fanjul
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

using GPG;

namespace Gitg
{

public class GPGUtils
{
	public static string sign_commit_object(string commit_content,
	                                        string signing_key) throws Error
	{
		check_version();
		Data plain_data;
		Data signed_data;
		Data.create(out signed_data);
		Data.create_from_memory(out plain_data, commit_content.data, false);
		Context context;
		Context.Context(out context);
		context.set_armor(true);
		Key key;
		context.get_key(signing_key, out key, true);
		if (key != null)
			context.signers_add(key);
		context.op_sign(plain_data, signed_data, SigMode.DETACH);
		return get_string_from_data(signed_data);
	}

	private static string get_string_from_data(Data data) {
		data.seek(0);
		uint8[] buf = new uint8[256];
		ssize_t? len = null;
		string res = "";
		do {
			len = data.read(buf);
			if (len > 0) {
				string part = (string) buf;
				part = part.substring(0, (long) len);
				res += part;
			}
		} while (len > 0);
		return res;
	}
}
}
