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
	var f = run_template('file', file);

	for (var i = 0; i < file.hunks.length; ++i)
	{
		var h = file.hunks[i];
		var ht = run_template('hunk', h);

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

	r.open("GET", "gitg-internal:/diff/?viewid=" + params.viewid);
	r.send();
}

addEventListener('DOMContentLoaded', function () {
	create_template("file", {
		'.path.old': function () { return this.file.old.path; },
		'.path.new': function () { return this.file.new.path; }
	});

	create_template("hunk", {
		'.header': function () { return this.header; }
	});

	create_template("commit", {
		'.author': function () { return this.author.name + ' <' + this.author.email + '>'; },
		'.date': function () {
			var d = new Date();
			d.setTime(this.author.time * 1000);
			return {text: d.toLocaleString()};
		},
		'.subject': function () { return this.subject; },
		'.message': function () { return this.message; },
		'.sha1': function () { return this.id; },
		'.avatar': function (e) {
			var h = this.author.email_md5;

			e.attr('src', 'http://www.gravatar.com/avatar/' + h + '?s=80');
		},
	});
}, false);

// vi:ts=4
