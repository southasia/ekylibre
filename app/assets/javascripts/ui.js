(function ($) {


    // Toggle now with
    $(document).ready(function(event) {
	$('*[data-toggle-now-with]').each(function () {
	    var element = $(this);
	    element.hide();
	    $(element.attr('data-toggle-now-with')).show();
	});
    });


    // Auto focus
    $.autoFocus = function () {
	this.focus();
	this.select();
    }
    // $.behave("*[data-autofocus]", "load", $.autoFocus);
    $.behave("input[type='text']:first", "load", $.autoFocus);

    // Auto-reconnection with time-out
    $.timedSession = {
	timer: null,
	reconnectable: true,
	openReconnection: function () {
	    var body = $('body');
	    var url = body.attr('data-timeout-href');
	    if ($.timedSession.reconnectable && url !== null && url !== undefined) {
		window.clearTimeout($.timedSession.timer); 
		$.timedSession.reconnectable = false;
		// Formize.Dialog.open(url, null, 0);
		$.ajaxDialog(url, {
		    returns: {
			granted: function (frame, data, textStatus, request) {
			    frame.dialog("option", "effect", "fadeOut");
			    frame.dialog("close");
			    $.timedSession.reconnectable = true;
			    $.timedSession.startCountdown();
			},
			denied: function (frame, data, textStatus, request) {
			    frame.html(request.responseText);
			    frame.dialog("widget").effect("shake", {}, 100, function () {
				frame.find('input[type="password"]').focus();
			    });
			}
		    }
		});
		// Adds $.timedSession.reconnectable = true if granted and not denied
	    }
	},	
	startCountdown: function () {
	    var body = $('body');
	    var timeout = body.attr('data-timeout');
	    window.clearTimeout($.timedSession.timer);
	    if (!isNaN(timeout) && $.timedSession.reconnectable) {
		var duration = parseFloat(timeout)*1000;
		$.timedSession.timer = window.setTimeout($.timedSession.openReconnection, duration);
	    }
	}
    }
    $(document).ready($.timedSession.startCountdown);
    $(document).ajaxStop($.timedSession.startCountdown);

}) (jQuery);