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

#CLASSES


#FUNCTIONS
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

arg_parser = argparse.ArgumentParser(description="Quickly view a slice of a 3D or 4D .npy file in your terminal")
arg_parser.add_argument("vol_path", metavar="npy volume path", type=str, help="The path to the .npy file you wish to view")
arg_parser.add_argument("-i", "--index", type=int, metavar="Spatial Index", help="The index along the dimension you wish to slice")
arg_parser.add_argument("-f", "--frame", type=int, metavar="Frame", help="The frame you wish to index from a 4D time series volume")
arg_parser.add_argument("-d", "--dimension", type=str, metavar="Spatial Dimension", help="The dimension, x y or z, that you wish to index along")
args = arg_parser.parse_args()

scan = np.load(args.vol_path)

#print header info here
match len(scan.shape):
    case 2:
        view_frame(scan)
    case 3:
        view_frame(select_slice(scan))
    case 4:
        view_frame(select_slice(select_frame(scan)))
    case _:
        print(f"Invalid scan shape {scan.shape}\nmust be either a frame (2D), static 3D scan or a functional 4D scan")