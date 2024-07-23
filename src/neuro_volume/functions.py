import numpy as np
from matplotlib import pyplot as plt

def show_3D_array(array):
    #More or less copypasta
    plt.rcParams["figure.figsize"] = [7.00, 3.50]
    plt.rcParams["figure.autolayout"] = True
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')
    z, x, y = array.nonzero()
    ax.scatter(x, y, z, c=z, alpha=1)
    plt.show()

def naive_sanity_check(array, thresh=0.0):
    #naive sanity check
    for index, density in np.ndenumerate(array):
        if density > thresh:
            print("Index: " + str(index) + " Density: " + str(density))


def normalize_array(arr):
    return (arr - np.min(arr)) / (np.max(arr) - np.min(arr))

def view_sagittal_slices(volume):
    for i in range(volume.shape[2]):
        slice = volume[:][:][i]
        plt.imshow(slice, cmap='gray')
        plt.title(i)
        plt.show()

def create_volume(normalized_tensor):
    mri_volume = np.zeros(normalized_tensor.shape)
    for z_index in range(normalized_tensor.shape[2]):
        sagittal_slice = normalized_tensor[:, :, z_index]
        for row_index, row in enumerate(sagittal_slice):
            for col_index, _ in enumerate(row):
                density = sagittal_slice[row_index][col_index]
                mri_volume[row_index][col_index][z_index] = density
    return mri_volume