var tutorialActive = false;
var currentPage = 0;
var tutorialPages = [
    "t1.html",
    "t2.html",
    "t3.html"
];

function changeTutorial(index) {
    $("#tutorial").fadeOut("fast", function() {
        $("#tutorial").load("tutorial/" + tutorialPages[index]);
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
            break;
        case ":prev":
            if (tutorialActive && currentPage > 0)
                goToPage(currentPage - 1);
            break;
        case ":restart":
            if (tutorialActive)
                goToPage(0);
            break;
        case ":clear":
            shell();
            return true;
        case ":start":
            tutorialActive = true;
            goToPage(0);
            break;
    }
    return line;
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
    $("#tutorial").load("intro.html");
    shell();
});
