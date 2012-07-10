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

var file_template = '<div class="file"><div class="header"><span class="cmd">diff --git</span> <span class="path old">#{this.file.old.path}</span> <span class="path new">#{this.file.new.path}</span><br/><span class="old prefix">---</span> <span class="path old prefix">#{this.file.old.path}</span><br/><span class="new prefix">+++</span> <span class="path new prefix">#{this.file.new.path}</span></div><div class="hunks"></div></div>';

var hunk_template = '<div class="hunk"><div class="header">@@ -#{this.range.old.start},#{this.range.old.lines} +#{this.range.new.start},#{this.range.new.lines} @@</div><div>';

function run_template(html, context)
{
	var r = /#{([^}]+)}/g;

	return $(html.replace(r, function (m, p1) {
		var f = function () {
			return eval(p1);
		}

		return f.call(context);
	}));
}

function diff_file(file)
{
	var f = run_template(file_template, file);

	for (var i = 0; i < file.hunks.length; ++i)
	{
		var h = file.hunks[i];
		var ht = run_template(hunk_template, h);

		for (var j = 0; j < h.lines.length; ++j)
		{
			var l = h.lines[j];

			var o = String.fromCharCode(l.type);

			var cls = {
				' ': 'context',
				'+': 'added',
				'-': 'removed'
			}[o];

			if (o == ' ')
			{
				o = '&nbsp';
			}

			var ll = $('<div/>', {'class': 'line ' + cls}).html(o);
			ll.append($('<span/>').text(l.content));

			ht.append(ll);
		}

		f.append(ht);
	}

	return f;
}

function write_diff(res)
{
	var content = $('#diff');
	content.empty();

	for (var i = 0; i < res.length; ++i)
	{
		content.append(diff_file(res[i]));
	}
}

function update_diff()
{
	var r = new XMLHttpRequest();

	r.onload = function(e) {
		j = JSON.parse(r.responseText);

		write_diff(j);
	}

	r.open("GET", "gitg-internal:/diff/?viewid=" + params.viewid);
	r.send();
}
