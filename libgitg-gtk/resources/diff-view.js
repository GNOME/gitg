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


function write_commit(commit)
{
	return run_template('commit', commit);
}

var html_builder_worker = 0;
var html_builder_tick = 0;

function update_diff(id)
{
	if (html_builder_worker)
	{
		html_builder_worker.terminate();
	}

	html_builder_worker = new Worker('diff-view-html-builder.js');
	html_builder_tick = 0;

	var content = document.getElementById('diff_content');

	html_builder_progress_timeout = setTimeout(function (){
		var eta = 200 / html_builder_tick - 200;

		if (eta > 1000)
		{
			// Show the progress
			content.innerHTML = '<div class="loading">Loading diff...</div>.';
		}

		html_builder_progress_timeout = 0;
	}, 200);

	html_builder_worker.onmessage = function (event) {
		if (event.data.log)
		{
			console.log(event.data.log);
		}
		else if (event.data.tick)
		{
			html_builder_tick = event.data.tick;
		}
		else
		{
			html_builder_worker.terminate();
			html_builder_worker = 0;

			if (html_builder_progress_timeout)
			{
				clearTimeout(html_builder_progress_timeout);
				html_builder_progress_timeout = 0;
			}

			content.innerHTML = event.data.diff_html;
		}
	}

	var t = (new Date()).getTime();

	var hunk_template = $('#templates div.hunk')[0].outerHTML;

	// Load the diff asynchronously
	html_builder_worker.postMessage({
		url: "gitg-diff:/diff/?t=" + t + "&viewid=" + params.viewid + "&diffid=" + id + "&format=diff_only",
		settings: settings,
		hunk_template: hunk_template,
	});

	// Load the commit directly here
	var r = new XMLHttpRequest();

	r.onload = function(e) {
		var j = JSON.parse(r.responseText);

		if ('commit' in j)
		{
			$('#diff_header').html(write_commit(j.commit));
		}
	}

	t = (new Date()).getTime();
	r.open("GET", "gitg-diff:/diff/?t=" + t + "&viewid=" + params.viewid + "&diffid=" + id + "&format=commit_only");
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
