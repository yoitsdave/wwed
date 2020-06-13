export var IndexApp = {
  run: function() {

    var submit = document.getElementById('submit');
    var name = document.getElementById('name');
    var pwd = document.getElementById('pwd');

    name.oninput = function() { submit.action = "room/" + name.value + "?pwd=" + pwd.value};
    pwd.oninput = function() { submit.action = "room/" + name.value + "?pwd=" + pwd.value };

    pwd.addEventListener("keyup", function(event) {
      event.preventDefault();
      if (event.keyCode === 13) {
        document.getElementById("submit-btn").click();
      }
    });
  }
}
