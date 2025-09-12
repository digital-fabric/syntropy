import JSONAPI from '/.syntropy/json_api.js'

(() => {
  const api = new JSONAPI('/counter_api');

  const value = document.querySelector('#value');
  const decr  = document.querySelector('#decr');
  const incr  = document.querySelector('#incr');

  decr.addEventListener('click', async () => {
    const result = await api.post('decr')
    value.innerText = String(result);
  });

  incr.addEventListener('click', async () => {
    const result = await api.post('incr')
    value.innerText = String(result);
  });

})()
