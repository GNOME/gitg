function html_escape(s)
{
	return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function diff_file(file, lnstate, data)
{
	var f = '<div>';

	tabrepl = '<span class="tab" style="width: ' + data.settings.tab_width + 'ex">\t</span>';

	for (var i = 0; i < file.hunks.length; ++i)
	{
		var h = file.hunks[i];

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

		var filepath;

		if (file.file.new.path)
		{
			filepath = file.file.new.path;
		}
		else
		{
			filepath = file.file.old.path;
		}

		var template = data.hunk_template.replace('<!-- ${FILEPATH} -->', filepath);
		f += template.replace('<!-- ${TABLE_BODY} -->', tablecontent);
	}

	return f + '</div>';
}

function diff_files(files, lines, data)
{
	var f = '';
	lnstate = {lines: lines, processed: 0, nexttick: 0, tickfreq: 0.01};

	for (var i = 0; i < files.length; ++i)
	{
		f += diff_file(files[i], lnstate, data);
	}

	return f;
}

self.onmessage = function(event) {
	var data = event.data;

	// Make request to get the diff formatted in json
	var r = new XMLHttpRequest();

	r.onload = function(e) {
		var j = JSON.parse(r.responseText);
		var html = diff_files(j.diff, j.lines, data);

		self.postMessage({url: data.url, diff_html: html});
	}

	r.open("GET", data.url);
	r.send();
};
