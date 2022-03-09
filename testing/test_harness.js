import axios from "axios"

async function createSensor(name) {
  let url = "http://localhost:3000/sky/event/cl0imgj1500nzj5uoe6144jjf/1556/sensor/new_sensor"
  let response = await axios.post(url, {
    name: name
  });
  if (response.status == 200) {
    console.log(name + " added");
  }
}

async function testSensorCreation() {
  await createSensor("test1");
  await createSensor("test2");
}

async function getSensors() {
  let url = "http://localhost:3000/sky/cloud/cl0imgj1500nzj5uoe6144jjf/manage_sensors/sensors";
  let response = await axios.get(url);
  if (response.status == 200) {
    return response.data
  } else {
    console.log("error getting sensors");
    return {}
  }
}

async function deleteSensor(name) {
  let url = "http://localhost:3000/sky/event/cl0imgj1500nzj5uoe6144jjf/1556/sensor/unneeded_sensor";
  let response = await axios.post(url, {
    name: name
  });
  if (response.status == 200) {
    console.log(name + " deleted");
  }
  else {
    console.log("error deleting " + name);
  }
}

async function sensorReadings(name) {
  let url = "http://localhost:3000/sky/cloud/cl0imgj1500nzj5uoe6144jjf/manage_sensors/getTemps?name=" + name;
  let response = await axios.get(url);
  if (response.status == 200) {
    return response.data
  } else {
    console.log("error getting sensors");
    return {}
  }
}

async function triggerReading(name) {
  let url = "http://localhost:3000/sky/event/cl0imgj1500nzj5uoe6144jjf/1556/sensor/reading_wanted";
  let response = await axios.post(url, {
    name: name
  });
  if (response.status == 200) {
    console.log(name + " triggered");
  } else {
    console.log("error triggering reading");
  }
}

async function getSensorProfile(name) {
  let url = "http://localhost:3000/sky/cloud/cl0imgj1500nzj5uoe6144jjf/manage_sensors/sensorProfile?name=" + name;
  let response = await axios.get(url);
  if (response.status == 200) {
    return response.data
  } else {
    console.log("error getting profile");
    return {}
  }
}

const delay = ms => new Promise(res => setTimeout(res, ms));

async function testDriver() {
  await testSensorCreation();
  // wait a minute to make sure sensors are added
  await delay(1000);
  let sensors = await getSensors();
  console.log(sensors);

  await triggerReading("test1");

  await deleteSensor("test2");
  sensors = await getSensors();
  console.log(sensors);

  let temps = await sensorReadings("test1");
  console.log(temps);

  let profile = await getSensorProfile("test1");
  console.log(profile);
}

testDriver();
