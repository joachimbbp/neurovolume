import os
from nibabel.testing import data_path
import nibabel as nib
import numpy as np
import matplotlib as mpl
from matplotlib import pyplot as plt
from matplotlib.colors import ListedColormap

class MRI_Anat:
    # you can find the rest here https://nipy.org/nibabel/nibabel_images.html#the-image-object

    def __init__(self, file_path):
        self.brain_file = os.path.join(data_path, file_path)
        self.brain_img = nib.load(self.brain_file)
        self.brain_data = self.brain_img.get_fdata()

    def __str__(self):
        return self.brain_img.header

    def view_slice(self,position=20, plane="transverse", color_map=mpl.colormaps['tab20c']):
        #Could you do this with an enum in self?
        #TODO Make this 
        if plane=="sagittal":
            slice = self.brain_data[:,position,:]
        elif plane=="frontal":
            slice = self.brain_data[position,:,:] #TODO verify
        elif plane=="transverse":
            slice = self.brain_data[:,:,position]
        else:
            print(f'{plane} not a valid plane.\nValid planes: "Sagittal", "frontal", "transverse"\nDefaulting to transverse plane')
            slice = self.brain_data[:,:,position]
        plt.imshow(slice, cmap=color_map)
        plt.title(f"Plane: {plane}, Position: {position}")
        plt.colorbar()
        plt.show()

    # def create_volume(self): #TODO this will be replaced with an affine transform to get an anatomically accurate volume
    #     """
    #     Redundant function that needs to be eliminated

    #     `anat_norm = create_volume(normalize_array(nib.load(anat_filepath).get_fdata()))
    #     anat_norm_no_cv = normalize_array(nib.load(anat_filepath).get_fdata())
    #     print(np.array_equal(anat_norm, anat_norm_no_cv))`
    #     Returns True

    #     However, when a vdb is created with `anat_norm_no_cv` it comes out as a pure box of noise
    #     I have no idea why!
    #     """
    #     mri_volume = np.zeros(normalized_tensor.shape) #This should be from the affine, actually
    #     for z_index in range(normalized_tensor.shape[2]):
    #         sagittal_slice = normalized_tensor[:, :, z_index]
    #         for row_index, row in enumerate(sagittal_slice):
    #             for col_index, _ in enumerate(row):
    #                 density = sagittal_slice[row_index][col_index]
    #                 mri_volume[row_index][col_index][z_index] = density
    #     return mri_volume
