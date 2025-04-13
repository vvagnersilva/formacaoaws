const express = require("express");
const app = express();
const port = 3000;

app.get("/", (req, res) => {
  res.send("Hello World, Wagner!");
  console.log(`${new Date().toISOString()}: Chegou request`);
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});
