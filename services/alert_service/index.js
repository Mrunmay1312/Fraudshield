const express = require('express');
const app = express();
app.use(express.json());
app.post('/alert', (req, res) => {
  const payload = req.body;
  console.log('ALERT:', payload);
  res.json({status:'sent', payload});
});
const port = process.env.PORT || 3000;
app.listen(port, () => console.log('Alert service on port', port));
