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
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;

		public GitgExt.Application? application { owned get; construct set; }
		private List<Gitg.Ref> d_all;

		public signal void ref_activated(Gitg.Ref? r);

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
			d_all = new List<Gitg.Ref>();

			try
			{
				repo.references_foreach(Ggit.RefType.LISTALL, (nm) => {
					Gitg.Ref? r;

					try
					{
						r = repo.lookup_reference(nm);
					} catch { return 0; }

					d_all.prepend(r);

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

			d_all.reverse();

			Gitg.Ref? head = null;

			try
			{
				head = repo.lookup_reference("HEAD");

				if (head.get_reference_type() != Ggit.RefType.SYMBOLIC)
				{
					head = null;
				}
			} catch {}

			// Branches
			model.begin_header(_("Branches"), null);

			foreach (var item in branches)
			{
				var it = item;
				string? icon = null;
				bool isdef = false;

				if (head != null && item.get_name() == head.get_target())
				{
					icon = "object-select-symbolic";

					if (!CommandLine.all)
					{
						isdef = true;
					}
				}

				if (isdef)
				{
					model.append_default(item.parsed_name.shortname,
					                     icon,
					                     (nc) => ref_activated(it));
				}
				else
				{
					model.append(item.parsed_name.shortname,
					             icon,
					             (nc) => ref_activated(it));
				}
			}

			model.separator();

			if (CommandLine.all)
			{
				model.append_default(_("All"), null, (nc) => ref_activated(null));
			}
			else
			{
				model.append(_("All"), null, (nc) => ref_activated(null));
			}

			model.end_header();

			// Remotes
			model.begin_header(_("Remotes"), "network-server-symbolic");

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
			model.begin_header(_("Tags"), null);

			foreach (var item in tags)
			{
				var it = item;

				model.append(item.parsed_name.shortname,
				             null,
				             (nc) => ref_activated(it));
			}
		}

		public List<Gitg.Ref> all
		{
			get { return d_all; }
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
