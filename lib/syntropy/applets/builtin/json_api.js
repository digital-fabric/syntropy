class JSONAPI {
  constructor(url) {
    this.url = url;
  }

  async get(q, params = {}) {
    return await this.#query('get', q, params);
  }

  async post(q, params = {}) {
    return await this.#query('post', q, params);
  }

  async #query(method, q, params = {}) {
    const url = `${this.url}?q=${q}`;
    const req = fetch(url, {
      method: method
    });
    const response = await req;
    if (!response.ok)
      throw new Error(`Response status: ${response.status}`)

    const result = await response.json();
    return result.response;
  }
}

export default JSONAPI;