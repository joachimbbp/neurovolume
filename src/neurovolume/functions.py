import numpy as np
import matplotlib as mpl
from matplotlib import pyplot as plt
from matplotlib.colors import ListedColormap
import os
from PIL import Image
from numpy import asarray
import ants
from ipywidgets import interact

#Visualization options (feel free to tweak):
default_cmap = 'nipy_spectral'
default_figsize = (4,4)
mask_contor_color = 'white'
mask_contor_thickness = 1
mask_contor_levels = [0.5]
empty_mask = np.empty((1,1,1))

def plot_average(arr, clip_range=None):
    means = []
    for i in range(arr.shape[3]):
        means.append(np.mean(arr[:,:,:,i]))
    if isinstance(clip_range, range):
        print(clip_range)       
        plt.plot(means[clip_range.start:clip_range.stop], linestyle='-', color='b')
    else:
        plt.plot(means, linestyle='-', color='b')


def explore_4D_vol(vol: np.ndarray, cmap=default_cmap, dim="x"):
    #TODO:
    #   DRY
    #   Interaction for dimensions
    #   Integrate 3D interaction
    """
    vol is 3 or 4 dimensional
    """

    def x_coord(slice, frame):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[slice, :, :, frame], cmap=cmap)

    def y_coord(slice, frame):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, slice, :, frame], cmap=cmap)
       
    def z_coord(slice, frame):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, :, slice, frame], cmap=cmap)

    frame_range=(0, vol.shape[3]-1)


    match dim:
        case "x":
            interact(x_coord, slice=(0, vol.shape[0]-1), frame=frame_range)
        case "y":
            interact(y_coord, slice=(0, vol.shape[1]-1), frame=frame_range)
        case "z":
            interact(z_coord, slice=(0, vol.shape[2]-1), frame=frame_range)

def explore_3D_vol(vol: np.ndarray, cmap=default_cmap, dim="x"):
    #TODO dry if possible

    def x_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[slice, :, :], cmap=cmap)

    def y_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, slice, :], cmap=cmap)
       
    def z_coord(slice):
        plt.figure(figsize=default_figsize)
        plt.imshow(vol[:, :, slice], cmap=cmap)

    match dim:
        case "x":
            interact(x_coord, slice=(0, vol.shape[0]-1))
        case "y":
            interact(y_coord, slice=(0, vol.shape[1]-1))
        case "z":
            interact(z_coord, slice=(0, vol.shape[2]-1))


def skull_strip_bold(bold, mni_template, mni_mask, dilate=False):
    """
    Assuming a motion corrected or relatively BOLD image
    """
    
    print("Skull strip for BOLD")
    isolated_brain_vol_frames = []
    for frame in range(bold.shape[3]):
        print(f"Skull stripping bold frame {frame + 1}/{bold.shape[3]}")
        bold_frame = ants.from_numpy(bold.numpy()[:,:,:,frame],
                                    spacing=bold.spacing[:3])
        brain_mask = generate_brain_mask(bold_frame, mni_template, mni_mask)
        if dilate:
            print("Dilating brain mask")
            brain_mask = ants.morphology(brain_mask, radius=4, operation='dilate', mtype='binary')
        isolated_brain_vol = ants.mask_image(bold_frame, brain_mask).numpy()
        isolated_brain_vol_frames.append(isolated_brain_vol)
    print("Creating new ANTsImage from isolated brain volumes")
    data = np.stack([frame for frame in isolated_brain_vol_frames], axis=3)
    isolated_brain_bold_img = ants.from_numpy(data, origin=bold.origin, spacing=bold.spacing)
    print("Done")
    return isolated_brain_bold_img
    
        

def generate_brain_mask(subject, mni_template, mni_mask):
    """
    subject: the scan that we are going to generate a brain mask for
    mni_template: your mni template
    mni_mask: your mni mask 
    """
    template_warp_to_raw_anat = ants.registration(
        fixed=subject,
        moving=mni_template, 
        type_of_transform='SyN',
        verbose=False
        )
    print("Creating brain mask")
    brain_mask = ants.apply_transforms(
        fixed=template_warp_to_raw_anat['warpedmovout'],
        moving=mni_mask,
        transformlist=template_warp_to_raw_anat['fwdtransforms'],
        interpolator='nearestNeighbor',
        verbose=False
    )
    return brain_mask

def skull_strip_anat(anat, mni_template, mni_mask, dilate=True, invert=False):
    """
    anat, mni_template, mni_mask must all be ANTS images.
    inverting 
    """
    print("Skull Stripping Anatomy Volume")
    print("Registering template to frame")

    brain_mask = generate_brain_mask(anat, mni_template, mni_mask)
    if dilate:
        print("Dilating brain mask")
        brain_mask = ants.morphology(brain_mask, radius=4, operation='dilate', mtype='binary')
    if invert:
        print("Inverting brain mask")
        brain_mask = ants.from_numpy(np.invert(brain_mask))


    print("Masking brain")
    isolated_brain = ants.mask_image(anat, brain_mask)
    print("Done")
    return isolated_brain

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

def normalize_array(arr):
    return np.array((arr - np.min(arr)) / (np.max(arr) - np.min(arr)))

def create_volume(tensor):

    # For some reason this incredibly redundant seeming function needs to be used!

    # comparing the mri_volume with tensor they are -as to be expected- the same
    # However, when a vdb is created just with the tensor it comes out as a pure box of noise
    # I have no idea why!

    mri_volume = np.zeros(tensor.shape)
    for z_index in range(tensor.shape[2]):
        sagittal_slice = tensor[:, :, z_index]
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
    print("creating masked normalized tensor")
    return create_volume((np.where(mask_tensor==keep_when,np.array(normalize_array(brain_tensor)), 0.0)))