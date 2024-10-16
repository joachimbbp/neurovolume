# integrate this:
# brain = create_volume((np.where(mask_3D==True,np.array(normalize_array(fmri.brain_data)), 0.0)))
# exterior_anat = create_volume((np.where(mask_3D==False,np.array(normalize_array(fmri.brain_data)), 0.0)))
# full_anat = create_volume(normalize_array(fmri.brain_data))
#into the vdb creation