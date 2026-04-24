import numpy as np
import sys

def _verify_and_copy_affine(affine: np.ndarray) -> np.ndarray:
    if len(affine) != 4:
        sys.exit(
            f"Invalid affine len, must be 4 (3D plus homogonized coordinate): {len(affine)}"
        )
    return affine.copy()

def scale(affine: np.ndarray, scale: float) -> np.ndarray:
    """
    modifies the affine matrix's scale
    usage: scale is the percentage to scale by
            0.5 is 50% etc
    """
    o = _verify_and_copy_affine(affine)
    # LLM: scale full 3x3 submatrix (not just diagonal) to preserve oblique orientation
    o[:3, :3] *= scale  # scale+rotation columns
    o[:3, 3] *= scale  # translation
    return o


def translate(affine: np.ndarray, x: float, y: float, z: float) -> np.ndarray:
    """
    modifies the affine matrix's translation
    usage: x y and z inputs are added to the translation column
    """
    # o for output
    o = _verify_and_copy_affine(affine)
    o[0][3] += x
    o[1][3] += y
    o[2][3] += z
    return o


def rotate(affine: np.ndarray, x: float, y: float, z: float) -> np.ndarray:
    """
    modifies the affine matrix's rotation
    usage: x y and z are respective theta in the 3D rotation
    (i think its radians...)
    """
    o = _verify_and_copy_affine(affine)
    # LLM: all below (I am way too lazy)
    Rx = np.array(
        [
            [1, 0, 0],
            [0, np.cos(x), -np.sin(x)],
            [0, np.sin(x), np.cos(x)],
        ]
    )

    Ry = np.array(
        [
            [np.cos(y), 0, np.sin(y)],
            [0, 1, 0],
            [-np.sin(y), 0, np.cos(y)],
        ]
    )

    Rz = np.array(
        [
            [np.cos(z), -np.sin(z), 0],
            [np.sin(z), np.cos(z), 0],
            [0, 0, 1],
        ]
    )

    # Combined rotation: R = Rz @ Ry @ Rx (applied right-to-left)
    R = Rz @ Ry @ Rx

    o[:3, :3] = R @ o[:3, :3]

    return o
