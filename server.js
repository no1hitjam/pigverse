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

wss.on('connection', (ws) => {
  console.log('Client connected');
  ws.on('message', (data) =>
  {
    console.log('Client message ' + data + ' received');
    broadcast(data);
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


var client = redis.createClient(process.env.REDISCLOUD_URL, {no_ready_check: true});

client.set('foo', 'bar');
client.get('foo', function (err, reply) {
    console.log(reply.toString()); // Will print `bar`
});