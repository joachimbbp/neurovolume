import numpy as np
from enum import Enum

class GridType(Enum):
    '''
    These are the default grid types for OpenVDB.
    More information can be found here: https://www.openvdb.org/documentation/doxygen/python.html
    '''
    FloatGrid = "FloatGrid"
    BoolGrid = "BoolGrid"
    Vec3SGrid = "Vec3SGrid"

class Grid:
    def __init__(self, name: str, frames: list[np.matrix], grid_type: GridType, color: tuple,
                tolerance_override=DEFAULT_TOLERANCE):
        self.name = name
        self.frames = frames
        self.grid_type = grid_type.value
        self.color = color
        self.grid_class = "FOG_VOLUME" #TODO find out other, possibly better, grid_classes
        self.modifiers = [] #TODO modifier stack, start with blur or something

    #TODO initialize a grid just from a NiFTY File
    def __str__(self):
        return f"grid: {self.name}"
    
class Scivol:
    '''
    Note there is strictly no special characters in Scivol or it's child grids
    Presently we only use one affine and tolerance per scivol which affects every grid.
    '''
    def __init__(self, name:str, affine: np.matrix, tolerance:float):
        self.name = name
        self.affine = affine
        self.tolerance = tolerance
        self.grids = []
    def __str__(self):
        return f"Scivol: {self.name}, Tolerance: {self.tolerance}, Grids: {self.grids}"
    def add_grid(self, grid:Grid):
        self.grids += grid
    def write_scivol(self):
        header = f"NAME:={self.name}|TOLERANCE:={self.tolerance}|AFFINE:={self.affine}|,"
        grids = ""
        for grid in self.grids:
            grids += f"name:{grid.name}$grid_type:{grid.grid_class}$color:{grid.color}$modifiers:{grid.modifiers}$frames:{grid.frames}"
        return header+grids
    def save_scivol(self, output_folder):
        with open(f"{output_folder}/{self.name}.scivol", 'w') as f:
            f.write(self.write_scivol(self))