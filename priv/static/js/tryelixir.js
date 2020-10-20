var tutorialActive = false;
var currentPage = 0;
var guideDirectory = (() => {
  try {
    var lang = (navigator.browserLanguage || navigator.language || navigator.userLanguage).substr(0, 2);
    return $.inArray(lang, ['ja']) == -1 ? 'en/' : lang + '/';
  } catch (e) { }
  return '';
})();

var tutorialPages = [
  {
    guide: "intro.html",
    trigger: (_line, _result) => false
  },
  {
    guide: "t1.html",
    trigger: (_line, result) => (result === "12")
  },
  {
    guide: "t2.html",
    trigger: (_line, result) => (result === "4")
  },
  {
    guide: "t3.html",
    trigger: (_line, result) => (result.charAt(0) === ":")
  },
  {
    guide: "t4.html",
    trigger: (line, result) => (line.substring(0, 8) === "put_elem" && result.charAt(0) === "{")
  },
  {
    guide: "t5.html",
    trigger: (_line, result) => (result === ":ok")
  },
  {
    guide: "t6.html",
    trigger: (_line, result) => (result === "[97, 98, 99, 1]")
  },
  {
    guide: "t7.html",
    trigger: (line, result) => (line === "age" && result.substring(0, 2) !== "**")
  },
  {
    guide: "t8.html",
    trigger: (_line, result) => (result === ":ok")
  },
  {
    guide: "t9.html",
    trigger: (_line, result) => (result === ":ok")
  },
  {
    guide: "t10.html",
    trigger: (_line, result) => (result === ":ok")
  },
  {
    guide: "t11.html",
    trigger: (_line, result) => (result === ":ok")
  },
  {
    guide: "end.html",
    trigger: (_line, _result) => {
      tutorialActive = false;
      return false;
    }
  }
];

// Removes <tab> and decodes html entities
function decode(line) {
  var temp = $("<div/>").html(line).text();
  var temp2 = temp.replace("<tab>", "");
  var decoded = temp2.replace("</tab>", "");
  return decoded;
}

function makeCodeClickable() {
  $('pre').each(() => {
    $(this).attr('title', 'Click me to insert in the console.');
    $(this).click((e) => {
      if (e.button == 0) {
        controller.promptText($(this).text());
        controller.inner.click();
      }
    });
  });
  $('code').each(() => {
    $(this).attr('title', "Click me to insert '" + $(this).text() + "' in the console.");
    $(this).click((e) => {
      if (e.button == 0) {
        controller.promptText($(this).text());
        controller.inner.click();
      }
    });
  });
}

function animate(page) {
  $("#tutorial").fadeOut("fast", function () {
    $(this).load(page, function () {
      makeCodeClickable();
      $(this).fadeIn("fast");
    });
  });
}

function goToPage(number) {
  if (number < tutorialPages.length && number >= 0) {
    currentPage = number;
    animate("static/tutorial/" + guideDirectory + tutorialPages[number].guide);
  }
}

$(document).ready(() => {
  var console = $("#console");
  controller = console.console({
    promptLabel: "iex(1)> ",
    commandValidate: (input) => (input.length < 1000),
    commandHandle: (line, report) => {
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
          animate("static/tutorial/" + guideDirectory + "steps.html");
          report("");
          return;
        default:
          m = line.match(/^:step(\d+)/);
          if (m) {
            page = Number(m[1]);
            if (page >= 1 && page <= 11) {
              tutorialActive = true;
              goToPage(page);
              report("");
              return;
            }
          }
          $.ajax({
            "type": "POST",
            "url": "/api/eval",
            "data": { "code": line },
            "dataType": "json",
            "success": (json) => {
              obj = JSON.parse(json);
              controller.promptLabel = obj.prompt;
              // If there's no result, just print prompt and keep adding new input
              if (obj.result == undefined) {
                report();
              } else {
                if (obj.type == "ok") {
                  report([{ msg: obj.result, className: "jquery-console-message-success" }]);
                } else {
                  report([{ msg: obj.result, className: "jquery-console-message-error" }]);
                }
                if (tutorialActive && tutorialPages[currentPage].trigger(line, obj.result)) {
                  goToPage(currentPage + 1);
                }
              }
            },
            "error": (_jqXHR, status, _error) => {
              report([{ msg: status, className: "jquery-console-message-error" }]);
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
  $("#tutorial").load("static/tutorial/" + guideDirectory + "intro.html", function () {
    makeCodeClickable();
  });
});
