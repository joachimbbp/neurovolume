import matplotlib.pyplot as plt
from ipywidgets import interact
import numpy as np


default_cmap = 'nipy_spectral'
default_figsize = (4,4)
empty_mask = np.empty((1,1,1))

def explore_3D_vol(vol: np.ndarray, cmap=default_cmap, dim="x", mask=empty_mask):
    #TODO rename dims to saggital, etc
    #TODO shot all 3D at the same time with https://matplotlib.org/stable/users/explain/axes/axes_intro.html
    masking = False
    if mask != empty_mask:
        masking = True

    def x_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[slice, :, :], cmap=default_cmap)

    def y_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, slice, :], cmap=default_cmap)
    
    def z_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, :, slice], cmap=default_cmap)

    match dim:
        case "x":
            interact(x_coord, slice=(0, vol.shape[0]-1))
        case "y":
            interact(y_coord, slice=(0, vol.shape[1]-1))
        case "z":
            interact(z_coord, slice=(0, vol.shape[2]-1))
