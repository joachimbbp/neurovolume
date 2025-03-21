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
import os
import json


#------------------------------------------------------------------------------
#                                   Backend Functions
#------------------------------------------------------------------------------


def get_basename(path):
    heiarchy = path.split("/")
    return heiarchy[-1].split(".")[0]

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
        self.layout.operator("load.volume", text="Load VDB from NIfTI")


def vdb_frames_sort(entry: dict):
    return int(entry["name"].split(".")[0].split("_")[-1])
class Volume(bpy.types.Operator):
    """Load in NPY file and convert it to VDB"""
    bl_idname = "load.volume"
    bl_label = "Load Volume"

    def execute(self, context):
        #For now we are just going to print what is input   
        print("Creating VDB from NIfTI File")
        nifti_filepath = context.scene.path_input
        output_filepath = "/Users/joachimpfefferkorn/repos/neurovolume/output"
        exe_path = "/Users/joachimpfefferkorn/repos/neurovolume/cmd/neurovolume/main"
        

        os.system(f"{exe_path} {nifti_filepath} {output_filepath}")
        vdb_basename = get_basename(nifti_filepath)
        vdb_metadata_filepath = f"{output_filepath}/{vdb_basename}_metadata.json"

        metadata = json.load(open(vdb_metadata_filepath))

        if metadata["Frames"] == 1:
            vdb_filename = f"{vdb_basename}.vdb"
            vdb_filepath = f"{output_filepath}/{vdb_filename}"
            print(f"loading in static VDB: {vdb_filepath}")
            bpy.ops.object.volume_import(filepath=vdb_filepath, directory=output_filepath, files=[{"name":vdb_filename}], relative_path=True, align='WORLD', location=(0, 0, 0), scale=(1, 1, 1))
#----------BOLD stuff
        elif metadata["Frames"] > 1:            
            print("loading VDB seq")
            vdb_seq_folder = f"{output_filepath}/{vdb_basename}_seq"
            vdb_sequence = []

            for filename in os.listdir(vdb_seq_folder):
                if filename.endswith(".vdb"):
                    #frame_num = int(name.split(".")[0].split("_")[-1])
                    vdb_sequence.append({"name": filename})
                else:
                    continue
            vdb_sequence.sort(key=vdb_frames_sort)
            print(f"loading in VDB sequence:\n{vdb_sequence}")
            bpy.ops.object.volume_import(filepath=vdb_seq_folder, directory=vdb_seq_folder, files=vdb_sequence, relative_path=True, align='WORLD', location=(0, 0, 0), scale=(1, 1, 1))

            #bpy.ops.object.volume_import(filepath="/Users/joachimpfefferkorn/repos/neurovolume/output/sub-01_task-emotionalfaces_run-1_bold_seq/", directory="/Users/joachimpfefferkorn/repos/neurovolume/output/sub-01_task-emotionalfaces_run-1_bold_seq/", files=[{"name":"sub-01_task-emotionalfaces_run-1_bold_0000.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0000.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0001.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0001.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0002.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0002.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0003.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0003.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0004.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0004.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0005.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0005.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0006.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0006.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0007.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0007.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0008.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0008.vdb"}, {"name":"sub-01_task-emotionalfaces_run-1_bold_0009.vdb", "name":"sub-01_task-emotionalfaces_run-1_bold_0009.vdb"}], relative_path=True, align='WORLD', location=(0, 0, 0), scale=(1, 1, 1))


#------------------------

        else:
            print("Invalid Frame number: ", metadata["Frames"])
            self.report({'INFO'}, "VDBs loaded into scene, Invalid Frame Number")
            return {"FINISHED"}

        

        self.report({'INFO'}, "VDBs loaded into scene")
        return {"FINISHED"}

#----------------------
# Property Registration
#----------------------
#THIS IS ALL A MESS

def register_properties():
    bpy.types.Scene.path_input = bpy.props.StringProperty(
        name="NIfTI File",
        description="Enter path to folder containing .npy files",
        default="/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
        )

        
def unregister_properties():
    del bpy.types.Scene.path_input

classes = [Neurovolume, Volume]

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

