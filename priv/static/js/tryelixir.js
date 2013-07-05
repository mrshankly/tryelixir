var tutorialActive = false;
var currentPage = 0;
var tutorialPages = [
    "t1.html",
    "t2.html",
    "t3.html"
];

function changeTutorial(index) {
    $("#tutorial").fadeOut("fast", function() {
        $("#tutorial").load("static/tutorial/" + tutorialPages[index]);
        $("#tutorial").fadeIn("fast");
    });
}

function goToPage(number) {
    currentPage = number;
    changeTutorial(number);
}

function onValidate(input) {
    return (input != "");
}

function onHandle(line, report) {
    switch (line) {
        case ":next":
            if (tutorialActive && currentPage < tutorialPages.length - 1)
                goToPage(currentPage + 1);
            report([{msg:":next", className:"jquery-console-message-success"}]);
            return;
        case ":prev":
            if (tutorialActive && currentPage > 0)
                goToPage(currentPage - 1);
            report([{msg:":prev", className:"jquery-console-message-success"}]);
            return;
        case ":restart":
            if (tutorialActive)
                goToPage(0);
            report([{msg:":restart", className:"jquery-console-message-success"}]);
            return;
        case ":clear":
            shell();
            report();
            return;
        case ":start":
            tutorialActive = true;
            goToPage(0);
            report([{msg:":start", className:"jquery-console-message-success"}]);
            return;
    }
    $.ajax({
        "type": "post",
        "url": "/api/eval",
        "data": {"code": line},
        "dataType": "text",
        "success": function(json){
            obj = JSON.parse(json);
            if (obj.type == "ok") {
                report([{msg:obj.result, className:"jquery-console-message-success"}]);
            } else {
                report([{msg:obj.result, className:"jquery-console-message-error"}]);
            }
        }
    });
    return;
}

function shell() {
    $("#console").empty();
    var console = $("#console");
    var controller = console.console({
        promptLabel: "iex(1)> ",
        commandValidate: onValidate,
        commandHandle: onHandle,
        autofocus: true,
        animateScroll: true,
        promptHistory: true,
        welcomeMessage: "Interactive Elixir (0.9.4-dev) - (type h() ENTER for help)"
    });
}

$(document).ready(function() {
    $("#tutorial").load("static/intro.html");
    shell();
});
