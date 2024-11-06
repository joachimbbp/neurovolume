import matplotlib.pyplot as plt
from ipywidgets import interact
import numpy as np

default_cmap = 'nipy_spectral'
default_figsize = (4,4)

def explore_3D_vol(vol: np.ndarray, cmap=default_cmap, dim="x"):
    #TODO rename dims to saggital, etc
    #TODO shot all 3D at the same time with https://matplotlib.org/stable/users/explain/axes/axes_intro.html

    def x_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[slice, :, :], cmap=default_cmap)
    if dim=="x":
        interact(x_coord, slice=(0, vol.shape[0]-1))

    def y_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, slice, :], cmap=default_cmap)
    if dim=="y":
        interact(y_coord, slice=(0, vol.shape[1]-1))
    
    def z_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, :, slice], cmap=default_cmap)
    if dim=="z":
        interact(z_coord, slice=(0, vol.shape[2]-1))