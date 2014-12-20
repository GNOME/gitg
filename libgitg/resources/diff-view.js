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
	show_parents: false,
	strings: {
		stage: 'stage',
		unstage: 'unstage',
		loading_diff: 'Loading diff...',
		notes: 'Notes:',
		parents: 'Parents:',
		diff_against: 'Diff against:'
	},
};

var avatar_cache = {};

if ('settings' in params)
{
	$.extend(settings, JSON.parse(params.settings));
}

var escapeDiv = document.createElement('div');
var escapeElement = document.createTextNode('');
escapeDiv.appendChild(escapeElement);

function html_escape(str)
{
	escapeElement.data = str;
	return escapeDiv.innerHTML;
}

var commit_elements = null;

function get_commit_elements(content)
{
	if (commit_elements != null)
	{
		return commit_elements;
	}

	var elems = content.find('[data-id]');

	commit_elements = {};

	for (var i = 0; i < elems.length; i++)
	{
		var elem = $(elems[i]);
		var name = elem.attr('data-id');

		commit_elements[name] = elem;
	}

	return commit_elements;
}

function write_avatar(avatar, commit)
{
	var h = commit.author.email_md5;

	if (h in avatar_cache)
	{
		var avc = avatar_cache[h];

		if (avc != null && avatar.attr('src') != avc)
		{
			avatar.attr('src', avc);
		}

		return;
	}

	var loader = $('<img/>');
	var gravatar = 'http://www.gravatar.com/avatar/' + h + '?d=404&s=50';

	loader.on('load', function () {
		avatar_cache[h] = gravatar;

		avatar.attr('src', gravatar);
	});

	loader.on('error', function () {
		var avc = 'gitg-diff:/icon/avatar-default-symbolic?size=50';

		avatar_cache[h] = avc;
		avatar.attr('src', avc);
	});

	loader.attr('src', gravatar);
}

function prettify_message(message)
{
	var lines = message.split(/\n/);
	var ret = '';
	var isempty = false;

	for (var i = 0; i < lines.length; i++)
	{
		var l = lines[i];
		l = l.trimRight();

		if (isempty && l.length != 0)
		{
			ret += '\n\n';
		}
		else if (l.match(/^[^a-zA-Z_]/))
		{
			ret += '\n';
		}
		else if (l.length != 0 && ret.length != 0)
		{
			ret += ' ';
		}

		ret += l;
		isempty = (l.length == 0);
	}

	return ret;
}

function write_commit(content, commit)
{
	var elems = get_commit_elements(content);

	// Author
	var name = $('<span/>', {'class': 'author name'}).text(commit.author.name);
	var a = $('<a/>', {href: 'mailto:' + commit.author.email}).text(commit.author.email);
	elems.author.html($('<span/>').append(name).append(' <').append(a).append('>'));

	// Date
	elems.date.text(commit.author.time);

	// Message
	elems.message.text(prettify_message(commit.message));

	// Notes
	if (commit.hasOwnProperty('note'))
	{
		elems.notes.text(settings.strings.notes);
		elems.note_message.text(commit.note);
		elems.notes_container.show();
	}
	else
	{
		elems.notes_container.hide();
	}

	if (commit.parents.length > 1)
	{
		var span = $('<span/>').text(settings.strings.diff_against);
		var chooser = $('<select/>');

		for (var i = 0; i < commit.parents.length; i++)
		{
			var parent = commit.parents[i];
			var elem = $('<option/>', {
				value: parent.id
			}).text(parent.id.slice(0, 6));

			if (parent.id === settings.parent)
			{
				elem.attr('selected', 'selected');
			}

			chooser.append(elem);
		}

		chooser.on('change', function() {
			xhr_get('internal', {'action': 'select-parent', 'value': chooser.val()});
		});

		elems.parent_chooser.html([span, chooser]);
	}
	else
	{
		elems.parent_chooser.html('');
	}

	if (commit.parents.length > 1 && settings.show_parents)
	{
		var d = $('<div/>');

		d.append($('<div/>', {'class': 'title'}).text(settings.strings.parents));

		var ul = $('<ul/>');

		for (var i = 0; i < commit.parents.length; i++)
		{
			var parent = commit.parents[i];
			var li = $('<li/>');

			var a = $('<a/>', {'href': '#'}).text(parent.id.slice(0, 6) + ': ' + parent.subject);
			a.on('click', (function(id, e) {

				xhr_get('internal', {'action': 'load-parent', 'value': id});
				e.preventDefault();
				e.stopPropagation();
			}).bind(this, parent.id));

			li.append(a);
			ul.append(li);
		}

		d.append(ul);

		elems.parents.html(d);
		elems.parents.show();
	}
	else
	{
		elems.parents.hide();
	}

	// Sha1
	elems.sha1.text(commit.id);

	write_avatar(elems.avatar, commit);
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

function update_has_selection()
{
	var selection = document.querySelectorAll('tr.added.selected, tr.removed.selected');
	var hs = (selection.length != 0);

	var v = hs ? "yes" : "no";
	xhr_get('internal', {action: 'selection-changed', value: v});
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
				// Contiguous block, just add the length
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

		// Keep track of the total offset difference between old and new
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

var tab_width_rule = null;

function update_tab_width(width)
{
	settings.tab_width = width;

	if (tab_width_rule == null)
	{
		var sheet = document.getElementById('dynamic_styles').sheet;
		sheet.addRule('#diff td.code', 'tab-size: ' + width, 0);
		tab_width_rule = sheet.rules[0];
	}

	tab_width_rule.style.tabSize = width;
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

	update_tab_width(settings.tab_width);

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
		if (!r)
		{
			return;
		}

		var j = JSON.parse(r);

		if ('commit' in j)
		{
			write_commit($('#diff_header .commit'), j.commit);
			$('#diff_header').show();
		}
		else
		{
			$('#diff_header').hide();
		}
	});
}

addEventListener('DOMContentLoaded', function () {
	xhr_get('internal', {action: 'loaded'});
}, false);

// vi:ts=4
