const fs = require('fs');
const path = require('path');
const raw = fs.readFileSync(path.join(__dirname, '_vw_w_out.json'), 'utf8');
const data = JSON.parse(raw);
module.exports = data.statements;
