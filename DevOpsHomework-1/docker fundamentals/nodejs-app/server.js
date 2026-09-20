const express = require("express");

const app = express();
const PORT = 3000;

app.get("/", (req, res) => {
  res.send(`<!DOCTYPE html>
<html>
<head><title>Node.js Hello World</title></head>
<body>
  <h1>Hello World from Node.js + Docker!</h1>
</body>
</html>`);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
