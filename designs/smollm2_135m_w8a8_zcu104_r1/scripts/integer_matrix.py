"""Exact integer dot backend; NumPy is optional, floating-point unused."""
try:
    import numpy as np
except ImportError:
    np = None

BACKEND = "numpy_int32" if np is not None else "python_integer"


def rows_times_rows(left, right, rows, columns, reduction):
    if np is not None:
        a = np.asarray(left, dtype=np.int32).reshape(rows, reduction)
        b = np.asarray(right, dtype=np.int32).reshape(columns, reduction)
        return (a @ b.T).reshape(-1).tolist()
    return [sum(left[r*reduction+k]*right[c*reduction+k] for k in range(reduction))
            for r in range(rows) for c in range(columns)]
