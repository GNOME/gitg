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

public enum RefType
{
	NONE,
	BRANCH,
	REMOTE,
	TAG,
	STASH
}

public enum RefState
{
	NONE,
	SELECTED,
	PRELIGHT
}

/**
 * Parse ref name into components.
 *
 * This class parses a refname and splits it into several components.
 *
 */
public class ParsedRefName : Object
{
	private string d_shortname;
	private string d_name;
	private string d_remote_name;
	private string d_remote_branch;
	private string? d_prefix;

	/**
	 * The type of ref.
	 */
	public RefType rtype { get; private set; }

	/**
	 * The full name of the ref.
	 */
	public string name
	{
		owned get { return d_name; }
	}

	/**
	 * The short name of the ref. This represents the name of the ref
	 * without the information of the type of ref.
	 */
	public string shortname
	{
		owned get { return d_shortname; }
	}

	/**
	 * The remote name of the ref (only for remote refs)
	 */
	public string? remote_name
	{
		owned get { return d_remote_name; }
	}

	/**
	 * The remote branch name of the ref (only for remote refs)
	 */
	public string? remote_branch
	{
		owned get { return d_remote_branch; }
	}

	public ParsedRefName(string name)
	{
		parse_name(name);
	}

	public string? prefix
	{
		get { return d_prefix; }
	}

	private void parse_name(string name)
	{
		d_name = name;

		string[] prefixes = {
			"refs/heads/",
			"refs/remotes/",
			"refs/tags/",
			"refs/stash"
		};

		d_shortname = name;
		d_prefix = null;

		if (d_name == "HEAD")
		{
			rtype = RefType.BRANCH;
		}

		for (var i = 0; i < prefixes.length; ++i)
		{
			if (!d_name.has_prefix(prefixes[i]))
			{
				continue;
			}

			d_prefix = prefixes[i];

			rtype = (RefType)(i + 1);

			if (rtype == RefType.STASH)
			{
				d_prefix = "refs/";
				d_shortname = "stash";
			}
			else
			{
				d_shortname = d_name[d_prefix.length:d_name.length];
			}

			if (rtype == RefType.REMOTE)
			{
				var pos = d_shortname.index_of_char('/');

				if (pos != -1)
				{
					d_remote_name = d_shortname.substring(0, pos);
					d_remote_branch = d_shortname.substring(pos + 1);
				}
				else
				{
					d_remote_name = d_shortname;
				}
			}
		}
	}
}

public interface Ref : Ggit.Ref
{
	private static Regex? s_remote_key_regex;

	protected abstract ParsedRefName d_parsed_name { get; set; }
	protected abstract List<Ref>? d_pushes { get; owned set; }

	public abstract RefState state { get; set; }
	public abstract bool working { get; set; }

	public ParsedRefName parsed_name
	{
		owned get
		{
			if (d_parsed_name == null)
			{
				d_parsed_name = new ParsedRefName(get_name());
			}

			return d_parsed_name;
		}
	}

	public abstract new Gitg.Repository get_owner();

	private void add_push_ref(string spec)
	{
		Gitg.Ref rf;

		try
		{
			rf = get_owner().lookup_reference(spec);
		} catch { return; }

		if (d_pushes.find_custom(rf, (a, b) => {
			return a.get_name().ascii_casecmp(b.get_name());
		}) == null)
		{
			d_pushes.append(rf);
		}
	}

	private void add_branch_configured_push(Ggit.Config cfg)
	{
		string remote;
		string merge;

		try
		{
			remote = cfg.get_string(@"branch.$(parsed_name.shortname).remote");
			merge = cfg.get_string(@"branch.$(parsed_name.shortname).merge");
		} catch { return; }

		var nm = new ParsedRefName(merge);

		add_push_ref(@"refs/remotes/$remote/$(nm.shortname)");
	}

	private void add_remote_configured_push(Ggit.Config cfg)
	{
		Regex valregex;

		try
		{
			valregex = new Regex("^%s:(.*)".printf(Regex.escape_string(get_name())));

			if (s_remote_key_regex == null)
			{
				s_remote_key_regex = new Regex("remote\\.(.*)\\.push");
			}

			cfg.match_foreach(s_remote_key_regex, (info, val) => {
				MatchInfo vinfo;

				if (!valregex.match(val, 0, out vinfo))
				{
					return 0;
				}

				var rname = info.fetch(1);
				var pref = vinfo.fetch(1);

				add_push_ref(@"refs/remotes/$rname/$pref");
				return 0;
			});

		} catch { return; }
	}

	private void add_branch_same_name_push(Ggit.Config cfg)
	{
		string remote;

		try
		{
			remote = cfg.get_string(@"branch.$(parsed_name.shortname).remote");
		} catch { return; }

		add_push_ref(@"refs/remotes/$remote/$(parsed_name.shortname)");
	}

	private void compose_pushes()
	{
		d_pushes = new List<Ref>();

		Ggit.Config cfg;

		try
		{
			cfg = get_owner().get_config();
		} catch { return; }

		/* The possible refspecs of a local $ref (branch) are resolved in the
		 * following order (duplicates are removed automatically):
		 *
		 * 1) Branch configured remote and merge (git push):
		 *
		 *    Remote: branch.<name>.remote
		 *    Spec:   branch.<name>.merge
		 *
		 * 2) Remote configured matching push refspec:
		 *    For each remote.<name>.push matching ${ref.name}:<spec>
		 *
		 *    Remote: <name>
		 *    Spec:   <spec>
		 *
		 * 3) Remote branch with the same name
		 *
		 *    Remote: branch.<name>.remote
		 *    Spec:   ${ref.name}
		 */

		// Branch configured remote and merge
		add_branch_configured_push(cfg);

		// Remote configured push spec
		add_remote_configured_push(cfg);

		// Same name push
		add_branch_same_name_push(cfg);
	}

	public List<Ref> pushes
	{
		get
		{
			if (d_pushes == null)
			{
				compose_pushes();
			}

			return d_pushes;
		}
	}
}

}

// ex:set ts=4 noet
