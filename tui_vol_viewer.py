import sys
import numpy as np
#Available color maps
mac_hearts = "🖤💜🧡💛💚🩶🤎🩷🩵💙🤍"
universal_chars = "$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\|()1{}[]?-_+~<>i!lI;:,^."

#100x100 seems like a decent resolution

#TODO implement the rest of these args
usage = '''Usage:
    arg1, scan you wish to display
    arg2, dimension to index (optional, if blank, default to half)
    arg3, 3D index (optional, if blank default to half)
    arg4, time index (optional, ignore if 3D, set tohalf if blank)
    arg5, color map (optional)'''

scan = np.load(sys.argv()[1])

def select_frame(vol_seq):
    print("select frame not implemented yet")

def select_slice(vol, dim=0, slice_idx=None):
    if 0 > dim > 2:
        print("Dimension must be 0 1 or 2, setting to 0")
        dim = 0

    if slice_idx==None:
        slice_idx = int(vol.shape[dim]/2)

def view_frame(frame):
    print("not implemented yet")

match len(scan.shape):
    case 2:
        view_frame(scan)
    case 3:
        view_frame(scan[])