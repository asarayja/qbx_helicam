HeliCam = {};

// Configurable throttling - this could be received from config if needed
let UPDATE_THROTTLE = 50; // Default 50ms, matches config.nui.updateThrottle
let lastUpdateTime = 0;

HeliCam.Open = () => {
  $("#helicontainer").css("display", "block");
  $(".scanBar").css("height", "0%");
}

HeliCam.UpdateScan = (data) => {
  const now = Date.now();
  if (now - lastUpdateTime < UPDATE_THROTTLE) return;
  
  $(".scanBar").css("height", data.scanvalue + "%");
  lastUpdateTime = now;
}

HeliCam.UpdateVehicleInfo = (data) => {
  const now = Date.now();
  if (now - lastUpdateTime < UPDATE_THROTTLE) return;
  
  $(".vehicleinfo").css("display", "block");
  $(".scanBar").css("height", "100%");
  $(".heli-model").find("p").html("MODEL: " + data.model);
  $(".heli-plate").find("p").html("PLATE: " + data.plate);
  $(".heli-street").find("p").html(data.street);
  $(".heli-speed").find("p").html(data.speed + " KM/U");
  lastUpdateTime = now;
}

HeliCam.DisableVehicleInfo = () => {
  $(".vehicleinfo").css("display", "none");
}

HeliCam.Close = () => {
  $("#helicontainer").css("display", "none");
  $(".vehicleinfo").css("display", "none");
  $(".scanBar").css("height", "0%");
  lastUpdateTime = 0; // Reset throttle timer
}

document.onreadystatechange = () => {
  if (document.readyState === "complete") {
      // Add event handler with error handling and message validation
      window.addEventListener('message', (event) => {
          try {
              if (!event.data || !event.data.type) return;
              
              switch(event.data.type) {
                  case "heliopen":
                      HeliCam.Open();
                      break;
                  case "heliclose":
                      HeliCam.Close();
                      break;
                  case "heliscan":
                      if (typeof event.data.scanvalue === 'number') {
                          HeliCam.UpdateScan(event.data);
                      }
                      break;
                  case "heliupdateinfo":
                      if (event.data.model && event.data.plate && 
                          event.data.street && typeof event.data.speed === 'number') {
                          HeliCam.UpdateVehicleInfo(event.data);
                      }
                      break;
                  case "disablescan":
                      HeliCam.DisableVehicleInfo();
                      break;
                  case "updateconfig":
                      // Update throttle value from config if provided
                      if (typeof event.data.throttle === 'number') {
                          UPDATE_THROTTLE = event.data.throttle;
                      }
                      break;
              }
          } catch (error) {
              console.error('Error handling message:', error);
          }
      });
  };
};

$(document).on('keydown', (event) => {
  switch(event.which) {
      case 27: // ESC
          Fingerprint.Close();
          break;
  }
});