// feed_test.ino - constant-speed feed driver for Test 1 (feed rig)
// Board: any Arduino or ESP32. Driver: TMC2209 in standalone STEP/DIR mode.
//
// Serial at 115200 baud, one command per line:
//   v <mm/s>   set paper speed (default 60)
//   r          run continuously
//   f <mm>     feed a fixed distance, then stop
//   x          stop
//   d          reverse direction (clears a jam)
//   ?          help

const int PIN_STEP = 2;
const int PIN_DIR  = 3;
const int PIN_EN   = 4;   // TMC2209 EN is active LOW

const float ROLLER_R_MM = 11.6; // "Effective roller radius: driven" in the SCAD report
const int   MICROSTEPS  = 8;    // TMC2209 standalone with MS1 = MS2 = GND on most boards; check yours
const float STEPS_PER_MM = 200.0 * MICROSTEPS / (2.0 * PI * ROLLER_R_MM);

const float START_SPEED = 10.0;  // mm/s
const float ACCEL       = 400.0; // mm/s^2

float speedMm = 60.0;
float cur = START_SPEED;
long stepsLeft = 0;
bool continuous = false;
bool dirFwd = true;
unsigned long lastStep = 0, lastUpdate = 0;

void help() {
  Serial.println(F("v <mm/s> | r | f <mm> | x | d | ?"));
  Serial.print(F("steps/mm = ")); Serial.println(STEPS_PER_MM, 3);
}

void setup() {
  pinMode(PIN_STEP, OUTPUT);
  pinMode(PIN_DIR, OUTPUT);
  pinMode(PIN_EN, OUTPUT);
  digitalWrite(PIN_EN, LOW);
  digitalWrite(PIN_DIR, dirFwd ? HIGH : LOW);
  Serial.begin(115200);
  help();
}

void handleSerial() {
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line.length() == 0) return;
  char c = line.charAt(0);
  float arg = line.substring(1).toFloat();
  switch (c) {
    case 'v': if (arg > 0) speedMm = arg; Serial.print(F("speed ")); Serial.println(speedMm); break;
    case 'r': continuous = true; Serial.println(F("run")); break;
    case 'f': continuous = false; stepsLeft = (long)(arg * STEPS_PER_MM); Serial.print(F("feed ")); Serial.println(arg); break;
    case 'x': continuous = false; stepsLeft = 0; Serial.println(F("stop")); break;
    case 'd': dirFwd = !dirFwd; digitalWrite(PIN_DIR, dirFwd ? HIGH : LOW);
              Serial.println(dirFwd ? F("dir fwd") : F("dir rev")); break;
    default:  help();
  }
}

void loop() {
  handleSerial();
  unsigned long now = micros();
  float dt = (now - lastUpdate) / 1e6;
  lastUpdate = now;

  if (!continuous && stepsLeft <= 0) { cur = START_SPEED; return; }

  cur = min(speedMm, cur + ACCEL * dt);
  unsigned long interval = (unsigned long)(1e6 / (cur * STEPS_PER_MM));
  if (now - lastStep >= interval) {
    digitalWrite(PIN_STEP, HIGH);
    delayMicroseconds(3);
    digitalWrite(PIN_STEP, LOW);
    lastStep = now;
    if (!continuous) stepsLeft--;
  }
}
