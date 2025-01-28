#tvsv stands for TUI Volume Slice Viewer

import sys
import numpy as np
from scipy.ndimage import zoom
import argparse
from enum import Enum

#COLOR MAPS
mac_squares = "🟫🟩🟥🟦🟧🟪🟨⬜️"
universal_chars = "$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\|()1{}[]?-_+~<>i!lI;:,^."
just_ints = "0123456789"
very_small = "#&*- "

#FUNCTIONS
def select_frame(vol_seq):
    print("select frame not implemented yet")

def get_slice(vol, dim, slice_idx):
    # I think there might be a more elegant way to do this
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

def midpoint(shape, dim):
    print(f"shape {shape} dim {dim}")
    return int(shape[dim]/2)

def select_slice(vol, dim=2, slice_idx=1):
    #(lambda s: s[-1])
    if slice_idx==None:
        slice_idx = midpoint(vol, dim)
    try:
        slice = get_slice(vol, dim, slice_idx)
    except:
        print("error in getting slice\nAttempting with dim=0 and slice as midpoint on x axis")
        slice = get_slice(vol, 0, midpoint(vol,dim))
    return slice

def view_frame(frame, scale_factor = 0.15):
    #WARNING: This normalizes to the specified frame, not the whole scan

    def find_char(pixel_luma, min, max, charmap=universal_chars):
        normalized_luma = (pixel_luma-min)/(max-min)
        charmap_idx = int(normalized_luma * (len(charmap)-1))
        #print(f"charmap idx {charmap_idx}, normalized luma {normalized_luma}, char: {charmap[charmap_idx]}")
        return charmap[charmap_idx]
    
    #TODO scale proportionally, don't force into 100x100
    resized_frame = zoom(frame, scale_factor)
    canvas = ""
    min = np.min(resized_frame)
    max = np.max(resized_frame)
    print(f"min {min} max {max}")
    for y in range(resized_frame.shape[0]):
        for x in range(resized_frame.shape[1]):
            canvas+=find_char(resized_frame[y,x], min, max)
        canvas += "\n"
    print(canvas)

def dim_char2int(dim: str):
    match dim:
        case "x":
            return 0
        case "y":
            return 1
        case "z":
            return 2
        case _:
            print("Invalid dimension string. Setting to default of 'z', returning 2")
            return 2
def dim_int2char(dim: int):
    match dim:
        case 0:
            return "x"
        case 1:
            return "y"
        case 2:
            return "z"
        case _:
            print("Invalid dimension string. Setting to default value of 'z', returning char 'z'")
            return "z"


arg_parser = argparse.ArgumentParser(description="Quickly view a slice of a 3D or 4D .npy file in your terminal")
arg_parser.add_argument("vol_path", metavar="npy volume path", type=str, help="The path to the .npy file you wish to view")
arg_parser.add_argument("-d", "--dimension", type=str, metavar="Spatial Dimension", help="The dimension, x y or z, that you wish to index along. Defaults to z")
arg_parser.add_argument("-f", "--frame", type=int, metavar="Frame", help="The frame you wish to index from a 4D time series volume")
arg_parser.add_argument("-i", "--index", type=int, metavar="Spatial Index", help="The index along the dimension you wish to slice")
args = arg_parser.parse_args()


scan = np.load(args.vol_path)
shape = scan.shape
dimension = dim_char2int(args.dimension) if args.dimension in {"x", "y", "z"} else 2
frame = args.frame if args.frame is not None else 0
index = args.index if args.index is not None else midpoint(shape, dimension)


match len(shape):
    case 2:
        print(f"3D Volume\nVolume Shape: {shape}")
        view_frame(scan)
    case 3:
        print(f"3D Volume\nVolume Shape: {shape} - Dimension {dim_int2char(dimension)} - Index {index}") #TODO make this more clear as to how you can move your slice up and down
        view_frame(select_slice(scan, slice_idx=index))
    case 4:
        print(f"4D Volume\nVolume Shape: {shape} - Dimension {dim_int2char(dimension)} - Index {index} - Frame {frame}")
        view_frame(select_slice(select_frame(scan, slice_idx=index)))
    case _:
        print(f"Invalid scan shape {scan.shape}\nmust be either a frame (2D), static 3D scan or a functional 4D scan")