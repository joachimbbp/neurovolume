#tvsv stands for Tui Volume Slice Viewer

import sys
import numpy as np
#Available color maps
mac_hearts = "🖤💜🧡💛💚🩶🤎🩷🩵💙🤍"
universal_chars = "$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\|()1{}[]?-_+~<>i!lI;:,^."
just_ints = "0123456789"

#100x100 seems like a decent resolution

#TODO implement the rest of these args
usage = '''Usage:
    arg1, scan you wish to display
    arg2, dimension to index (optional, if blank, default to half)
    arg3, 3D index (optional, if blank default to half)
    arg4, time index (optional, ignore if 3D, set tohalf if blank)
    arg5, color map (optional)'''

scan = np.load(sys.argv[1])

def select_frame(vol_seq):
    print("select frame not implemented yet")

def get_slice(vol, dim, slice_idx):
    # I think there might be a more elegant way to do this
    print(f"Dimensions: {dim}")
    if 0 > dim > 2:
        print("Dimension must be 0 1 or 2, setting to 0")
        dim = 0
    match dim:
        case 0:
            return vol[slice_idx, :, :]
        case 1:
            return vol[:,slice_idx,:]
        case 2:
            return vol[:,:,slice_idx]

def midpoint(vol, dim):
    return int(vol.shape[dim]/2)

def select_slice(vol, dim=0, slice_idx=1):
    #(lambda s: s[-1])
    if slice_idx==None:
        slice_idx = midpoint(vol, dim)
    try:
        slice = get_slice(vol, dim, slice_idx)
    except:
        print("error in getting slice\nAttempting with dim=0 and slice as midpoint on x axis")
        slice = get_slice(vol, 0, midpoint(vol,dim))
    return slice

def view_frame(frame):
    #WARNING: This normalizes to the specified frame, not the whole scan

    def find_char(pixel_luma, min, max, charmap=just_ints):
        normalized_luma = (pixel_luma-min)/(max-min)
        charmap_idx = int(normalized_luma * (len(charmap)-1))
        #print(f"charmap idx {charmap_idx}, normalized luma {normalized_luma}, char: {charmap[charmap_idx]}")
        return charmap[charmap_idx]
    
    #TODO scale proportionally, don't force into 100x100
    resized_frame = np.resize(frame, (25,25))
    canvas = ""
    minmax = (np.min(resized_frame), np.max(resized_frame))
    for y in range(resized_frame.shape[0]):
        for x in range(resized_frame.shape[1]):
            canvas+=find_char(resized_frame[y,x], minmax[0], minmax[1])
        canvas += "\n"
    print(canvas)
    print(f"minmax: {minmax}, ")

match len(scan.shape):
    case 2:
        view_frame(scan)
    case 3:
        view_frame(select_slice(scan))
    case 4:
        view_frame(select_slice(select_frame(scan)))
    case _:
        print(f"Invalid scan shape {scan.shape}\nmust be either a frame (2D), static 3D scan or a functional 4D scan")

print(mac_hearts)