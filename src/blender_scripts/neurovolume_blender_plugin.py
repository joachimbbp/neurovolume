print("Neurovolume is running")

#--------
# Setup
#--------
bl_info = {
    "name": "Neurovolume",
    }

import bpy
import numpy as np

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
        layout.operator("load.npy", text="Load .npy File")

class LoadVolume(bpy.types.Operator):
    """Load in NPY file and convert it to VDB"""
    bl_idname = "load.volume" #ugh why are these conventions different?
    bl_label = "Load Volume"
    
    def execute(self, context):
        #For now we are just going to print what is input
        text = context.scene.path_input
        print(f"Entered Path: {text}")
        
        self.report({'INFO'}, "path printed to terminal")
        return {"FINISHED"}

#----------------------
# Property Registration
#----------------------
def register_properties():
    bpy.types.Scene.path_input = bpy.props.StringProperty(
        name="Path Input",
        description="Enter path to .npy file",
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