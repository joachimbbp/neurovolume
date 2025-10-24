# :_: ------------------------------------------------------------------------
#                               Imports
# ----------------------------------------------------------------------------
import json
import os
import bpy
from . import neurovolume_lib as nv  # LOCAL:
# :_: ------------------------------------------------------------------------
#                               User Set Path
#                                           Replace these paths with
#                                           the the corresponding paths
#                                           on your machine
# ------------------------------------------------------------------------------
user_set_output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output"
user_set_default_nifti = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"  # optional

# :_: ------------------------------------------------------------------------
#                               Setup
# ------------------------------------------------------------------------------
bl_info = {
    "name": "Neurovolume",
    "author": "Joachim Pfefferkorn",
    "description": "",
    "blender": (2, 80, 0),
    "version": (0, 0, 0),
    "location": "",
    "warning": "",
    "category": "Generic",
}
print("Neurovolume is running")


# :_: ------------------------------------------------------------------------
#                               Backend Functions
# ------------------------------------------------------------------------------
# THOUGHT: Not sure if these first two should go into the neurovolume_lib?

def vdb_frames_sort(entry: dict):
    return int(entry["name"].split(".")[0].split("_")[-1])


def volume_data(filepath) -> str:
    path_parts = filepath.split("/")
    filename = nv.get_basename(filepath)
    fps = nv.source_fps(filepath, "NIfTI1")
    if fps == 0:
        return f"{filename}\nStatic Volume"
    else:
        return f"{filename}\nFPS: {fps}"


def load_nifti1(filepath: str, normalize: bool = True):
    vdb_path = os.path.abspath(
        nv.nifti1_to_VDB(filepath, normalize))
    print("vdb path: ", vdb_path)

    n_frames = nv.num_frames(filepath, "NIfTI1")
    if n_frames == 1:
        bpy.ops.object.volume_import(filepath=vdb_path,
                                     relative_path=False,
                                     align='WORLD',
                                     location=(0, 0, 0),
                                     scale=(1, 1, 1))
        return volume_data(filepath)
    elif n_frames > 1:
        vdb_sequence = []

        for filename in os.listdir(vdb_path):
            if filename.endswith(".vdb"):
                vdb_sequence.append({"name": filename})
            else:
                continue
            vdb_sequence.sort(key=vdb_frames_sort)
            print(f"loading in VDB sequence:\n{vdb_sequence}")
        bpy.ops.object.volume_import(filepath=filepath,
                                     directory=vdb_path,
                                     files=vdb_sequence,
                                     relative_path=True,
                                     align='WORLD',
                                     location=(0, 0, 0),
                                     scale=(1, 1, 1))
        return volume_data(filepath)
# :_: ------------------------------------------------------------------------
# ------------------------------------------------------------------------------
#                               GUI Functions
# ------------------------------------------------------------------------------


class Neurovolume(bpy.types.Panel):
    # Eventually this will probably just be "Load Volumes." Other functionality can go in other panels
    """Main Neurovolume Panel"""
    bl_label = "Neurovolume"
    bl_idname = "VIEW3D_PT_nv"
    bl_space_type = "VIEW_3D"  # in the 3D viewport
    bl_region_type = "UI"  # in the UI panel
    bl_category = "Neurovolume"  # name of panel

    def draw(self, context):
        self.layout.prop(context.scene, "path_input")
        self.layout.operator("load.volume", text="Load VDB from NIfTI")


class LoadVolume(bpy.types.Operator):
    bl_idname = "load.volume"
    bl_label = "Load Volume"

    def execute(self, context):
        report = load_nifti1(context.scene.path_input)
        self.report({'INFO'}, report)
        return {"FINISHED"}
# :_: ------------------------------------------------------------------------
#                               Property Registration
# ------------------------------------------------------------------------------


def register_properties():
    bpy.types.Scene.path_input = bpy.props.StringProperty(
        name="NIfTI File",
        description="Enter path to folder containing .npy files",
        default=user_set_default_nifti
    )


def unregister_properties():
    del bpy.types.Scene.path_input


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
