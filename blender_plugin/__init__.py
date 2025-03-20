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
        
        vdb_filename = f"{get_basename(nifti_filepath)}.vdb"
        vdb_filepath = f"{output_filepath}/{vdb_filename}"
        print(f"loading in {vdb_filepath}")
        bpy.ops.object.volume_import(filepath=vdb_filepath, directory=output_filepath, files=[{"name":vdb_filename, "name":vdb_filename}], relative_path=True, align='WORLD', location=(0, 0, 0), scale=(1, 1, 1))

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

