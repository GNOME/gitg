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

namespace GitgHistory
{
	private class Navigation : Object, GitgExt.Navigation
	{
		public GitgExt.Application? application { owned get; construct set; }

		public signal void ref_activated(Gitg.Ref r);

		public Navigation(GitgExt.Application app)
		{
			Object(application: app);
		}

		private static int sort_refs(Gitg.Ref a, Gitg.Ref b)
		{
			return a.parsed_name.shortname.ascii_casecmp(b.parsed_name.shortname);
		}

		public void populate(GitgExt.NavigationTreeModel model)
		{
			var repo = application.repository;

			List<Gitg.Ref> branches = new List<Gitg.Ref>();
			List<Gitg.Ref> tags = new List<Gitg.Ref>();

			HashTable<string, List<Gitg.Ref>> remotes;
			List<string> remotenames = new List<string>();

			remotes = new HashTable<string, List<Gitg.Ref>>(str_hash, str_equal);

			try
			{
				repo.references_foreach(Ggit.RefType.LISTALL, (nm) => {
					Gitg.Ref? r;

					try
					{
						r = repo.lookup_reference(nm);
					} catch { return 0; }

					if (r.parsed_name.rtype == Gitg.RefType.BRANCH)
					{
						branches.insert_sorted(r, sort_refs);
					}
					else if (r.parsed_name.rtype == Gitg.RefType.TAG)
					{
						tags.insert_sorted(r, sort_refs);
					}
					else if (r.parsed_name.rtype == Gitg.RefType.REMOTE)
					{
						unowned List<Gitg.Ref> lst;

						string rname = r.parsed_name.remote_name;

						if (!remotes.lookup_extended(rname, null, out lst))
						{
							List<Gitg.Ref> nlst = new List<Gitg.Ref>();
							nlst.prepend(r);

							remotes.insert(rname, (owned)nlst);
							remotenames.insert_sorted(rname, (a, b) => a.ascii_casecmp(b));
						}
						else
						{
							lst.prepend(r);
						}
					}

					return 0;
				});
			} catch {}

			Gitg.Ref? head = null;

			try
			{
				head = repo.get_head();
			} catch {}

			// Branches
			model.begin_header("Branches", null);

			foreach (var item in branches)
			{
				var it = item;

				if (head != null && item.get_id().equal(head.get_id()))
				{
					model.append_default(item.parsed_name.shortname,
					                     "object-select-symbolic",
					                     (nc) => ref_activated(it));
				}
				else
				{
					model.append(item.parsed_name.shortname,
					             null,
					             (nc) => ref_activated(it));
				}
			}

			model.end_header();

			// Remotes
			model.begin_header("Remotes", "network-server-symbolic");

			foreach (var rname in remotenames)
			{
				model.begin_header(rname, null);

				foreach (var rref in remotes.lookup(rname))
				{
					var it = rref;

					model.append(rref.parsed_name.remote_branch,
					             null,
					             (nc) => ref_activated(it));
				}

				model.end_header();
			}

			model.end_header();

			// Tags
			model.begin_header("Tags", null);

			foreach (var item in tags)
			{
				var it = item;

				model.append(item.parsed_name.shortname,
				             null,
				             (nc) => ref_activated(it));
			}
		}

		public GitgExt.NavigationSide navigation_side
		{
			get { return GitgExt.NavigationSide.LEFT; }
		}

		public bool available
		{
			get { return true; }
		}
	}
}

// ex: ts=4 noet
