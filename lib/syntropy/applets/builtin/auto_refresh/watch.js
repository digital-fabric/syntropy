(() => {
  const js_url = document.currentScript.src;
  const sse_url = js_url.replace(/\.js$/, '.sse');
  const eventSource = new EventSource(sse_url);

  eventSource.addEventListener('message', (msg) => {
    if (msg.data != '') window.location.reload();
  })
  eventSource.addEventListener('error', () => {
    console.log(`Failed to connect to auto refresh watcher (${sse_url})`);
  })
})()
