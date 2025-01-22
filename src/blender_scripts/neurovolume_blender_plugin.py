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

def load_vdb(npy, data_folder):
    print(f"Loading in {npy}")
    return np.load(f"{data_folder}/{npy}")

def generate_vdb_frame(basename, volume, save_dir):
    print(f"Generating vdb for {basename}")
    grid = vdb.DoubleGrid()
    grid.copyFromArray(volume.astype(float))
    grid.gridClass = vdb.GridClass.FOG_VOLUME
    grid.name='density'
    output_path = f"{save_dir}/{basename}.vdb"
    vdb.write(output_path,grid)
    print(f"VDB written to {output_path}")

def static_vdb_from_npy(npy, data_folder):
    print("Static vdb from npy")
    basename = os.path.basename(npy).split('.')[0]
    generate_vdb_frame(basename, load_vdb(npy, data_folder), data_folder) #just saving to same folder for now
    
def vdb_seq_from_npy(npy, data_folder):
    print("VDB seq fron npy")
    basename = os.path.basename(npy).split('.')[0]
    seq_folder = f"{data_folder}/{basename}_seq" #huge quick hack fix later
    os.mkdir(seq_folder)
    vdb_seq = load_vdb(npy, data_folder)
    for frame_idx in range(vdb_seq.shape[3]):
        frame_filename = f"bold_{frame_idx}"
        generate_vdb_frame(frame_filename, vdb_seq[:,:,:,frame_idx], save_dir=seq_folder)

def read_volumes(data_folder: str):
    """""
    folder_path: folder containing properly named .npy files
    """""
    print(f"searching in {data_folder}")
    for npy in os.listdir(data_folder):
        print(f"reading in {npy}")
        name = pathlib.Path(f"{data_folder}/{npy}").name
        if name == "anat.npy" or name == "mni_mask.npy" or name == "mni_template.npy":
            static_vdb_from_npy(npy, data_folder)
        if name == "bold_rest.npy" or name == "bold_stim.npy":
            vdb_seq_from_npy(npy, data_folder)
        else:
            print(f"invalid name: {name}, not loading")
# This is some of the worsrt code I have written
# but I was in a huge hurry
# TODO cleanup later            
        
    print("All volumes read in")


#------------------------------------------------------------------------------
#                                   GUI Functions
#------------------------------------------------------------------------------

#--------
# Setup
#--------
bl_info = {
    "name": "Neurovolume",
    }

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
        layout = self.layout
        scene = context.scene
        #redundant, or are these methods that
        #generate things and we thus need them?
        
        layout.prop(scene, "path_input")
        layout.operator("load.volume", text="Load.npy Files as VDBs")



class LoadVolume(bpy.types.Operator):
    """Load in NPY file and convert it to VDB"""
    bl_idname = "load.volume" #ugh why are these conventions different?
    bl_label = "Load Volume"
    
    def execute(self, context):
        #For now we are just going to print what is input
        folder_path = context.scene.path_input
        print(f"Entered Path: {folder_path}")
        read_volumes(folder_path)
        
        self.report({'INFO'}, "path printed to terminal")
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

