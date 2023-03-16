fetch('https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod/lambdaddb')
  .then(response => response.text())
  .then(visitorCount => {
    document.getElementById('visits').innerText = visitorCount;
  });
  