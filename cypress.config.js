const { defineConfig } = require("cypress");

module.exports = defineConfig({
  projectId: "wnqnyx",
  video: false,
  e2e: {
    baseUrl: "https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod",
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
  },
});
