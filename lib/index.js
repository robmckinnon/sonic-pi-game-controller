const ds = require('dualshock');
const osc = require('osc');
const debug = false;

var udpPort = new osc.UDPPort({
    // This is the port we're listening on.
    localAddress: "127.0.0.1",
    localPort: 57121,

    // This is where sonicpi is listening for OSC messages.
    remoteAddress: "127.0.0.1",
    remotePort: 4559,
    metadata: true
});
udpPort.open();

var nLedVal = 0;
begin();

// Quit by typing "exit"
function waitForExit() {
	process.stdin.resume();
	process.stdin.setEncoding('utf8');
	process.stdin.on('data', function(text) {
		while(text.search('\n') != -1) text = text.substring(0, text.search('\n'));
		while(text.search('\r') != -1) text = text.substring(0, text.search('\r'));
		if(text == "exit" || text == "quit") {
			console.log("Exiting...");
			process.exit();
		}
	});
}

// const OSC_BUTTON_INVALID = "/bi";
const OSC_BUTTON_A = "/b/a"; // X
const OSC_BUTTON_B = "/b/b"; // CIRCLE
const OSC_BUTTON_X = "/b/x"; // SQUARE
const OSC_BUTTON_Y = "/b/y"; // TRIANGLE
const OSC_BUTTON_BACK = "/b/back"; // SHARE
const OSC_BUTTON_GUIDE = "/b/guide"; // ON_BUTTON
const OSC_BUTTON_START = "/b/start"; // OPTIONS
const OSC_BUTTON_LEFTSTICK = "/b/leftstick"; // LEFT_ANALOG_PRESS
const OSC_BUTTON_RIGHTSTICK = "/b/rightstick"; // RIGHT_ANALOG_PRESS
const OSC_BUTTON_LEFTSHOULDER = "/b/leftshoulder";
const OSC_BUTTON_RIGHTSHOULDER = "/b/rightshoulder";
const OSC_BUTTON_LEFTTRIGGER = "/b/lefttrigger";
const OSC_BUTTON_RIGHTTRIGGER = "/b/righttrigger";
const OSC_BUTTON_DPAD_UP = "/b/dpup";
const OSC_BUTTON_DPAD_DOWN = "/b/dpdown";
const OSC_BUTTON_DPAD_LEFT = "/b/dpleft";
const OSC_BUTTON_DPAD_RIGHT = "/b/dpright";
// const OSC_BUTTON_MAX = "/bm";

// const OSC_AXIS_INVALID = "/ai";
const OSC_AXIS_LEFTX = "/a/leftx";
const OSC_AXIS_LEFTY = "/a/lefty";
const OSC_AXIS_RIGHTX = "/a/rightx";
const OSC_AXIS_RIGHTY = "/a/righty";
const OSC_AXIS_TRIGGERLEFT = "/a/lefttrigger";
const OSC_AXIS_TRIGGERRIGHT = "/a/righttrigger";
// const OSC_AXIS_MAX = "/am";

const mapping = {
  a: OSC_BUTTON_A,
  b: OSC_BUTTON_B,
  x: OSC_BUTTON_X,
  y: OSC_BUTTON_Y,
  up: OSC_BUTTON_DPAD_UP,
  down: OSC_BUTTON_DPAD_DOWN,
  left: OSC_BUTTON_DPAD_LEFT,
  right: OSC_BUTTON_DPAD_RIGHT,
  l1: OSC_BUTTON_LEFTSHOULDER,
  l2: OSC_BUTTON_LEFTTRIGGER,
  l3: false,
  r1: OSC_BUTTON_RIGHTSHOULDER,
  r2: OSC_BUTTON_RIGHTTRIGGER,
  r3: false,
  select: OSC_BUTTON_BACK,
  start: OSC_BUTTON_START,
  ps: OSC_BUTTON_GUIDE,
  pad: false,
  t1: true,
  t2: true
};
const previous = {};

