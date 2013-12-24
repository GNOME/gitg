function html_escape(s)
{
	return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function exec_template(template, replacements) {
	for (var r in replacements)
	{
		// As we are using the repl in the later 'template.replace()'
		// as the replacement in which character '$' is special, we
		// need to make sure each occurence of '$' character in the
		// replacement is represented as '$$' (which stands for a
		// literal '$'), so, we need to use '$$$$' here to get '$$'.
		var replacement = replacements[r].replace(/\$/g, '$$$$');
		var placeholder = new RegExp('<!-- \\$\\{' + r + '\\} -->', 'g');
		template = template.replace(placeholder, replacement);
	}

	return template;
}

function diff_hunk(hunk, lnstate, data)
{
	var hunk_body = '';

	var hunk_header = '<span class="hunk_stats">@@ -' + hunk.range.old.start + ',' + hunk.range.old.lines + ' +' + hunk.range.new.start + ',' + hunk.range.new.lines + ' @@</span>';

	hunk_header = lnstate.stagebutton + hunk_header;

	hunk_body += '<tr class="hunk_header">\
		<td class="gutter old">' + lnstate.gutterdots + '</td> \
		<td class="gutter new">' + lnstate.gutterdots + '</td> \
		<td class="hunk_header">' + hunk_header + '</td> \
	</tr>';

	var row, line, proc;
	var cold = hunk.range.old.start;
	var cnew = hunk.range.new.start;
	for (var i = 0; i < hunk.lines.length; ++i)
	{
		row = '<tr class="';

		line = hunk.lines[i];

		switch (String.fromCharCode(line.type))
		{
			case ' ':
				row += 'context"> \
					<td class="gutter old">' + cold + '</td> \
					<td class="gutter new">' + cnew + '</td>';

				cold++;
				cnew++;
				break;
			case '+':
				row += 'added"> \
					<td class="gutter old"></td> \
					<td class="gutter new">' + cnew + '</td>';

				cnew++;
				lnstate.added++;
				break;
			case '-':
				row += 'removed"> \
					<td class="gutter old">' + cold + '</td> \
					<td class="gutter new"></td>';

				cold++;
				lnstate.removed++;
				break;
			case '=':
			case '>':
			case '<':
				row += 'context"> \
					<td class="gutter old"></td> \
					<td class="gutter new"></td>';
					line.content = line.content.substr(1, line.content.length);
				break;
			default:
				row += '">';
				break;
		}

		line.content = html_escape(line.content).replace(/\t/g, '<span class="tab" style="width: ' + data.settings.tab_width + 'ex">\t</span>');

		row += '<td class="code">' + line.content + '</td>';

		row += '</tr>';

		hunk_body += row;

		lnstate.processed++;

		proc = lnstate.processed / lnstate.lines;

		if (proc >= lnstate.nexttick)
		{
			self.postMessage({tick: proc});

			while (proc >= lnstate.nexttick)
			{
				lnstate.nexttick += lnstate.tickfreq;
			}
		}
	}

	return hunk_body;
}

function diff_file(file, lnstate, data)
{
	lnstate.added = 0;
	lnstate.removed = 0;

	var file_body = '';

	for (var i = 0; i < file.hunks.length; ++i)
	{
		file_body += diff_hunk(file.hunks[i], lnstate, data);
	}

	var file_path;

	if (file.file.new.path)
	{
		file_path = file.file.new.path;
	}
	else
	{
		file_path = file.file.old.path;
	}

	var total = lnstate.added + lnstate.removed;
	var addedp = Math.floor(lnstate.added / total * 100);
	var removedp = 100 - addedp;

	var file_stats = '<span class="file_stats"><span class="number">' + (lnstate.added + lnstate.removed)  + '</span><span class="bar"><span class="added" style="width: ' + addedp + '%;"></span><span class="removed" style="width: ' + removedp + '%;"></span></span></span>';

	file_stats = lnstate.stagebutton + file_stats;

	return exec_template(data.file_template, {
		'FILE_PATH': file_path,
		'FILE_BODY': file_body,
		'FILE_STATS': file_stats,
	});
}

function diff_files(files, lines, maxlines, data)
{
	var f = '';

	var lnstate = {
		lines: lines,
		maxlines: maxlines,
		gutterdots: new Array(maxlines.toString().length + 1).join('.'),
		processed: 0,
		nexttick: 0,
		tickfreq: 0.01,
		stagebutton: '',
	};

	if (data.settings.staged || data.settings.unstaged)
	{
		var cls;
		var nm;

		if (data.settings.staged)
		{
			cls = 'unstage';
			nm = data.settings.strings.unstage;
		}
		else
		{
			cls = 'stage';
			nm = data.settings.strings.stage;
		}

		lnstate.stagebutton = '<span class="' + cls + '">' + nm + '</span>';
	}

	for (var i = 0; i < files.length; ++i)
	{
		f += diff_file(files[i], lnstate, data);
	}

	return f;
}

function log(e)
{
	self.postMessage({'log': e});
}

self.onmessage = function(event) {
	var data = event.data;

	// Make request to get the diff formatted in json
	var r = new XMLHttpRequest();

	r.onload = function(e) {
		var j = JSON.parse(r.responseText);
		var html = diff_files(j.diff, j.lines, j.maxlines, data);

		self.postMessage({url: data.url, diff_html: html});
	}

	r.open("GET", data.url);
	r.send();
};
