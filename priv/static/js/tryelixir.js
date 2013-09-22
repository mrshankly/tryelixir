var tutorialActive = false;
var currentPage = 0;
var guideSuffix = (function() {
  try {
    var lang = (navigator.browserLanguage || navigator.language || navigator.userLanguage).substr(0,2)

    lang = $.inArray(lang,
              ['ja'] //add if you create support language files.
                    ) ? lang : 'en';

    return 'en' == lang ? '' : '.' + lang
  } catch(e) {}
  return '';
})();

var tutorialPages = [
    {guide: "intro.html",
     trigger:function(line, result){
        return false;
    }},
    {guide: "t1.html",
     trigger:function(line, result){
        return (result === "12");
    }},
    {guide: "t2.html",
     trigger:function(line, result){
        return (result === "4");
    }},
    {guide: "t3.html",
     trigger:function(line, result){
        return (result.charAt(0) === ":");
    }},
    {guide: "t4.html",
     trigger:function(line, result){
        return (line.substring(0, 8) === "set_elem" && result.charAt(0) === "{")
    }},
    {guide: "t5.html",
     trigger:function(line, result){
        return (result === ":ok");
    }},
    {guide: "t6.html",
     trigger:function(line, result){
        return (result === "[97, 98, 99, 1]");
    }},
    {guide: "t7.html",
     trigger:function(line, result){
        return (line === "age" && result.substring(0, 2) !== "**");
    }},
    {guide: "t8.html",
     trigger:function(line, result){
        return (result === ":ok");
    }},
    {guide: "t9.html",
     trigger:function(line, result){
        return (result === ":ok");
    }},
    {guide: "end.html",
     trigger:function(line, result){
        tutorialActive = false;
        return false;
    }}
];

// Removes <tab> and decodes html entities
function decode(line) {
    var temp = $("<div/>").html(line).text();
    var temp2 = temp.replace("<tab>", "");
    var decoded = temp2.replace("</tab>", "");
    return decoded;
}

function makeCodeClickable() {
    /* multi-line clicks not working */
    /*$('#mlcode').each(function() {
        $(this).attr('title','Click me to insert in the console.');
        $(this).click(function(e) {
            if (e.button == 0) {
                var code = $(this).html().split("<br>");
                controller.inner.click();
                for (var i = 0; i < code.length; i++) {
                    controller.promptText(decode(code[i]));
                    //TODO
                }
            }
        })
    });*/
    $('code').each(function() {
        $(this).attr('title','Click me to insert "' +
                         $(this).text() + '" in the console.');
        $(this).click(function(e) {
            if (e.button == 0) {
                controller.promptText($(this).text());
                controller.inner.click();
            }
        });
    });
}

function animate(page) {
    $("#tutorial").fadeOut("fast", function() {
        $(this).load(page, function() {
            makeCodeClickable();
            $(this).fadeIn("fast");
        });
    })
}

function goToPage(number) {
    if (number < tutorialPages.length && number >= 0) {
        currentPage = number;
        animate("static/tutorial/" + tutorialPages[number].guide + guideSuffix);
    }
}

$(document).ready(function() {
    var console = $("#console");
    controller = console.console({
        promptLabel: "iex(1)> ",
        commandValidate: function(input) {
            return (input.length < 1000);
        },
        commandHandle: function(line, report) {
            switch (line) {
                case ":next":
                    if (tutorialActive)
                        goToPage(currentPage + 1);
                    report("");
                    return;
                case ":prev":
                    if (tutorialActive)
                        goToPage(currentPage - 1);
                    report("");
                    return;
                case ":restart":
                    if (tutorialActive)
                        goToPage(1);
                    report("");
                    return;
                case ":clear":
                    controller.reset();
                    return;
                case ":start":
                    tutorialActive = true;
                    goToPage(1);
                    report("");
                    return;
                case ":steps":
                    animate("static/tutorial/steps.html")
                    report("");
                    return;
                default:
                    var m = line.match(/^:step([1-9]+)/);
                    if (m) {
                        tutorialActive = true;
                        goToPage(Number(m[1]));
                        report("");
                        return;
                    }
                    $.ajax({
                        "type": "post",
                        "url": "/api/eval",
                        "data": {"code": line},
                        "dataType": "text",
                        "success": function(json){
                            obj = JSON.parse(json);
                            controller.promptLabel(obj.prompt);

                            // If there's no result, just print prompt and keep adding new input
                            if (obj.result == undefined) {
                                report();
                            } else {
                                if (obj.type == "ok") {
                                    report([{msg:obj.result, className:"jquery-console-message-success"}]);
                                } else {
                                    report([{msg:obj.result, className:"jquery-console-message-error"}]);
                                }
                                if (tutorialActive && tutorialPages[currentPage].trigger(line, obj.result)) {
                                    goToPage(currentPage + 1);
                                }
                            }
                        }
                    });
            }
            return;
        },
        autofocus: true,
        animateScroll: true,
        promptHistory: true,
        welcomeMessage: "Interactive Elixir (" + version.dataset.version + ")"
    });
    $("#tutorial").load("static/tutorial/intro.html" + guideSuffix, function() {
        makeCodeClickable();
    });
});
