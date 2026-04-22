# scratchy little thing to get some test data
#110% copyslop


import numpy as np

def save_sphere(radius=128, filename="sphere.npy"):
    diameter = radius * 2
    grid = np.zeros((diameter, diameter, diameter), dtype=np.float32)
    cx, cy, cz = radius, radius, radius
    z, y, x = np.ogrid[:diameter, :diameter, :diameter]
    mask = (x - cx)**2 + (y - cy)**2 + (z - cz)**2 <= radius**2
    grid[mask] = 1.0
    np.save(filename, grid)
    print(f"Saved {filename} — shape: {grid.shape}, voxels filled: {mask.sum()}")

def save_cube(radius=128, filename="cube.npy"):
    diameter = radius * 2
    grid = np.ones((diameter, diameter, diameter), dtype=np.float32)
    np.save(filename, grid)
    print(f"Saved {filename} — shape: {grid.shape}, voxels filled: {grid.size}")

save_sphere()
save_cube()
