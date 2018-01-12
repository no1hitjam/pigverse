'use strict';

const express = require('express');
const SocketServer = require('ws').Server;
const path = require('path');
var redis = require('redis');

const PORT = process.env.PORT || 3000;

const server = express()
  .use(express.static(path.join(__dirname, '/public')))
  .listen(PORT, () => console.log(`Listening on ${ PORT }`));

const wss = new SocketServer({ server });

var client = redis.createClient(process.env.REDISCLOUD_URL, {no_ready_check: true});

wss.on('connection', (ws) => {
  console.log('Client connected');
  ws.on('message', (data) =>
  {
    console.log('Client message ' + data + ' received');
    if (!check_kill(data)) {
      broadcast(data);
    }
  }); 
  ws.on('close', () => console.log('Client disconnected'));
});

function broadcast(data)
{
	wss.clients.forEach((client) =>
	{
    client.send(data);
  });
}

function check_kill(data) {
  if (data === 'server_kill') {
    client.get('kills', function(err, reply) {
      if (err) {
        return;
      }
      // increment kills and send to server
      var kills = parseInt(reply);
      if (kills === NaN) {
        kills = 0;
      }
      kills++;
      client.set('kills', kills);
      // send kills to clients
      broadcast('server_killCount_' + kills);
    });
    return true;
  }
  return false;
}

/*client.set('foo', 'bar');
client.get('foo', function (err, reply) {
  console.log(reply.toString()); // Will print `bar`
});*/