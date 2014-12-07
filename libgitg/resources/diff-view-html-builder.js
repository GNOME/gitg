function log(e)
{
	self.postMessage({'log': e});
}

function html_escape(s)
{
	return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function Template(template, placeholders)
{
	var components = [template];

	for (var i = 0; i < placeholders.length; i++)
	{
		var name = placeholders[i];
		var varspec = '\\$\\{' + name + '\\}';
		var r = new RegExp('<!-- ' + varspec + ' -->|' + varspec, 'g');

		var newcomp = [];

		for (var j = 0; j < components.length; j += 2)
		{
			var parts = components[j].split(r);

			for (var k = 0; k < parts.length; k++)
			{
				newcomp.push(parts[k]);

				if (k != parts.length - 1)
				{
					newcomp.push(name);
				}
			}

			if (j < components.length - 1)
			{
				newcomp.push(components[j + 1]);
			}
		}

		components = newcomp;
	}

	this.components = components;
}

Template.prototype.execute = function(replacements) {
	var ret = '';

	for (var i = 0; i < this.components.length - 1; i += 2)
	{
		var name = this.components[i + 1];
		ret += this.components[i] + replacements[name];
	}

	return ret + this.components[this.components.length - 1];
}

const EDIT_INSERT = 0;
const EDIT_DELETE = 1;
const EDIT_SUBSTITUTE = 2;
const EDIT_KEEP = 3;

function min_dist(ins, del, sub)
{
	if (ins <= del)
	{
		if (sub < ins)
		{
			return {distance: sub, direction: EDIT_SUBSTITUTE};
		}
		else
		{
			return {distance: ins, direction: EDIT_INSERT};
		}
	}
	else if (del <= sub)
	{
		return {distance: del, direction: EDIT_DELETE};
	}
	else
	{
		return {distance: sub, direction: EDIT_SUBSTITUTE};
	}
}

function edit_distance(a, b)
{
	var nr = a.length + 1;
	var nc = b.length + 1;

	var d = new Uint16Array(nr * nc);
	var e = new Int8Array(nr * nc);

	for (var i = 0; i < nr; i++)
	{
		d[i] = i;
		e[i] = EDIT_DELETE;
	}

	var p = 0;

	for (var j = 0; j < nc; j++)
	{
		d[p] = j;
		e[p] = EDIT_INSERT;

		p += nr;
	}

	// Start calculating distance at first element (row 1, column 1)
	p = nr + 1;

	for (var j = 0; j < b.length; j++)
	{
		for (var i = 0; i < a.length; i++)
		{
			if (a[i] == b[j])
			{
				// zero cost substitute
				d[p] = d[p - nr - 1];
				e[p] = EDIT_KEEP;
			}
			else
			{
				var md = min_dist(d[p - nr] + 1,      // insert
				                  d[p - 1] + 1,       // delete
				                  d[p - nr - 1] + 2); // substitute

				d[p] = md.distance;
				e[p] = md.direction;
			}

			p++;
		}

		// Advance one to skip first row
		p++;
	}

	var ret = [];
	var pi = [nr, 1, nr + 1, nr + 1];

	p = nr * nc - 1;

	var cost = d[p];

	// Walk backwards to determine shortest path
	while (p > 0)
	{
		if (e[p] == EDIT_SUBSTITUTE)
		{
			ret.push(EDIT_INSERT);
			ret.push(EDIT_DELETE);
		}
		else
		{
			ret.push(e[p]);
		}

		p -= pi[e[p]];
	}

	ret.reverse();
	return {moves: ret, cost: cost};
}

const LINE_CONTEXT           = ' '.charCodeAt(0);
const LINE_ADDED             = '+'.charCodeAt(0);
const LINE_REMOVED           = '-'.charCodeAt(0);
const LINE_CONTEXT_EOFNL     = '='.charCodeAt(0);
const LINE_CONTEXT_ADD_EOFNL = '>'.charCodeAt(0);
const LINE_CONTEXT_DEL_EOFNL = '<'.charCodeAt(0);

function split_words(lines)
{
	var ret = [];

	for (var i = 0; i < lines.length; i++)
	{
		if (i != 0)
		{
			ret.push('\n');
		}

		var c = lines[i].content;

		if (lines[i].trailing_whitespace)
		{
			c += lines[i].trailing_whitespace;
		}

		// Split on word boundaries, as well as underscores and tabs
		var words = c.split(/\b|(?=[_\t])/);

		if (words.length > 0 && words[0].length == 0)
		{
			words = words.slice(1, words.length);
		}

		if (words.length > 0 && words[words.length - 1].length == 0)
		{
			words = words.slice(0, words.length - 1);
		}

		ret = ret.concat(words);
	}

	ret.push('\n');
	return ret;
}

function make_content(content)
{
	return html_escape(content);;
}

function make_content_cell(content, tws)
{
	content = make_content(content);

	var ws = '';

	if (tws)
	{
		ws = make_content(tws);
		ws = '<span class="trailing-whitespace">' + ws + '</span>';
	}

	return '<td class="code">' + content + ws + '</td>';
}

function edit_type_to_cls(tp)
{
	switch (tp)
	{
	case EDIT_DELETE:
		return "removed";
	case EDIT_INSERT:
		return "added";
	default:
		return "context";
	}
}

function lines_to_word_diff_rows(removed, added, ccontext)
{
	// concat line contents and split on word boundaries
	var remc = split_words(removed);
	var addc = split_words(added);

	var dist = edit_distance(remc, addc);

	var row = '';
	var rows = '';

	var didinsert = false;
	var didremove = false;

	var dellines = 0;
	var inslines = 0;

	var delptr = 0;
	var insptr = 0;

	// Construct rows containing the word diff, based on moves
	for (var i = 0; i < dist.moves.length; i++)
	{
		var word = '';

		switch (dist.moves[i])
		{
		case EDIT_DELETE:
			word = remc[delptr];
			delptr++;

			if (word == '\n')
			{
				dellines++;
				ccontext.removed++;
			}

			didremove = true;
			break;
		case EDIT_INSERT:
			word = addc[insptr];
			insptr++;

			if (word == '\n')
			{
				inslines++;
				ccontext.added++;
			}

			didinsert = true;
			break;
		case EDIT_KEEP:
			// Keep the same
			word = remc[delptr];

			if (word == '\n')
			{
				inslines++;
				dellines++;

				ccontext.added++;
				ccontext.removed++;
			}
			else
			{
				didinsert = true;
				didremove = true;
			}

			delptr++;
			insptr++;

			break;
		default:
			break;
		}

		if (word == '\n')
		{
			var tp = '&nbsp;';
			var cold = '';
			var cnew = '';

			if (didinsert && didremove)
			{
				tp = '±';

				cold = ccontext.old;
				cnew = ccontext.new;
			}
			else if (didinsert)
			{
				tp = '+';

				cnew = ccontext.new;
			}
			else if (didremove)
			{
				tp = '-';

				cold = ccontext.old;
			}

			rows += '<tr class="' + edit_type_to_cls(dist.moves[i]) + '"> \
				<td class="gutter old">' + cold + '</td> \
				<td class="gutter new">' + cnew + '</td> \
				<td class="gutter type">' + tp + '</td> \
				<td class="code">' + row + '</td></tr>';

			row = '';

			didremove = false;
			didinsert = false;

			if (dist.moves[i] == EDIT_INSERT || dist.moves[i] == EDIT_KEEP)
			{
				ccontext.new++;
			}

			if (dist.moves[i] == EDIT_DELETE || dist.moves[i] == EDIT_KEEP)
			{
				ccontext.old++;
			}
		}
		else
		{
			var content = make_content(word);
			var cls = edit_type_to_cls(dist.moves[i]);

			if (cls.length != 0)
			{
				row += '<span class="' + cls + '">' + content + '</span>';
			}
			else
			{
				row += content;
			}
		}
	}

	if (row.length != 0)
	{
		rows += '<tr class="' + edit_type_to_cls(dist.moves[dist.moves.length - 1]) + '"> \
			<td class="gutter old">' + ccontext.old + '</td> \
			<td class="gutter new">' + ccontext.new + '</td> \
			<td class="gutter type">&nbsp;</td> \
			<td class="code">' + row + '</td></tr>';
	}

	return rows;
}

function line_to_row(l, ccontext)
{
	var o = String.fromCharCode(l.type);

	var row = '<tr data-offset="' + l.offset + '" data-length="' + l.length + '" class="';

	switch (l.type)
	{
		case LINE_CONTEXT:
			row += 'context"> \
				<td class="gutter old">' + ccontext.old + '</td> \
				<td class="gutter new">' + ccontext.new + '</td>';

			ccontext.old++;
			ccontext.new++;
		break;
		case LINE_ADDED:
			row += 'added"> \
				<td class="gutter old"></td> \
				<td class="gutter new">' + ccontext.new + '</td>';

			ccontext.new++;
			ccontext.added++;
		break;
		case LINE_REMOVED:
			row += 'removed"> \
				<td class="gutter old">' + ccontext.old + '</td> \
				<td class="gutter new"></td>';

			ccontext.old++;
			ccontext.removed++;
		break;
		case LINE_CONTEXT_EOFNL:
		case LINE_CONTEXT_ADD_EOFNL:
		case LINE_CONTEXT_DEL_EOFNL:
			row += 'context"> \
				<td class="gutter old"></td> \
				<td class="gutter new"></td>';
			l.content = l.content.substr(1, l.content.length);
		break;
		default:
			o = ' ';
			row += '">';
		break;
	}

	if (o == ' ')
	{
		o = '&nbsp;';
	}

	row += '<td class="gutter type">' + o + '</td>';
	row += make_content_cell(l.content, l.trailing_whitespace);
	row += '</tr>';

	return row;
}

function diff_file(file, lnstate, data)
{
	var file_body = '';

	var ccontext = {
		added: 0,
		removed: 0,
		old: 0,
		new: 0
	};

	for (var i = 0; i < file.hunks.length; ++i)
	{
		var h = file.hunks[i];

		if (!h)
		{
			file_body += '<tr class="context"> \
				<td class="gutter old">' + lnstate.gutterdots + '</td> \
				<td class="gutter new">' + lnstate.gutterdots + '</td> \
				<td class="gutter type">&nbsp;</td> \
				<td></td> \
			</tr>';
			continue;
		}

		ccontext.old = h.range.old.start;
		ccontext.new = h.range.new.start;

		var hunk_header = '<span class="hunk_stats">@@ -' + h.range.old.start + ',' + h.range.old.lines + ' +' + h.range.new.start + ',' + h.range.new.lines + ' @@</span>';

		hunk_header = hunk_header;

		file_body += '<tr class="hunk_header"> \
			<td class="gutter old">' + lnstate.gutterdots + '</td> \
			<td class="gutter new">' + lnstate.gutterdots + '</td> \
			<td class="gutter type">&nbsp;</td> \
			<td class="hunk_header">' + hunk_header + '</td> \
		</tr>';

		var j = 0;

		while (j < h.lines.length)
		{
			var l = h.lines[j];
			var process = 1;

			if (data.settings.changes_inline && (l.type == LINE_ADDED || l.type == LINE_REMOVED))
			{
				// Obtain block of added/removed or removed/added
				var fj = j;

				while (fj < h.lines.length && h.lines[fj].type == l.type)
				{
					fj++;
				}

				var lj = fj;

				if (lj < h.lines.length && (h.lines[lj].type == LINE_ADDED || h.lines[lj].type == LINE_REMOVED))
				{
					var ctp = h.lines[lj].type;

					while (lj < h.lines.length && h.lines[lj].type == ctp)
					{
						lj++;
					}
				}

				if (lj - fj > 0)
				{
					// word diff of block
					process = 0;

					var flines = h.lines.slice(j, fj);
					var llines = h.lines.slice(fj, lj);

					var ladded = (l.type == LINE_ADDED ? flines : llines);
					var lremoved = (l.type == LINE_REMOVED ? flines : llines);

					var wdiff = lines_to_word_diff_rows(lremoved, ladded, ccontext);

					if (wdiff == null)
					{
						process = lj - j;
					}
					else
					{
						file_body += wdiff;

						for (var k = 0; k < lj - j; k++)
						{
							lnstate.tick();
						}

						j = lj;
					}
				}
				else
				{
					// Safe to process directly added/removed lines here, so
					// we don't recheck for a possible block
					process = fj - j;
				}
			}

			for (var k = j; k < j + process; k++)
			{
				file_body += line_to_row(h.lines[k], ccontext);
				lnstate.tick();
			}

			j += process;
		}
	}

	var file_path = '';
	var file_stats = '';
	var file_classes = '';

	if (file.file)
	{
		if (file.similarity > 0)
		{
			file_path = file.file.new.path + ' ← ' +file.file.old.path;
		}
		else if (file.file.new.path)
		{
			file_path = file.file.new.path;
		}
		else
		{
			file_path = file.file.old.path;
		}

		var total = ccontext.added + ccontext.removed;
		var addedp = Math.floor(ccontext.added / total * 100);
		var removedp = 100 - addedp;

		file_stats = '<span class="file_stats"><span class="number">' + (ccontext.added + ccontext.removed)  + '</span><span class="bar"><span class="added" style="width: ' + addedp + '%;"></span><span class="removed" style="width: ' + removedp + '%;"></span></span></span>';
	}
	else
	{
		file_classes = 'background';
	}

	var repls = {
		'FILE_PATH': file_path,
		'FILE_BODY': file_body,
		'FILE_STATS': file_stats,
		'FILE_FILENAME': file_path,
		'FILE_CLASSES': file_classes
	};

	return lnstate.template.execute(repls);
}

function diff_files(files, lines, maxlines, data)
{
	var placeholders = [
		'FILE_PATH',
		'FILE_BODY',
		'FILE_STATS',
		'FILE_FILENAME',
		'FILE_CLASSES'
	];

	var template = new Template(data.file_template, placeholders);

	var lnstate = {
		lines: lines,
		maxlines: maxlines,
		gutterdots: new Array(maxlines.toString().length + 1).join('.'),
		processed: 0,
		nexttick: 0,
		tickfreq: 0.01,
		template: template,
	};

	lnstate.tick = function() {
		lnstate.processed++;

		var proc = lnstate.processed / lnstate.lines;

		if (proc >= lnstate.nexttick)
		{
			self.postMessage({tick: proc});

			while (proc >= lnstate.nexttick)
			{
				lnstate.nexttick += lnstate.tickfreq;
			}
		}
	};

	// special empty background filler
	var f = diff_file({hunks: [null]}, lnstate, data);

	for (var i = 0; i < files.length; ++i)
	{
		f += diff_file(files[i], lnstate, data);
	}

	return f;
}

function handle_error(data, message) {
	if (!message)
	{
		message = 'unknown internal error';
	}

	var msg = 'Internal error while loading diff: ' + message;

	self.postMessage({url: data.url, diff_html: '<div class="error"><p>' + html_escape(msg) + '</p><p>This usually indicates a bug in gitg. Please consider filing a bug report at <a href="https://bugzilla.gnome.org/browse.cgi?product=gitg">https://bugzilla.gnome.org/browse.cgi?product=gitg</a></p></div>'});
}

self.onmessage = function(event) {
	var data = event.data;

	// Make request to get the diff formatted in json
	var r = new XMLHttpRequest();

	r.onerror = function(e) {
		handle_error(data, e.target.responseText);
	};

	r.onload = function(e) {
		var j = JSON.parse(r.responseText);

		if (j.error !== undefined)
		{
				handle_error(data, j.error);
		}
		else
		{
			var html = diff_files(j.diff, j.lines, j.maxlines, data);
			self.postMessage({url: data.url, diff_html: html});
		}
	}

	r.open("GET", data.url);
	r.send();
};

/* vi:ts=4 */
