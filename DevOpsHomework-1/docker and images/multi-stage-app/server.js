const express = require("express");

const app = express();
const PORT = 8080;

app.get("/", (req, res) => {
  res.send(`<!DOCTYPE html>
<html>
<head><title>Multi-Stage Build</title></head>
<body>
  <h1>Hello World from Docker multi-stage build</h1>
</body>
</html>`);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
