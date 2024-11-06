import numpy as np
from enum import Enum
import json
import gzip

np.set_printoptions(threshold=np.inf, linewidth=np.inf)

class GridType(Enum):
 
    # These are the default grid types for OpenVDB.
    # More information can be found here: https://www.openvdb.org/documentation/doxygen/python.html

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

    def to_dict(self):
        print(f"writing {self.name} to grid")
        content =  {
            "frames": [frame.tolist() for frame in self.frames],  # Convert numpy arrays to lists
            "grid_type": self.grid_type,
            "color": self.color,
            "grid_class": self.grid_class,
            "modifiers": self.modifiers
        }
        return content
    
class Scivol:

    # Note there is strictly no special characters in Scivol or it's child grids
    # Presently we only use one affine and tolerance per scivol which affects every grid.
    # Using ANTS, it seems like we don't need an affine, so we are setting this just as an identity matrix.
    # This is just incase we need an affine in the future for some reason.

    def __init__(self, name:str, tolerance = 0.0, affine = np.eye(4),):
        self.name = name
        self.affine = affine
        self.tolerance = tolerance
        self.grids = {}
    def add_grids(self, grids:[Grid]):
        for grid in grids:
            self.grids[grid.name] = grid.to_dict()
    def write_scivol(self):
        print(f"writing {self.name} scivol dictionary")
        content = {
        'name' : self.name,
        'tolerance' : self.tolerance,
        'affine' : self.affine.tolist(),
        'grids' : self.grids #self.grids
        }
        #print(content)
        return content

    def save_scivol(self, output_folder, filename = ""):
        if filename == "":
            filename = self.name
        json_str = json.dumps(self.write_scivol())
        print("Encoding JSON file to utf-8")
        json_bytes = json_str.encode('utf-8')
        print(f"saving {filename}.scivol to {output_folder}")
        with gzip.open(f"{output_folder}/{filename}.scivol", "wb") as svgz:
            svgz.write(json_bytes)

    def __str__(self):
        string = f"{self.name}\ntolerance: {self.tolerance}\naffine: {self.affine}\ngrids:\n"
        for g in self.grids:
            string += f"    - {g}\n"
        return string