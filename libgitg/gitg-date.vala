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

namespace Gitg
{

public errordomain DateError
{
	INVALID_FORMAT
}

public class Date : Object, Initable
{
	private static Regex s_rfc2822;
	private static Regex s_iso8601;
	private static Regex s_internal;

	private static string?[] s_months = new string?[] {
		null,
		"Jan",
		"Feb",
		"Mar",
		"Apr",
		"May",
		"Jun",
		"Jul",
		"Aug",
		"Sep",
		"Oct",
		"Nov",
		"Dec"
	};

	static construct
	{
		try
		{

		s_iso8601 = new Regex(@"^
			(?<year>[0-9]{4})
			(?:
				[-.]?(?:
					(?<month>[0-9]{2})
					(?:
						[-.]?(?<day>[0-9]{2})
					)?
				|
					W(?<week>[0-9]{2})
					(?:
						[-.]?(?<weekday>[0-9])
					)?
				)
				(?:
					[T ](?<hour>[0-9]{2})
					(?:
						:?
						(?<minute>[0-9]{2})
						(?:
							:?
							(?<seconds>[0-9]{2})
							(?<tz>
								(?<tzutc>Z) |
								[+-](?<tzhour>[0-9]{2})
								(?:
									:?
									(?<tzminute>[0-9]{2})
								)?
							)?
						)?
					)?
				)?
			)?
		$$", RegexCompileFlags.EXTENDED);

		s_rfc2822 = new Regex(@"^
			(?:
				[\\s]*(?<dayofweek>Mon|Tue|Wed|Thu|Fri|Sat|Sun)
				,
			)?
			[\\s]*(?<day>[0-9]{1,2})
			[\\s]+
				(?<month>Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)
			[\\s]+
				(?<year>[0-9]{4})
			[\\s]+
				(?<hour>[0-9]{2})
				:
				(?<minute>[0-9]{2})
				(?:
					:
					(?<seconds>[0-9]{2})
				)?
			[\\s]+
			(?<tz>
				[+-]
				(?<tzhour>[0-9]{2})
				(?<tzminute>[0-9]{2})
			)
		$$", RegexCompileFlags.EXTENDED);

		s_internal = new Regex(@"^
			@?
			(?<timestamp>[0-9]+)
			[ ](?<tz>
				[+-](?<tzhour>[0-9]{2})
				(?:
					:?
					(?<tzminute>[0-9]{2})?
				)
			)
		$$", RegexCompileFlags.EXTENDED);

		}
		catch (Error e)
		{
			warning(@"Failed to compile date regex: $(e.message)");
		}
	}

	private static bool fetch_and_set_int(MatchInfo info, string name, ref int retval)
	{
		string? val = info.fetch_named(name);

		if (val == null)
		{
			return false;
		}

		retval = int.parse(val);
		return true;
	}

	private static bool fetch_and_set_double(MatchInfo info, string name, ref double retval)
	{
		string? val = info.fetch_named(name);

		if (val == null)
		{
			return false;
		}

		retval = double.parse(val);
		return true;
	}

	private static DateTime parse_internal(MatchInfo info) throws Error
	{
		string? timestamp = info.fetch_named("timestamp");
		int64 unixt = int64.parse(timestamp);

		string? tzs = info.fetch_named("tz");

		if (tzs != null)
		{
			var ret = new DateTime.from_unix_utc(unixt);
			return ret.to_timezone(new TimeZone(tzs));
		}
		else
		{
			return new DateTime.from_unix_local(unixt);
		}
	}

	private static DateTime parse_iso8601(MatchInfo info) throws Error
	{
		TimeZone tz = new TimeZone.utc();

		int year = 0;
		int month = 1;
		int day = 1;
		int hour = 0;
		int minute = 0;
		double seconds = 0.0;

		fetch_and_set_int(info, "year", ref year);
		fetch_and_set_int(info, "month", ref month);
		fetch_and_set_int(info, "day", ref day);
		fetch_and_set_int(info, "hour", ref hour);
		fetch_and_set_int(info, "minute", ref minute);
		fetch_and_set_double(info, "seconds", ref seconds);

		string? tzs = info.fetch_named("tz");

		if (tzs != null)
		{
			tz = new TimeZone(tzs);
		}
		else
		{
			tz = new TimeZone.local();
		}

		return new DateTime(tz, year, month, day, hour, minute, seconds);
	}

	private static DateTime parse_rfc2822(MatchInfo info) throws Error
	{
		TimeZone tz;
		int year = 0;
		int month = 0;
		int day = 1;
		int hour = 0;
		int minute = 0;
		double seconds = 0;

		fetch_and_set_int(info, "year", ref year);

		string? monthstr = info.fetch_named("month");

		for (int i = 0; i < s_months.length; ++i)
		{
			if (s_months[i] != null && s_months[i] == monthstr)
			{
				month = i;
				break;
			}
		}

		if (month == 0)
		{
			throw new DateError.INVALID_FORMAT("Invalid month specified");
		}

		fetch_and_set_int(info, "day", ref day);
		fetch_and_set_int(info, "hour", ref hour);
		fetch_and_set_int(info, "minute", ref minute);
		fetch_and_set_double(info, "seconds", ref seconds);

		string? tzs = info.fetch_named("tz");

		if (tzs != null)
		{
			tz = new TimeZone(tzs);
		}
		else
		{
			tz = new TimeZone.local();
		}

		return new DateTime(tz, year, month, day, hour, minute, seconds);
	}

	private DateTime d_datetime;

	public string date_string
	{
		get; construct set;
	}

	public DateTime date
	{
		get { return d_datetime; }
	}

	public bool init(Cancellable? cancellable = null) throws Error
	{
		MatchInfo info;

		if (s_internal.match(date_string, 0, out info))
		{
			d_datetime = parse_internal(info);

			return true;
		}

		if (s_iso8601.match(date_string, 0, out info))
		{
			d_datetime = parse_iso8601(info);

			return true;
		}

		if (s_rfc2822.match(date_string, 0, out info))
		{
			d_datetime = parse_rfc2822(info);

			return true;
		}

		throw new DateError.INVALID_FORMAT("Invalid date format");
	}

	public Date(string date) throws Error
	{
		Object(date_string: date);
		((Initable)this).init(null);
	}

	public string for_display()
	{
		var dt = d_datetime;
		TimeSpan t = (new DateTime.now_local()).difference(dt);

		if (t < TimeSpan.MINUTE * 29.5)
		{
			int rounded_minutes = (int) Math.round((float) t / TimeSpan.MINUTE);

			if (rounded_minutes == 0)
			{
				return _("Now");
			}
			else
			{
				return ngettext("A minute ago", "%d minutes ago", rounded_minutes).printf(rounded_minutes);
			}
		}
		else if (t < TimeSpan.MINUTE * 45)
		{
			return _("Half an hour ago");
		}
		else if (t < TimeSpan.HOUR * 23.5)
		{
			int rounded_hours = (int) Math.round((float) t / TimeSpan.HOUR);
			return ngettext("An hour ago", "%d hours ago", rounded_hours).printf(rounded_hours);
		}
		else if (t < TimeSpan.DAY * 7)
		{
			int rounded_days = (int) Math.round((float) t / TimeSpan.DAY);
			return ngettext("A day ago", "%d days ago", rounded_days).printf(rounded_days);
		}
		// FIXME: Localize these date formats, Bug 699196
		else if (dt.get_year() == new DateTime.now_local().get_year())
		{
			return dt.format("%h %e, %I:%M %P");
		}
		return dt.format("%h %e %Y, %I:%M %P");
	}

	public Date.for_date_time(DateTime dt)
	{
		d_datetime = dt;
	}

	public static DateTime parse(string date) throws Error
	{
		return (new Date(date)).date;
	}
}

}

// ex: ts=4 noet