function send_osc(key, val) {
  if (val !== null) {
    if (val !== previous[key]) {
      udpPort.send({address: mapping[key], args: [{type: "i", value: val}]});
    }
    previous[key] = val;
  }
};

function begin() {
	waitForExit();

	//Get list of devices. Accepts optional string to filter by type.
	var list = ds.getDevices();
	if (list.length < 1) {
		console.log("Could not find a controller!");
		process.exit();
	}
	console.log("Devices:", list);


	var device = list[0];
	var gamepad = ds.open(device, {
		smoothAnalog: 10,
		smoothMotion: 15,
		joyDeadband: 5,
		moveDeadband: 5
	});

	gamepad.onmotion = true;
	gamepad.onstatus = true;
  gamepad.setLed(1,1,1);

	//DS4 Only: Random LED Stuffs:
	// setInterval(function() {
	// 	gamepad.setLed(
	// 		Math.floor(Math.random()*255),
	// 		Math.floor(Math.random()*255),
	// 		Math.floor(Math.random()*255)
	// 	);
	// }, 100);

	gamepad.onupdate = function(changed) {
		// rumbleScript(changed, this);
		//Uncomment one of these lines for debugging!
    const dig = this.digital;
    const ana = this.analog;
    Object.keys(changed).forEach(function (key) {
      switch(key) {
        case "rStickY":
        case "rStickX":
        case "lStickY":
        case "lStickX":
          // console.log(changed);
          console.log(key, ana[key]);
          break;
        case "r2":
        case "l2":
          let val;
          const pressed = dig[key];
          if (!pressed) {
            val = 0;
          } else if (pressed) {
            if (ana[key] === 255) {
              val = 1;
            } else {
              val = 0;
            }
          }
          send_osc(key, val);
          break;
        default:
          if (dig.hasOwnProperty(key)) {
            console.log([key,dig[key]]);
            if(mapping[key]) {
              console.log(mapping[key],dig[key]);
              let val;
              if (dig[key]) {
                val = 1;
              } else {
                val = 0;
              }
              send_osc(key, val);
            }
          }
      }
    });
		// console.log(this.digital);
		// console.log(this.analog);
		//console.log(this.motion,this.status);
	}


	function rumbleScript(chg, g) {
		//Rumble On:
		if(chg.l2 || chg.r2) { g.rumbleAdd(g.analog.l2?g.analog.l2:-1, g.analog.r2?255:-1, 254, 254); console.log("rumble set", [g.analog.l2,(g.analog.r2>0)?255:0]); }
		else if(chg.l3 && g.digital.l3) { g.rumbleAdd(94, 0, 255, 0); console.log("rumble slow"); }
		else if(chg.start && g.digital.start) { g.rumbleAdd(0, 255, 0, 5); console.log("rumble tap"); }
		//Rumble Off:
		if((chg.l2 || chg.r2 || chg.l3 || chg.start) && !(g.analog.l2 || g.analog.r2 || g.digital.l3 || g.digital.start)) { g.rumble(0, 0); console.log("rumble off"); }
		//Change LED Pattern:
		if(chg.ps && g.digital.ps) { g.setLed(nLedVal); console.log("led set "+nLedVal); nLedVal++; if(nLedVal > 15) nLedVal = 0; }
	}

	//See how much easier this is with onupdate?
	//Some apps work well with ondigital & onanalog, while others work better using onupdate.
	//While we're at it, we also changed that first rumble to a rumbleAdd. (So it wont cancel any current rumbles already going on)
	//Setting a value to -1 in rumbleAdd overrides to 0 for that value, otherwise setting to 0 would not override any current value.

	//If gamepad is disconnected, exit application:
	gamepad.ondisconnect = function() {
		console.log(this.type.toUpperCase()+" disconnected!");
		process.exit();
	}

	//If any error happens, log it and exit:
	gamepad.onerror = function(error) {
		console.log(error);
		process.exit();
	}
}
