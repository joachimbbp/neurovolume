import numpy as np
import matplotlib as mpl
from matplotlib import pyplot as plt
from matplotlib.colors import ListedColormap
import os
from PIL import Image
from numpy import asarray

def build_bool_mask(mask_sequence_path, original_mri_tensor):
    masks = {} #dictionary with number being the key, the mask array as the value
    for entry in os.listdir(mask_sequence_path):
        if entry.endswith(".jpg"):
            img_path = f"{mask_sequence_path}/{entry}"
            with Image.open(img_path) as img:
                masks[entry[-6:-4]] = (asarray(img.convert('L')) > 0)
                #Creates a boolean mask for now #TODO come to think of it, you could do string or enum labels for anatomy here!
                #TODO some scalar number to give soft transitions between the grids
    
    mask_3D = np.empty(original_mri_tensor.shape)
    for index in sorted(masks):
        mask_3D[:,:,int(index)] = masks[index]
    print("bool masks built v1")
    return mask_3D


def iso_scale_trans(affine):
    """
    Isolates the scale and translation from an affine
    """
    return [
    [float(affine[0][0]), 0.0, 0.0, 0.0],
    [0.0, float(affine[1][1]), 0.0, 0.0],
    [0.0, 0.0, float(affine[2][2]), 0.0],
    [0.0, 0.0, 0.0, 1.0],
]

def plot_examples(colormaps):
#copypasta from matplotlib docs
    """
    Helper function to plot data with associated colormap.
    """
    np.random.seed(19680801)
    data = np.random.randn(30, 30)
    n = len(colormaps)
    fig, axs = plt.subplots(1, n, figsize=(n * 2 + 2, 3),
                            layout='constrained', squeeze=False)
    for [ax, cmap] in zip(axs.flat, colormaps):
        psm = ax.pcolormesh(data, cmap=cmap, rasterized=True, vmin=-4, vmax=4)
        fig.colorbar(psm, ax=ax)
    plt.show()


def show_3D_array(array):
    print('updated')
    plt.switch_backend('Agg')
    #More or less copypasta
    #Currently is crashing the kernel when in the dev container

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


def normalize_array(arr): #changed to return an np array directly
    return np.array((arr - np.min(arr)) / (np.max(arr) - np.min(arr)))

def view_slice(slice, color_map="tab20c", title=""):
    plt.imshow(slice, cmap=color_map)
    plt.title(title)
    plt.show()

#TODO move the view saggital slices function over here, integrate into all these matplotlib functions

def view_all_sagittal_slices(volume, color_map):
    for i in range(volume.shape[2]):
        slice = volume[:,:,i]
        view_slice(slice, color_map, title=str(i))

def view_sagittal_slice(volume, middle, color_map):
    slice = volume[:,:,middle]
    view_slice(slice, color_map)
    

def create_volume(normalized_tensor):
    """
    Redundant function that needs to be eliminated

    `anat_norm = create_volume(normalize_array(nib.load(anat_filepath).get_fdata()))
    anat_norm_no_cv = normalize_array(nib.load(anat_filepath).get_fdata())
    print(np.array_equal(anat_norm, anat_norm_no_cv))`
    Returns True

    However, when a vdb is created with `anat_norm_no_cv` it comes out as a pure box of noise
    I have no idea why!
    """
    mri_volume = np.zeros(normalized_tensor.shape)
    for z_index in range(normalized_tensor.shape[2]):
        sagittal_slice = normalized_tensor[:, :, z_index]
        for row_index, row in enumerate(sagittal_slice):
            for col_index, _ in enumerate(row):
                density = sagittal_slice[row_index][col_index]
                mri_volume[row_index][col_index][z_index] = density
    return mri_volume

def create_normalized_volume(vol):
    return create_volume(normalize_array(vol))

def parent_directory() -> str:
    #WARNING
    #This only works for this repo's specific folder structure
    dir = os.path.dirname(os.path.dirname(os.getcwd()))
    return dir

def sum_3D_array(array):
    return np.sum(array[0]) + np.sum(array[1]) + np.sum(array[2])

def create_masked_normalized_tensor(brain_tensor, mask_tensor, keep_when=True):
    print("creating masked normal tensor")
    return create_volume((np.where(mask_tensor==keep_when,np.array(normalize_array(brain_tensor)), 0.0)))