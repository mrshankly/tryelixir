var tutorialActive = false;
var currentPage = 0;
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
        return (result.charAt(0) === "[");
    }},
    {guide: "t6.html",
     trigger:function(line, result){
        if (line === "age") {
            tutorialActive = false;
            goToPage(0);
        }
        return false;
    }}
];

function changeTutorial(index) {
    $("#tutorial").fadeOut("fast", function() {
        $("#tutorial").load("static/tutorial/" + tutorialPages[index].guide);
        $("#tutorial").fadeIn("fast");
    });
}

function goToPage(number) {
    if (number < tutorialPages.length && number >= 0) {
        currentPage = number;
        changeTutorial(number);
    }
}

$(document).ready(function() {
    $("#tutorial").load("static/tutorial/intro.html");
    var console = $("#console");
    var controller = console.console({
        promptLabel: "iex(1)> ",
        commandValidate: function(input) {
            return (input != "" && input.length < 1000);
        },
        commandHandle: function(line, report) {
            switch (line) {
                case ":next":
                    if (tutorialActive)
                        goToPage(currentPage + 1);
                    report([{msg:":next", className:"jquery-console-message-success"}]);
                    return;
                case ":prev":
                    if (tutorialActive)
                        goToPage(currentPage - 1);
                    report([{msg:":prev", className:"jquery-console-message-success"}]);
                    return;
                case ":restart":
                    if (tutorialActive)
                        goToPage(1);
                    report([{msg:":restart", className:"jquery-console-message-success"}]);
                    return;
                case ":clear":
                    controller.reset();
                    return;
                case ":start":
                    tutorialActive = true;
                    goToPage(1);
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
            return;
        },
        autofocus: true,
        animateScroll: true,
        promptHistory: true,
        welcomeMessage: "Interactive Elixir (" + version.dataset.version + ")"
    });
});
