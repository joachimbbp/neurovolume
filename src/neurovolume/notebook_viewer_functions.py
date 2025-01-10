import matplotlib.pyplot as plt
from ipywidgets import interact
import numpy as np

#LEGACY FUNCTIONS

#Visualization options (feel free to tweak):
default_cmap = 'nipy_spectral'
default_figsize = (4,4)
mask_contor_color = 'white'
mask_contor_thickness = 1
mask_contor_levels = [0.5]

#control flow dependent stuff (don't change these):
empty_mask = np.empty((1,1,1))

def explore_3D_vol(vol: np.ndarray, cmap=default_cmap, dim="x", mask=empty_mask):
    #TODO rename dims to saggital, etc, or at least print that on the plot
    #TODO shot all 3D at the same time with https://matplotlib.org/stable/users/explain/axes/axes_intro.html
    masking = False
    if mask.all() != empty_mask.all():
        masking = True

    #TODO dry if possible
    #TODO Hey you could use .set_title() to display the frame, maybe?
    def x_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[slice, :, :], cmap=cmap)
        if masking:
            plt.contour(mask[slice,:,:], levels=mask_contor_levels, colors=mask_contor_color, linewidths=mask_contor_thickness)

    def y_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, slice, :], cmap=cmap)
        if masking:
            plt.contour(mask[:,slice,:], levels=mask_contor_levels, colors=mask_contor_color, linewidths=mask_contor_thickness)
    
    def z_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, :, slice], cmap=cmap)
        if masking:
            plt.contour(mask[:,:,slice], levels=mask_contor_levels, colors=mask_contor_color, linewidths=mask_contor_thickness)

    match dim:
        case "x":
            interact(x_coord, slice=(0, vol.shape[0]-1))
        case "y":
            interact(y_coord, slice=(0, vol.shape[1]-1))
        case "z":
            interact(z_coord, slice=(0, vol.shape[2]-1))

