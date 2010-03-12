$(function() {
	$('#search_form').submit(function(event) {
		event.preventDefault();

		var search = $('#search').val();
		if (search.length) {
			var search_extra = $('#search_extra').val();
			if (search_extra.length) {
				var quote_count = search.length - search.replace(/"/g, '').length;
				if (quote_count % 2) {
					search += '"';
				}
				search += ' ' + search_extra;
			}
			// 2回エスケープしないと Passenger で動作しない
			location.href = '/search/' + encodeURIComponent(encodeURIComponent(search));
		}
	});

	$('#search').focus().select();
});
