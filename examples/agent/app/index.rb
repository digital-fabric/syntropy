layout = import '_layout/default'

require 'papercraft/version'

export layout.apply {
  header {
    h1 'Fake-MCP Agent test'
  }
  main {
  }
  template(id: 'template-prompt-form') {
    form(id: 'prompt-form') {
      input type: 'text', id: 'prompt-text', minlength: 5, required: true, value: 'Give me all alarms'
      button "Submit", type: 'submit', id: 'prompt-submit'
    }
  }
  # script(src: '/assets/minigfm.js' )
  script(src: '/assets/agent_new.js', type: 'module')
}
