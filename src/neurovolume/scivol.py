import numpy as np
from enum import Enum

np.set_printoptions(threshold=np.inf, linewidth=np.inf)


class GridType(Enum):
    '''
    These are the default grid types for OpenVDB.
    More information can be found here: https://www.openvdb.org/documentation/doxygen/python.html
    '''
    FloatGrid = "FloatGrid"
    BoolGrid = "BoolGrid"
    Vec3SGrid = "Vec3SGrid"

class Grid:
    def __init__(self, name: str, frames: list[np.ndarray], color: tuple=(0,0,0), grid_type: GridType=GridType.FloatGrid):
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
    def __init__(self, name:str, affine: np.ndarray, tolerance:float):
        self.name = name
        self.affine = affine
        self.tolerance = tolerance
        self.grids = []
    def add_grid(self, grid:Grid):
        self.grids.append(grid)
    def add_grids(self, grids:[Grid]):
        for grid in grids:
            self.add_grid(grid)
    def write_scivol(self):
        header = f"NAME:={self.name}|\nTOLERANCE:={self.tolerance}|\nAFFINE:={self.affine}|\n"
        grids = ""
        for grid in self.grids:
            grids += f"name:{grid.name}\n$grid_type:{grid.grid_class}\n$color:{grid.color}\n$modifiers:{grid.modifiers}\n$frames:{grid.frames}"
        return header+grids
    def save_scivol(self, output_folder):
        with open(f"{output_folder}/{self.name}.scivol", 'w') as f:
            f.write(self.write_scivol())
    def __str__(self):
        return self.write_scivol()