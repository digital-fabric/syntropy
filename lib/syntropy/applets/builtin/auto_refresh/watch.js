(() => {
  const jsURL = document.currentScript.src;
  const sseURL = jsURL.replace(/\.js$/, '.sse');
  const eventSource = new EventSource(sseURL);

  eventSource.addEventListener('message', (msg) => {
    if (msg.data != '') window.location.reload();
  })
  eventSource.addEventListener('error', () => {
    console.log(`Failed to connect to auto refresh watcher (${sseURL})`);
  })
})()
