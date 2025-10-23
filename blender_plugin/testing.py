import neurovolume_lib as nv

static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
fmri_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii"


t1_save_location = nv.nifti1_to_VDB(static_testfile, True)
t1_nf = nv.num_frames(static_testfile, "NIfTI1")
print("🐍 static VDB saved to: ", t1_save_location,
      " with ", t1_nf, " frames\n")

fmri_save_location = nv.nifti1_to_VDB(fmri_testfile, True)
bold_nf = nv.num_frames(fmri_testfile, "NIfTI1")
print("🐍 bold VDB saved to: ", fmri_save_location,
      " with ", bold_nf, " frames\n")
