var id = 1;

// Extract query parameters
var params = function(query) {
	var search = /([^&=]+)=?([^&]*)/g,
	    pl = /\+/g,
	    decode = function (s) { return decodeURIComponent(s.replace(pl, " ")); },
	    ret = {};

	while (match = search.exec(query))
	{
		ret[decode(match[1])] = decode(match[2]);
	}

	return ret;
}(document.location.search.substring(1));

var settings = {
	wrap: true,
	tab_width: 4,
};

if ('settings' in params)
{
	settings = $.merge(settings, JSON.parse(params.setttings));
}

var templates = {};

function create_template(name, bindmap)
{
	templ = $('#templates').children('.' + name);

	if (templ.length != 1)
	{
		return;
	}

	templ = $(templ[0]);

	props = [];

	$.each(bindmap, function (key, callback) {
		props.push({
			elements: templ.find(key),
			callback: callback
		});
	});

	templates[name] = {
		template: templ,
		props: props,
		execute: function (context) {
			$.each(this.props, function (i, val) {
				$.each(val.elements, function (i, e) {
					var ee = $(e);

					retval = val.callback.call(context, ee);

					if (typeof(retval) == 'undefined')
					{
						return;
					}

					if (retval.nodeType || retval.jquery)
					{
						ee.replace(retval);
					}

					if (typeof(retval) == 'string')
					{
						ee.text(retval);
					}
					else if ('text' in retval)
					{
						ee.text(retval.text);
					}
					else if ('html' in retval)
					{
						ee.html(retval.html);
					}
				});
			});

			return this.template.clone();
		}
	};

	return templates[name];
}

function run_template(name, context)
{
	return templates[name].execute(context);
}

function diff_file(file)
{
	var f = $('<div/>');

	for (var i = 0; i < file.hunks.length; ++i)
	{
		var h = file.hunks[i];
		var ht = run_template('hunk', {file: file, hunk: h});

		var table = ht.children('table');

		if (settings.wrap)
		{
			table.addClass('wrapped');
		}

		var cold = h.range.old.start;
		var cnew = h.range.new.start;

		for (var j = 0; j < h.lines.length; ++j)
		{
			var l = h.lines[j];
			var o = String.fromCharCode(l.type);

			var oldtd = $('<td/>', {'class': 'gutter'});
			var newtd = $('<td/>', {'class': 'gutter'});

			var row = $('<tr/>');

			switch (o)
			{
				case ' ':
					row.addClass('context');

					oldtd.text(cold);
					newtd.text(cnew);

					cold++;
					cnew++;
				break;
				case '+':
					row.addClass('added');

					newtd.text(cnew);
					cnew++;
				break;
				case '-':
					row.addClass('removed');

					oldtd.text(cold);
					cold++;
				break;
			}

			var texttd = $('<td/>').text(l.content);

			texttd.html(texttd.html().replace(/\t/g, '<span class="tab" style="width: ' + settings.tab_width + 'ex">\t</span>'));

			row.append(oldtd).append(newtd).append(texttd);
			table.append(row);
		}


		f.append(ht);
	}

	return f;
}

function write_diff(content, res)
{
	for (var i = 0; i < res.length; ++i)
	{
		var df = diff_file(res[i]);

		content.append(df);
	}
}

function write_commit(content, commit)
{
	var c = run_template('commit', commit);
	content.append(c);
}

function update_diff()
{
	var r = new XMLHttpRequest();

	r.onload = function(e) {
		j = JSON.parse(r.responseText);

		var content = $('#diff');
		content.empty();

		if ('commit' in j)
		{
			write_commit(content, j.commit);
		}

		write_diff(content, j.diff);
	}

	var t = (new Date()).getTime()

	r.open("GET", "gitg-internal:/diff/?t=" + t + "&viewid=" + params.viewid);
	r.send();
}

function date_to_string(d)
{
	var t = ((new Date()).getTime() - d.getTime()) / 1000.0;

	if (t < 1)
	{
		return "Less than a second ago";
	}
	else if (t < 60)
	{
		return "Less than a minute ago";
	}
	else if (t < 600)
	{
		return "Less than 10 minutes ago";
	}
	else if (t < 1800)
	{
		return "Half an hour ago";
	}
	else if (t < 3600)
	{
		return "One hour ago";
	}
	else if (t < 3600 * 12)
	{
		var tt = Math.round(t / 3600)
		return tt + " hours ago";
	}
	else if (t < 3600 * 24)
	{
		return "One day ago";
	}
	else if (t < 3600 * 24 * 6)
	{
		return Math.round(t / (3600 * 24)) + " days ago";
	}

	return d.toLocaleString();
}

addEventListener('DOMContentLoaded', function () {
	create_template("hunk", {
		'.filepath': function () {
			var f = this.file.file;

			if (f.new.path)
			{
				return f.new.path;
			}
			else
			{
				return f.old.path;
			}
		},
	});

	create_template("commit", {
		'.author': function () {
			var name = $('<span/>', {'class': 'author name'}).text(this.author.name);
			var a = $('<a/>', {href: this.author.email}).text(this.author.email);

			return {html: $('<span/>').append(name).append(' <').append(a).append('>')};
		},
		'.date': function () {
			var d = new Date();
			d.setTime(this.author.time * 1000);
			return {text: date_to_string(d)};
		},
		'.subject': function () {
			return this.subject;
		},
		'.message': function () {
			return this.message;
		},
		'.sha1': function () {
			return this.id;
		},
		'.avatar': function (e) {
			var h = this.author.email_md5;

			var robo = 'http://robohash.org/' + h + '.png?size=80x80';

			e.attr('src', 'http://www.gravatar.com/avatar/' + h + '?d=' + encodeURIComponent(robo) + '&s=80');
		},
	});
}, false);

// vi:ts=4
