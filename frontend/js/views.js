var xhttp = new XMLHttpRequest();
xhttp.onreadystatechange = function () {
    if (this.readyState === 4 && this.status === 200) {
        document.getElementById("visits").innerHTML = xhttp.responseText;
    }
};
xhttp.open("GET", "https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod/lambdaddb", true);
xhttp.send();