from machine import Pin
import time

step = Pin(2, Pin.OUT)   # GP2 -> STEP
dir_ = Pin(3, Pin.OUT)   # GP3 -> DIR

STEPS_PER_REV = 200      # full step (M0-M2 open)
DELAY_US = 1000          # half-period; raise to 4000 if it stalls

def move(steps, direction):
    dir_.value(direction)
    time.sleep_us(5)               # DIR setup time before first STEP
    for _ in range(steps):
        step.on()
        time.sleep_us(DELAY_US)
        step.off()
        time.sleep_us(DELAY_US)

# while True:
#     move(STEPS_PER_REV, 1)
#     time.sleep(1)
#     move(STEPS_PER_REV, 0)
#     time.sleep(1)

for i in range(3):
    move(STEPS_PER_REV, 1)
    time.sleep(2)
    move(STEPS_PER_REV, 0)
    time.sleep(2)