const express = require('express');
const redis = require('redis');

const app = express();
const client = redis.createClient({
	host: 'redis-server',
	port: 6379
});
client.set('users', 0);

app.get('/', (req, res) => {
  client.get('users', (err, users) => {
    res.send('Access user count is: ' + users);
    client.set('users', parseInt(users) + 1);
  });
});

app.listen(8080, () => {
  console.log('Listening on port 8080');
});