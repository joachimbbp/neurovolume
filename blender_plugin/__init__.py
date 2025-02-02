bl_info = {
    "name": "Neurovolume",
    "author": "Joachim Pfefferkorn",
    "description": "",
    "blender": (2, 80, 0),
    "version": (0, 0, 1),
    "location": "",
    "warning": "",
    "category": "Generic",
}

print("Neurovolume is running")
import bpy
import numpy as np
import pyopenvdb as vdb
import numpy as np
import os
import pathlib

#------------------------------------------------------------------------------
#                                   Backend Functions
#------------------------------------------------------------------------------

def load_npy(npy, data_folder):
    print(f"Loading in {npy}")
    try:
        return np.load(f"{data_folder}/{npy}")
    except:
        return "LOAD_ERROR"

def generate_vdb_frame(basename, volume, save_dir):
    print(f"Generating vdb for {basename}")
    grid = vdb.DoubleGrid()
    grid.copyFromArray(volume.astype(float))
    grid.gridClass = vdb.GridClass.FOG_VOLUME
    grid.name='density'
    output_path = f"{save_dir}/{basename}.vdb"
    vdb.write(output_path,grid)
    print(f"VDB written to {output_path}")
    return output_path

def static_vdb_from_npy(np_vol, basename, data_folder):
    print("Static vdb from npy")
    return generate_vdb_frame(basename, np_vol, data_folder) #just saving to same folder for now
    
def vdb_seq_from_npy(np_vol, basename, data_folder):
    print("VDB seq fron npy")
    seq_folder = f"{data_folder}/{basename}_seq" #huge quick hack fix later
    #TODO better handling if the folder already exists
    os.mkdir(seq_folder)
    sequence = np_vol
    for frame_idx in range(sequence.shape[3]):
        frame_filename = f"bold_{frame_idx}"
        generate_vdb_frame(frame_filename, sequence[:,:,:,frame_idx], save_dir=seq_folder)
    return seq_folder

def read_volumes(data_folder: str):
    #TODO method of subtraction for fMRI sequences
    """""
    folder_path: folder containing properly named .npy files
    """""
    print(f"searching in {data_folder}")

    vdb_paths = []

    for npy in os.listdir(data_folder):
        name = pathlib.Path(f"{data_folder}/{npy}").name #TEMP
        print(f"name {name}")
        basename, extension = name.split('.')
        print(f"basename: {basename}, extension: {extension}") #TEMP DEBUG
        if extension == "npy":
            np_vol = load_npy(npy, data_folder)
            if type(np_vol) != np.ndarray:
                print(f"{name} not loaded, error loading .npy file. volume is of type {np_vol.type()}")
                continue
            elif len(np_vol.shape) == 3:
                print(f"reading in 3D vol {npy}")
                vdb_paths.append(static_vdb_from_npy(np_vol, basename, data_folder))
            elif len(np_vol.shape) == 4:
                print(f"reading in 4D vol {npy}")
                vdb_paths.append(vdb_seq_from_npy(np_vol, basename, data_folder))
            else:
                print(f"invalid size: {name} is {len(np_vol.shape)} dimensions")
                continue
    print(f"All volumes read in:\n paths: {vdb_paths} ")
    return vdb_paths

def import_VDBs(vdb_paths):
    for vdb_filepath in vdb_paths:
        #bpy.ops.object.volume_import(filepath="/Users/joachimpfefferkorn/repos/neurovolume/output/anat.vdb", directory="/Users/joachimpfefferkorn/repos/neurovolume/output/", files=[{"name":"anat.vdb", "name":"anat.vdb"}], relative_path=True, align='WORLD', location=(0, 0, 0), scale=(1, 1, 1))
        # fullname = os.path.basename(vdb_filepath)
        # print("fullname ", fullname, "vdb filepath: ", vdb_filepath)
        # filename, basename = fullname.split(".")
        
        if os.path.isdir(vdb_filepath):
            print(f"VDB sequence detected at {vdb_filepath}. This function is not implemented yet")

        elif os.path.basename(vdb_filepath).split('.')[1] == "vdb":
            print("Static VDB file detected")
            name = os.path.basename(vdb_filepath)#.split('.')[0] #this feels a little clunky and error prone?
            try:
                bpy.ops.object.volume_import(filepath=vdb_filepath, directory=os.path.dirname(vdb_filepath), files=[{"name":name}], relative_path=True, align='WORLD', location=(0, 0, 0), scale=(1, 1, 1))
            except:
                print(f"{vdb_filepath} could not be loaded")
        else:
            print(f"invalid filepath {vdb_filepath}")
            continue

#------------------------------------------------------------------------------
#                                   GUI Functions
#------------------------------------------------------------------------------


#--------
# Classes
#--------
class Neurovolume(bpy.types.Panel):
    """Main Neurovolume Panel"""
    bl_label = "Neurovolume"
    bl_idname = "VIEW3D_PT_nv"
    bl_space_type = "VIEW_3D" #in the 3D viewport
    bl_region_type = "UI" #in the UI panel
    bl_category = "Neurovolume" #name of panel
    
    def draw (self, context):        
        self.layout.prop(context.scene, "path_input")
        self.layout.operator("load.volume", text="Load .npy Files as VDBs")

class LoadVolume(bpy.types.Operator):
    """Load in NPY file and convert it to VDB"""
    bl_idname = "load.volume" #ugh why are these conventions different?
    bl_label = "Load Volume"
    
    def execute(self, context):
        #For now we are just going to print what is input
        folder_path = context.scene.path_input
        print(f"Entered Path: {folder_path}")
        paths = read_volumes(folder_path)
        import_VDBs(paths)

        self.report({'INFO'}, "VDBs loaded into scene")
        return {"FINISHED"}

#----------------------
# Property Registration
#----------------------
def register_properties():
    bpy.types.Scene.path_input = bpy.props.StringProperty(
        name="NPY Folder",
        description="Enter path to folder containing .npy files",
        default=""
        )
        
def unregister_properties():
    del bpy.types.Scene.path_input
#-------------
# Registration
#-------------
classes = [Neurovolume, LoadVolume]

def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    register_properties()
    
def unregister():
    for cls in classes:
        bpy.utils.unregister_class(cls)
    unregister_properties()

if __name__ == "__main__":
    register()

#------------------------------------------------------------------------------
#                                   Control Flow
#------------------------------------------------------------------------------

