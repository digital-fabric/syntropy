(() => {
  const jsURL = import.meta.url;
  const cssURL = jsURL.replace(/\.js$/, '.css');

  const head = document.querySelector('head');
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.type = 'text/css';
  link.href = cssURL;
  head.appendChild(link);



  let lastTarget = undefined;
  document.querySelectorAll('[data-syntropy-level]').forEach((ele) => {
    // ele.addEventListener('mouseover', (evt) => {
    //   if (evt.target != lastTarget) {

    //   }
    //   console.log(evt)
    // });

    // ele.addEventListener('mouseout', (evt) => {
    //   if (evt.target == last)
    // });

    const parent = ele.parentElement;
    const attachment = document.createElement('debug-attachment');
    const tag = ele.tagName;
    if (tag == 'SCRIPT' || tag == 'HEAD') return;

    const level = ele.dataset.syntropyLevel;
    const href = ele.dataset.syntropyLoc;
    const fn = ele.dataset.syntropyFn;

    let attachToParent = false; //(tag != 'BODY');

    if (level == '1') {
      const cleanFn = fn.match(/([^\/]+)$/)[0];
      attachment.innerHTML = `<debug-label class="fn"><a href="${href}">${cleanFn}</a></debug-label>`;
    }
    else {
      attachToParent = true;
      attachment.innerHTML = `<debug-label><a href="${href}">${tag}</a></debug-label>`;
    }

    // console.log(tag, attachToParent);
    if (attachToParent) {
      parent.style.position = 'relative';
      parent.prepend(attachment);
    }
    else {
      ele.style.position = 'relative';
      ele.prepend(attachment);
    }
  });
})()
