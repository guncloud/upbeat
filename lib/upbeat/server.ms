require('js-yaml');

var express = require('express');
var Service = require('./service');
var http    = require('http');
var Status  = require('./status');

export class Server {
  function initialize(file) {
    var config = require(file).shift();
    this.port  = config.port || '2468';
    this.host  = config.host || '127.0.0.1';

    this.services = {};
    this.servicesArray = [];
    for (var name in config.services) {
      var service = new Service(config.services[name]); 
      this.addService(name, service);
      this.servicesArray.push(service);
    }

    this._status = new Status();
  }

  function addService(name, service) {
    this.services[name] = service;
    service.name = name;
  }

  function getActions() {
    var ret = [];
    foreach (var s in this.servicesArray) {
      foreach (var a in s.actions) {
        ret.push(a);
      }
    }

    return ret;
  }

  function start() {
    if (this.app) this.app.close();

    for (var name in this.services) {
      this.services[name].start();
    }

    var $this = this;

    var app = express.createServer();
    app.configure(#{
      app.set("views", __dirname + "/views");
      app.use(express.static(__dirname + "/static"));
    });

    app.get("/", #(req, res) {
      res.render('status.jade', { services: $this.servicesArray });
    });


    app.get("/health", #(req, res) {
      res.writeHead(200, {"Content-type": "text/plain"});
      res.end("OK");
    });

    app.get("/health.strict", #(req, res) {
      var passed = true;
      foreach (var a in $this.getActions()) {
        if (! a.meta.up) {
          passed = false;
          break;
        }
      }

      res.writeHead(passed ? 200 : 400, {"Content-type": "application/json"});
      res.end($this._status.json($this.serviceArray));
    });


    app.get("/status.:format?", #(req, res) {
      if (req.params.format == 'json') {
        res.end($this._status.json($this.services));
      } else {
        res.render('status.jade', { services: $this.servicesArray });
      }
    });

    app.get("/:service", #(req, res) {
      var service = $this.services[req.params.service];
      if (! service) {
        res.send(404);
      } else {
        service.respond(res);
      }
    });
    
    console.log('Starting upbeat app: http://' + this.host + ':' + this.port);

    app.listen(this.port);
    this.app = app;
  }

  function stop() {
    if (this.app) this.app.close();
  }
}