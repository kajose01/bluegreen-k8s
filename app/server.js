const http = require('http');
const fs = require('fs');
const { version } = JSON.parse(fs.readFileSync(__dirname + '/version.json', 'utf8'));

http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200); return res.end('ok');
  }
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ app: 'bluegreen-demo', version, pod: process.env.HOSTNAME }) + '\n');
}).listen(3000, () => console.log(`bluegreen-demo ${version} listening on 3000`));
