window.addEventListener('load', function () {
  var scriptTag = document.createElement('script');
  scriptTag.src = 'main.dart.js';
  scriptTag.type = 'application/javascript';
  document.body.appendChild(scriptTag);
});
