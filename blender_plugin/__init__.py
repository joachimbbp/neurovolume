#------------------------------------------------------------------------------
#                                   Setup
#------------------------------------------------------------------------------

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
import time

low_clip: float = 0.0

#------------------------------------------------------------------------------
#                                   Backend Functions
#------------------------------------------------------------------------------
def create_normalized_volume(normalized_tensor):
    print("Creating normalized Volume")
    def normalize_array(arr):
        return np.array((arr - np.min(arr)) / (np.max(arr) - np.min(arr)))
    mri_volume = np.zeros(normalized_tensor.shape)
    for z_index in range(normalized_tensor.shape[2]):
        print(f"     sagittal slice {z_index}/{normalized_tensor.shape[2]}")
        sagittal_slice = normalized_tensor[:, :, z_index]
        for row_index, row in enumerate(sagittal_slice):
            for col_index, _ in enumerate(row):
                density = sagittal_slice[row_index][col_index]
                mri_volume[row_index][col_index][z_index] = density
    return normalize_array(mri_volume)


def load_npy(npy, data_folder):
    print(f"Loading in {npy}")
    try:
        return np.load(f"{data_folder}/{npy}")
    except:
        return "LOAD_ERROR"

def generate_vdb_frame(basename, volume, save_dir):
    output_path = f"{save_dir}/{basename}.vdb"

    if os.path.exists(output_path):
        print(f"{basename} already exist, overwriting!")
        os.remove(output_path)
    if low_clip > 0.0:
        print(f'Clipping {basename} low density at {low_clip}')
        volume = create_normalized_volume(np.clip(volume, low_clip, None))

    print(f'vol range {volume.min()}-{volume.max()}')
    print(f'vol type: {type(volume)}')

    print(f"Generating vdb for {basename}")
    grid = vdb.DoubleGrid()
    grid.copyFromArray(volume.astype(float))
    grid.gridClass = vdb.GridClass.FOG_VOLUME
    grid.name='density'
    vdb.write(output_path,grid)
    print(f"VDB written to {output_path}")
    return output_path

def static_vdb_from_npy(np_vol, basename, data_folder):
    print("Static vdb from npy")
    return generate_vdb_frame(basename, np_vol, data_folder) #just saving to same folder for now
    
def vdb_seq_from_npy(np_vol, basename, data_folder):
    print("VDB seq fron npy")
    seq_folder = f"{data_folder}/{basename}_seq"
    if os.path.exists(seq_folder):
        print(f"{seq_folder} folder already exists")
        return seq_folder
    else:
        os.mkdir(seq_folder)
        sequence = np_vol
        for frame_idx in range(sequence.shape[3]):
            frame_filename = f"bold_{frame_idx}"
            generate_vdb_frame(frame_filename, sequence[:,:,:,frame_idx], save_dir=seq_folder)
        return seq_folder

def read_volumes(data_folder: str):
    """""
    folder_path: folder containing properly named .npy files
    """""
    print(f"searching in {data_folder}")

    vdb_paths = []
    start_time = time.time()
    for npy in os.listdir(data_folder):
        name = pathlib.Path(f"{data_folder}/{npy}").name #TEMP
        print(f"name {name}")
        try:
            basename, extension = name.split('.')
        except Exception as e:
            print(f'{name} is not a valid .npy file')
            continue
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
    end_time = time.time()
    print(f"Took {end_time - start_time} seconds")
    return vdb_paths

def import_VDBs(vdb_paths):
    for vdb_filepath in vdb_paths:

        if os.path.isdir(vdb_filepath):
            try:
                print(f"VDB sequence detected at {vdb_filepath}. Importing sequence")
                frames = []
                for item in os.listdir(vdb_filepath):
                    dict = {"name":item, "name":item} #not sure why this is redundant like this, but it's how Blender reads it in
                    frames.append(dict)
                bpy.ops.object.volume_import(filepath=vdb_filepath,
                                                directory=vdb_filepath,
                                                files=frames,
                                                relative_path=True, align='WORLD', location=(0,0,0), scale=(1,1,1))
            except Exception as e:
                print(f"Directory does not contain valid VDB sequence.\n    Exception: {e}")

        elif os.path.basename(vdb_filepath).split('.')[1] == "vdb":
            print(f"Static VDB file detected at {vdb_filepath}")
            name = os.path.basename(vdb_filepath)
            try:
                bpy.ops.object.volume_import(filepath=vdb_filepath, directory=os.path.dirname(vdb_filepath), files=[{"name":name}], relative_path=True, align='WORLD', location=(0, 0, 0), scale=(1, 1, 1))
            except Exception as e:
                print(f"{vdb_filepath} could not be loaded\n    Exception:{e}")
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
    #Eventually this will probably just be "Load Volumes." Other functionality can go in other panels
    """Main Neurovolume Panel"""
    bl_label = "Neurovolume"
    bl_idname = "VIEW3D_PT_nv"
    bl_space_type = "VIEW_3D" #in the 3D viewport
    bl_region_type = "UI" #in the UI panel
    bl_category = "Neurovolume" #name of panel
    
    def draw (self, context):        
        self.layout.prop(context.scene, "path_input")
        self.layout.prop(context.scene, "low_clip")
        self.layout.operator("load.volume", text="Load .npy Files as VDBs")

class LoadVolume(bpy.types.Operator):
    """Load in NPY file and convert it to VDB"""
    bl_idname = "load.volume"
    bl_label = "Load Volume"
    
    def execute(self, context):
        global low_clip
        #For now we are just going to print what is input
        folder_path = context.scene.path_input
        print(f"Entered Path: {folder_path}")
        low_clip = context.scene.low_clip
        print("executing with low clip,", low_clip)
        paths = read_volumes(folder_path)
        import_VDBs(paths)

        self.report({'INFO'}, "VDBs loaded into scene")
        return {"FINISHED"}

#----------------------
# Property Registration
#----------------------
#THIS IS ALL A MESS

def register_properties():
    bpy.types.Scene.path_input = bpy.props.StringProperty(
        name="NPY Folder",
        description="Enter path to folder containing .npy files",
        default="/Users/joachimpfefferkorn/repos/neurovolume/output"
        )
    bpy.types.Scene.low_clip = bpy.props.FloatProperty(
        name="Low Clip",
        description="Set low threshold for volume",
        default=0.0,
        min=0.0,
        max=1.0,
    )
        
def unregister_properties():
    del bpy.types.Scene.path_input
    del bpy.types.Scene.low_clip

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

