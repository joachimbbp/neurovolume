# scratchy little thing to get some test data
# 110% copyslop


import numpy as np


def save_sphere(radius=64, filename="sphere.npy"):
    diameter = radius * 2
    grid = np.zeros((diameter, diameter, diameter), dtype=np.float32)
    cx, cy, cz = radius, radius, radius
    z, y, x = np.ogrid[:diameter, :diameter, :diameter]
    mask = (x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2 <= radius**2
    grid[mask] = 1.0
    np.save(filename, grid)
    print(f"Saved {filename} — shape: {grid.shape}, voxels filled: {mask.sum()}")


def save_cube(radius=128, filename="cube.npy"):
    diameter = radius * 2
    grid = np.ones((diameter, diameter, diameter), dtype=np.float32)
    np.save(filename, grid)
    print(f"Saved {filename} — shape: {grid.shape}, voxels filled: {grid.size}")


def save_rotating_cube(radius=64, n_frames=48, filename="rotating_cube.npy"):
    diameter = radius * 2
    cube = np.ones((diameter, diameter, diameter), dtype=np.float32)

    frames = np.zeros((n_frames, diameter, diameter, diameter), dtype=np.float32)

    c = (diameter - 1) / 2.0
    ax = np.arange(diameter) - c
    X, Y, Z = np.meshgrid(ax, ax, ax, indexing="ij")

    for i in range(n_frames):
        angle = i * (2.0 * np.pi / n_frames)
        cos_a, sin_a = np.cos(angle), np.sin(angle)

        src_x = cos_a * X + sin_a * Y + c
        src_y = -sin_a * X + cos_a * Y + c
        src_z = Z + c

        ix = np.round(src_x).astype(np.int32)
        iy = np.round(src_y).astype(np.int32)
        iz = np.round(src_z).astype(np.int32)

        valid = (
            (ix >= 0)
            & (ix < diameter)
            & (iy >= 0)
            & (iy < diameter)
            & (iz >= 0)
            & (iz < diameter)
        )
        ix = np.clip(ix, 0, diameter - 1)
        iy = np.clip(iy, 0, diameter - 1)
        iz = np.clip(iz, 0, diameter - 1)

        frames[i] = np.where(valid, cube[ix, iy, iz], 0.0)

    mb = frames.nbytes / (1024**2)
    np.save(filename, frames)
    print(f"Saved {filename} — shape: {frames.shape}, size: {mb:.1f} MB")


def save_rotating_pyramid(radius=64, n_frames=48, filename="rotating_pyramid.npy"):
    diameter = radius * 2
    c = (diameter - 1) / 2.0

    ax = np.arange(diameter) - c
    X, Y, Z = np.meshgrid(ax, ax, ax, indexing="ij")

    # Square cross-section shrinks linearly from base (z=0) to apex (z=diameter-1)
    z_norm = np.arange(diameter) / (diameter - 1)
    half_width = (1.0 - z_norm) * radius
    hw = half_width[np.newaxis, np.newaxis, :]

    pyramid = ((np.abs(X) <= hw) & (np.abs(Y) <= hw)).astype(np.float32)

    frames = np.zeros((n_frames, diameter, diameter, diameter), dtype=np.float32)

    for i in range(n_frames):
        angle = i * (2.0 * np.pi / n_frames)
        cos_a, sin_a = np.cos(angle), np.sin(angle)

        src_x = cos_a * X + sin_a * Y + c
        src_y = -sin_a * X + cos_a * Y + c
        src_z = Z + c

        ix = np.round(src_x).astype(np.int32)
        iy = np.round(src_y).astype(np.int32)
        iz = np.round(src_z).astype(np.int32)

        valid = (
            (ix >= 0)
            & (ix < diameter)
            & (iy >= 0)
            & (iy < diameter)
            & (iz >= 0)
            & (iz < diameter)
        )
        ix = np.clip(ix, 0, diameter - 1)
        iy = np.clip(iy, 0, diameter - 1)
        iz = np.clip(iz, 0, diameter - 1)

        frames[i] = np.where(valid, pyramid[ix, iy, iz], 0.0)

    mb = frames.nbytes / (1024**2)
    np.save(filename, frames)
    print(f"Saved {filename} — shape: {frames.shape}, size: {mb:.1f} MB")


def save_jittery_cube(
    radius=64,
    full_n_frames=48,
    n_keyframes=4,
    filename="jittery_cube.npy",
):
    diameter = radius * 2
    cube = np.ones((diameter, diameter, diameter), dtype=np.float32)
    frames = np.zeros((n_keyframes, diameter, diameter, diameter), dtype=np.float32)

    c = (diameter - 1) / 2.0
    ax = np.arange(diameter) - c
    X, Y, Z = np.meshgrid(ax, ax, ax, indexing="ij")

    kept = np.linspace(0, full_n_frames, n_keyframes, endpoint=False)

    for out_i, i in enumerate(kept):
        angle = i * (2.0 * np.pi / full_n_frames)
        cos_a, sin_a = np.cos(angle), np.sin(angle)

        src_x = cos_a * X + sin_a * Y + c
        src_y = -sin_a * X + cos_a * Y + c
        src_z = Z + c

        ix = np.round(src_x).astype(np.int32)
        iy = np.round(src_y).astype(np.int32)
        iz = np.round(src_z).astype(np.int32)

        valid = (
            (ix >= 0)
            & (ix < diameter)
            & (iy >= 0)
            & (iy < diameter)
            & (iz >= 0)
            & (iz < diameter)
        )
        ix = np.clip(ix, 0, diameter - 1)
        iy = np.clip(iy, 0, diameter - 1)
        iz = np.clip(iz, 0, diameter - 1)

        frames[out_i] = np.where(valid, cube[ix, iy, iz], 0.0)

    mb = frames.nbytes / (1024**2)
    np.save(filename, frames)
    print(f"Saved {filename} — shape: {frames.shape}, size: {mb:.1f} MB")


# save_sphere()
# save_cube()
# save_rotating_cube()
# save_rotating_pyramid()
save_jittery_cube()
