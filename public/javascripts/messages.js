$(function() {
	var message = [];

	var matches = location.hash.match(/^#(\d+)$/);
	if (matches) {
		message = $('#message_' + matches[1]);
	}

	if (message.length == 0) {
		if (DATE_BY_PARAM) return;

		var trs = $('#messages tr');
		for (var i = trs.length - 1; i >= 0; i--) {
			var matches = trs[i].id.match(/^message_\d+$/);
			if (matches) {
				message = trs.eq(i);
				break;
			}
		}
	}

	if (message.length == 0) return;


	// scroll to message
	var headerHeight = 120;
	var scrollTo     = message.offset().top - headerHeight;
	$('html').animate({ scrollTop: scrollTo }, 1000);


	// highlight message
	var tds = message.find('td');
	for (var i = 0; i < 5; i++) {
		tds.effect('highlight', {}, 1200);
	}
});
