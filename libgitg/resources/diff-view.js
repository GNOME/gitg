var current_diff;

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
	debug: false,
	staged: false,
	unstaged: false,
	strings: {
		stage: 'stage',
		unstage: 'unstage',
		loading_diff: 'Loading diff...'
	},
};

if ('settings' in params)
{
	$.extend(settings, JSON.parse(params.settings));
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

function expand_collapse()
{
	var expander = $(this);

	// If expanded, will be true
	var toExpand = expander.text() == "+";

	if (toExpand)
	{
		// next step to close it
		expander.text("-");
	}
	else
	{
		// next step is to open it
		expander.text("+");
	}

	expander.closest('tbody').toggleClass("collapsed");
}

function next_element(elem)
{
	elem = elem.nextSibling;

	while (elem != null && elem.nodeType != Node.ELEMENT_NODE)
	{
		elem = elem.nextSibling;
	}

	return elem;
}

function has_class(e, cls)
{
	return e.classList.contains(cls);
}

var has_selection = false;

function update_has_selection()
{
	var selection = document.querySelectorAll('tr.added.selected, tr.removed.selected');
	var hs = (selection.length != 0);

	if (hs != has_selection)
	{
		has_selection = hs;

		var v = has_selection ? "yes" : "no";
		xhr_get('internal', {action: 'selection-changed', value: v});
	}
}

function prepare_patchset(filediv)
{
	var elem = filediv.querySelector('tr.file_header');

	elem = next_element(elem);

	var patches = [];
	var doffset = 0;

	var a = "a".charCodeAt(0);
	var r = "r".charCodeAt(0);

	var last = null;

	while (elem != null)
	{
		var e = elem;
		elem = next_element(elem);

		var added = has_class(e, 'added');
		var removed = has_class(e, 'removed');

		if (!added && !removed)
		{
			continue;
		}

		var selected = has_class(e, 'selected');
		var offset = parseInt(e.getAttribute('data-offset'));
		var length = parseInt(e.getAttribute('data-length'));

		if (selected)
		{
			var tp = added ? a : r;

			if (last != null && last[0] == tp && last[2] + last[3] == offset)
			{
				last[3] += length;
			}
			else
			{
				var o = {old: offset, new: offset};

				if (added)
				{
					o.old -= doffset;
				}
				else
				{
					o.new += doffset;
				}

				// [sign, old_offset, new_offset, length]
				last = [tp, o.old, o.new, length];
				patches.push(last);
			}
		}

		doffset += added ? length : -length;
	}

	var filename = filediv.getAttribute('data-filename');
	return [filename, patches];
}

function get_selection()
{
	var files = document.querySelectorAll('#diff_content div.file');
	var ret = [];

	for (var i = 0; i < files.length; i++)
	{
		if (!has_class(files[i], 'background'))
		{
			ret.push(prepare_patchset(files[i]));
		}
	}

	return ret;
}

function stage_unstage_hunk()
{
	var elem = next_element(this);

	var hasunsel = false;
	var lines = [];

	while (elem != null && !(has_class(elem, 'file_header') || has_class(elem, 'hunk_header')))
	{
		if ((has_class(elem, 'added') || has_class(elem, 'removed')))
		{
			lines.push(elem);

			if (!has_class(elem, 'selected'))
			{
				hasunsel = true;
			}
		}

		elem = next_element(elem);
	}

	for (var i = 0; i < lines.length; i++)
	{
		if (hasunsel)
		{
			lines[i].classList.add('selected');
		}
		else
		{
			lines[i].classList.remove('selected');
		}
	}

	update_has_selection();
}

function stage_unstage_line()
{
	if (has_class(this, 'selected'))
	{
		this.classList.remove('selected');
	}
	else
	{
		this.classList.add('selected');
	}

	update_has_selection();
}

function xhr_get(action, data, onload)
{
	var r = new XMLHttpRequest();

	if (onload)
	{
		r.onload = function(e) { onload(r.responseText); }
	}

	t = (new Date()).getTime();
	d = '?_t=' + t + '&viewid=' + params.viewid + "&diffid=" + current_diff;

	for (var k in data)
	{
		d += '&' + encodeURIComponent(k) + '=' + encodeURIComponent(data[k]);
	}

	r.open("GET", "gitg-diff:/" + action + "/" + d);
	r.send();
}

function update_diff(id, lsettings)
{
	if (html_builder_worker)
	{
		html_builder_worker.terminate();
	}

	var content = $('#diff_content');

	if (typeof id == 'undefined')
	{
		content.empty();
		update_has_selection();
		return;
	}

	current_diff = id;

	if (typeof lsettings != 'undefined')
	{
		$.extend(settings, lsettings);
	}

	workeruri = 'diff-view-html-builder.js';

	if (settings.debug)
	{
		var t = (new Date()).getTime();
		workeruri += '?t' + t;
	}

	html_builder_worker = new Worker(workeruri);
	html_builder_tick = 0;

	html_builder_progress_timeout = setTimeout(function (){
		var eta = 200 / html_builder_tick - 200;

		if (eta > 1000)
		{
			// Show the progress
			content.html(' \
				<div class="loading"> \
					' + settings.strings.loading_diff + ' \
				</div> \
			');

			update_has_selection();
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

			content.html(event.data.diff_html);
			update_has_selection();

			$(".expander").click(expand_collapse);

			if (settings.staged || settings.unstaged)
			{
				$("tr.hunk_header").click(stage_unstage_hunk);
				$("tr.added, tr.removed").click(stage_unstage_line);
			}
		}
	}

	var t = (new Date()).getTime();

	var file_template = $('#templates div.file')[0].outerHTML;

	// Load the diff asynchronously
	html_builder_worker.postMessage({
		url: "gitg-diff:/diff/?t=" + t + "&viewid=" + params.viewid + "&diffid=" + id + "&format=diff_only",
		settings: settings,
		file_template: file_template,
	});

	xhr_get("diff", {format: "commit_only"}, function(r) {
		var j = JSON.parse(r);

		if ('commit' in j)
		{
			$('#diff_header').html(write_commit(j.commit));

			$(".format_patch_button").click(function() {
				xhr_get('patch', {id: j.commit.id});
			});
		}
	});
}

addEventListener('DOMContentLoaded', function () {
	create_template("commit", {
		'.author': function () {
			var name = $('<span/>', {'class': 'author name'}).text(this.author.name);
			var a = $('<a/>', {href: 'mailto:' + this.author.email}).text(this.author.email);

			return {html: $('<span/>').append(name).append(' <').append(a).append('>')};
		},
		'.date': function () {
			return {text: this.author.time};
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
