from . import _internal
import ctypes as c
import numpy as np  # DEPENDENCY: really the only one we should have!
from pathlib import Path


def hello():
    """Prints 'hello neurovolume' from the c_root.zig"""
    _internal._hello()


def prep_ndarray(
    arr: np.ndarray,
    transpose: tuple,
) -> np.ndarray:
    """
    Returns an ndarray that is useable by neurovolume
    """
    # order matters here:
    arr = np.transpose(arr, transpose)
    arr = np.array(arr, order="C", dtype=np.float32)

    max_val = arr.max()

    # completes 0-1 f32 normalization
    if max_val > 0:
        arr = arr / max_val
    return arr


class SaveConfig:
    def __init__(
        self,
        basename: str,
        # default assumes running from root:
        folder=Path("output"),
        # version numbering not implemented yet:
        overwrite=True,
    ):
        """
        Holds all the information needed to write out a VDB to disk

        Parameters:
        ----------

        basename: str
            the name of the VDB, or VDB sequence.
        folder: Path
            The locaiton where you want to save the VDB to.
            Defaults to an "output" folder on root (so update your gitignores to include *.vdb!)
        overwrite: bool
            Right now the only available option is True
            if False, you should get numbered versions of your VDB (but I haven't implemented that yet)
        """
        folder.mkdir(parents=True, exist_ok=True)
        if not overwrite:
            raise ValueError(
                "Non overwrite functions (like numbering) not implemented yet!"
            )
        self.basename = basename
        self.folder = folder
        self.overwrite = overwrite


class Grid:
    # I must admit the naming repititions throughout this entire
    # stack are mildly cursed!
    def __init__(
        self,
        name: str,
        data: np.ndarray,
        transform: np.ndarray = np.eye(4),
        prune: np.float32 | None = 4 * np.finfo(np.float32).eps,
        normalize: bool = False,
        source_format: str = "ndarray",
        cartesian_order: tuple = (0, 1, 2),
    ):
        """
        Gathers all the information you need to build a grid

        Parameters:
        ------------
        name:
            The name of the grid
        data: np.ndarray
            The data to put in the grid!
            Don't forget to prepare it using prep_ndarray!
            right now this should probably be f32!
        transform: np.ndarray
            The affine transform matrix to apply to this grid to move it around. .nii files often include these
            for alignment. Otherwise, check out the `transform` module for some sane abstractions (rotation,
            translation, etc)
        prune: np.float32
            The higher this is, the more sparse the volume becomes. At some point it begins to degrade the volume
            Balance between disk space usage and fidelity as per your use case.
            Robbie has set this to a very specific, small default for some math reasons that, frankly, elude
            me at this time (perhaps he will write a blog post!)
        normalize: bool
            WARNING:
            Not used at the moment! Keeping it around as it might be needed in VDB sequences, normally you should
            normalize before yeeting your arrays into the grids (prep_ndarray does normalize for you)
        source_format: str (although it should be an enum or something later)
            ndarray is the only option here! Similar story as normalize.
        cartesian_order:
            The order in which the dimensions are laid out. prep_ndarray makes it so (0,1,2) works just fine,
            but if you want to do something weird, this is here for you.
            Note to self and those curious, iirc 4D time series sequences are (3,0,1,2)

        """
        self.name = name
        self.data = data
        self.transform = transform
        self.prune = prune
        self.normalize = normalize
        self.cartesian_order = cartesian_order
        self.dims = data.shape
        if data.ndim != 3:
            # for vdbs with arbitrarily high (or low) dimensions... submit a PR you maniac!
            # (it is possible according to the paper fyi)
            # just think of the posibilities: n-dimensional physarum simulations!
            # higher dimensional slime!
            raise ValueError(f"Grids must be 3D! {data.ndim}D grids not supported")
        if source_format == "ndarray":
            self.source_format_int = 0
        else:
            raise ValueError(
                f"{source_format} not supported yet. Presently only numpy arrays are supported!"
            )

    def c_ptr(self) -> c.c_void_p:
        """
        Returns the C pointer to the initialized grid
        """
        return _internal._init_grid(
            self.name,
            self.transform,
            self.dims,
            self.prune,
            self.normalize,
            self.source_format_int,
            self.cartesian_order,
        )


class Volume:
    def __init__(
        self,
        grids: list[Grid],
        save_config: SaveConfig,
    ):
        """
        Gathers all the information you need to build a VDB volume!
        (i.e, a static VDB, not a squence)

        Parameters:
        -----------
        name:
            The name of your VDB.
            Will be saved out as <name>.vdb
        grids:
            The individual grids that make up your VDB
        save_config: SaveConfig
           All the info you need to write a VDB to disk!
        """
        self.grids = grids
        self.save_config = save_config

    def write(self):
        """
        Writes the VDB to disk

        WARN: this assumes the grids are the same dimensions
            definately write some functionality to make them
            take different dimensions!
        """
        # BOOKMARK:
        # todo:
        # so this is tough...
        # transform happens on the VDB level
        # SO: calculate the final size of the two grids ontop of each other
        # AFTER they have the transformation applied
        # then TRANSFORM them (via modifiying their affine) so that they
        # appear properly within the origin
        # its certainly some linear algebra to consider but very doable!

        grid_ptrs = []
        for g in self.grids:
            grid_ptr = g.c_ptr()
            grid_ptrs.append(grid_ptr)
            _internal._populate_grid(grid_ptr, g.data)

        vol = _internal._init_vol(
            self.save_config.basename,
            self.save_config.folder,
            self.save_config.overwrite,
            grid_ptrs,
        )
        _internal._save_vol(vol)

        _internal._deinit_vol(vol)

        for gp in grid_ptrs:
            _internal._deinit_grid(gp)
