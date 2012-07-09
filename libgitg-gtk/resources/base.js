var id = 1;

document.addEventListener("DOMContentLoaded", function () {
	console.log('lala');
}, false);

function update_diff() {
	var r = new XMLHttpRequest();

	r.onload = function (e) {
		console.log(r.responseText);
	}

	r.open("GET", "diff:///1");
	r.send();
}
