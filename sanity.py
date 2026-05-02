import numpy as np

a = np.load("jittery_cube.npy")
print(a.shape)
# Are the 4 frames actually different?
for i in range(a.shape[0]):
    for j in range(i + 1, a.shape[0]):
        diff = np.abs(a[i] - a[j]).sum()
        print(f"frame {i} vs {j}: {diff}")
