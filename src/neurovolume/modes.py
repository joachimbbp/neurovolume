from enum import IntEnum

# TODO: source type should eventually go here!


class Interpolation(IntEnum):
    direct = 0  # write source frames straight to disk
    frozen = 1  # single 3D frame held for the entire output runtime
    fade = 2  # cross-fade between source frames to stretch runtime
