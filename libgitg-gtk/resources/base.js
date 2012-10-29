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
			selector: key,
			callback: callback
		});
	});

	templates[name] = {
		template: templ,
		props: props,
		execute: function (context) {
			var ret = this.template.clone();

			$.each(this.props, function (i, val) {
				ret.find(val.selector).each(function (i, e) {
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

			return ret;
		}
	};

	return templates[name];
}

function run_template(name, context)
{
	return templates[name].execute(context);
}

var escapeDiv = document.createElement('div');
var escapeElement = document.createTextNode('');
escapeDiv.appendChild(escapeElement);

function html_escape(str)
{
	escapeElement.data = str;
	return escapeDiv.innerHTML;
}

function diff_file(file)
{
	var f = '<div>';

	tabrepl = '<span class="tab" style="width: ' + settings.tab_width + 'ex">\t</span>';

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

		var tablecontent = '';

		for (var j = 0; j < h.lines.length; ++j)
		{
			var l = h.lines[j];
			var o = String.fromCharCode(l.type);

			var row = '<tr class="';

			switch (o)
			{
				case ' ':
					row += 'context"><td>' + cold + '</td><td>' + cnew + '</td>';

					cold++;
					cnew++;
				break;
				case '+':
					row += 'added"><td></td><td>' + cnew + '</td>';

					cnew++;
				break;
				case '-':
					row += 'removed"><td>' + cold + '</td><td></td>';

					cold++;
				break;
				default:
					row += '">';
				break;
			}

			row += '<td>' + html_escape(l.content).replace(/\t/g, tabrepl) + '</td>';
			tablecontent += row;
		}

		var h = ht[0].outerHTML;
		var findstr = '</table>';
		var idx = h.indexOf(findstr);

		f += h.substring(0, idx) + tablecontent + h.substring(idx);
	}

	return f + '</div>';
}

function write_diff(res)
{
	var f = '';

	for (var i = 0; i < res.length; ++i)
	{
		f += diff_file(res[i]);
	}

	return f;
}

function write_commit(commit)
{
	return run_template('commit', commit);
}

function update_diff()
{
	var r = new XMLHttpRequest();

	r.onload = function(e) {
		var j = JSON.parse(r.responseText);

		var html = '';

		if ('commit' in j)
		{
			$('#diff_header').html(write_commit(j.commit));
		}

		var content = document.getElementById('diff_content');
		content.innerHTML = write_diff(j.diff);
	}

	var t = (new Date()).getTime();

	r.open("GET", "gitg-diff:/diff/?t=" + t + "&viewid=" + params.viewid);
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

			var loader = $('<img/>');

			loader.on('error', function () {
				var robosrc = 'http://robohash.org/' + h + '.png?size=50x50';

				e.attr('src', robosrc);
			});

			var gravatar = 'http://www.gravatar.com/avatar/' + h + '?d=404&s=50';

			loader.on('load', function () {
				e.attr('src', gravatar);
			});

			loader.attr('src', gravatar);
		},
	});
}, false);

// vi:ts=4
