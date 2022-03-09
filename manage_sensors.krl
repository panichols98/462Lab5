ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares sensors, sensorProfile, getTemps, allTemps
  }
  global {
    absoluteUrl = "file:///Users/parkernichols/Desktop/CS462/462Lab5/"

    sender = meta:rulesetConfig{"sender"}
    aToken = meta:rulesetConfig{"aToken"}
    sid = meta:rulesetConfig{"sid"}
    notificationNumber = meta:rulesetConfig{"to"}

    clear_sensors = { "name": "eci" }

    sensors = function() {
      ent:sensors
    }

    sensorProfile = function(name) {
      wrangler:picoQuery(ent:sensors{name},"sensor_profile","profile",{})
    }

    getTemps = function(name) {
      wrangler:picoQuery(ent:sensors{name},"temperature_store","temps",{})
    }

    allTemps = function() {
      ent:sensors.map(function(v,k) {
        wrangler:picoQuery(v,"temperature_store","temps",{})
      })
    }
  }
  rule add_sensor {
    select when sensor new_sensor
    pre {
      name = event:attrs{"name"}
      exists = ent:sensors && ent:sensors >< name
    }
    if not exists then noop()
    fired {
      raise wrangler event "new_child_request"
          attributes { "name": name, "backgroundColor": "#ff69b4" }
    }
  }
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attrs{"name"}
      exists = ent:sensors >< name
      eci_to_delete = ent:sensors{name}
    }
    if exists && eci_to_delete then
      send_directive("deleting_sensor", {"name":name})
    fired {
      raise wrangler event "child_deletion_request"
        attributes {"eci": eci_to_delete};
      clear ent:sensors{name}
    }
  }
  rule trigger_sensor {
    select when sensor reading_wanted
    pre {
      name = event:attrs{"name"}
      exists = ent:sensors >< name
      childEci = ent:sensors{name}
    }
    if exists then
      event:send(
          { "eci": childEci,
            "eid": "sensor_reading", // can be anything, used for correlation
            "domain": "emitter", "type": "new_sensor_reading",
          }
      )
  }
  rule install_emitter {
    select when wrangler child_initialized
    pre {
      childEci = event:attrs{"eci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "emulator",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "emitter_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_twilio {
    select when sensor emitter_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "twilio-sdk",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "twilio_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_profile {
    select when sensor twilio_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "sensor_profile",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "profile_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_store {
    select when sensor profile_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "temperature_module",
            "config": {},
          }
        }
    )
    fired {
      raise sensor event "store_installed"
          attributes { "childEci": childEci, "name": name }
    }
  }
  rule install_wovyn_base {
    select when sensor store_installed
    pre {
      childEci = event:attrs{"childEci"}
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": childEci,
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": absoluteUrl,
            "rid": "wovyn_base",
            "config": { "sid": sid, "aToken": aToken, "sender": sender },
          }
        }
    )
    fired {
      raise sensor event "base_installed" attributes { "childEci": childEci, "name": name }
    }
  }
  rule add_mapping {
    select when sensor base_installed
    pre {
      name = event:attrs{"name"}
      eci = event:attrs{"childEci"}
    }
    send_directive("sensor_added", {
      "name" : name,
      "eci": eci
    })
    always{
      ent:sensors := ent:sensors.defaultsTo(clear_sensors, "initialization was needed");
      ent:sensors{name} := eci
      raise sensor event "mapping_added" attributes {"name": name}
    }
  }
  rule set_profile {
    select when sensor mapping_added
    pre {
      name = event:attrs{"name"}
    }
    event:send(
        { "eci": ent:sensors{event:attrs{"name"}},
          "eid": "profile-update", // can be anything, used for correlation
          "domain": "sensor", "type": "profile_updated",
          "attrs": {
            "phone": notificationNumber,
            "name": name,
            "location": ""
          }
        }
    )
  }
  rule get_profile {
    select when manager profile_requested
    pre {
      eci = ent:sensors{event:attrs{"name"}};
      args = {}
      answer = wrangler:picoQuery(eci,"sensor_profile","profile",{}.put(args));
    }
    if answer{"error"}.isnull() then noop();
    fired {
      // process using answer
      answer = "profile: " + answer.klog("sensor profile ")
    }
}

  rule clear_sensors {
    select when sensor sensors_reset
    send_directive("Clear sensors")
    always{
      ent:sensors := {}
    }
  }
}
