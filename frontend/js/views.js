function incrementCount() {
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function () {
      if (this.readyState === 4 && this.status === 200) {
          fetchCount(); // Refresh the count after incrementing
      }
  };
  xhttp.open("POST", "https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod/lambdaddb", true);
  xhttp.send();
}

function fetchCount() {
  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function () {
      if (this.readyState === 4 && this.status === 200) {
          document.getElementById("visits").innerHTML = xhttp.responseText;
      }
  };
  xhttp.open("GET", "https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod/lambdaddb", true);
  xhttp.send();
}

// Increment the count with the POST method to the API
incrementCount();

// Fetch the count
fetchCount();