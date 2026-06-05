#!/usr/bin/env python3
# Generate an N-queens problem in DLX/XCC format for ssxcc.
# Usage: python3 queens.py 8 > queens8.dlx
import sys
n = int(sys.argv[1]) if len(sys.argv) > 1 else 8
prim = [f"r{i}" for i in range(n)] + [f"c{j}" for j in range(n)]
sec  = [f"a{k}" for k in range(2*n-1)] + [f"b{k}" for k in range(2*n-1)]
print(" ".join(prim) + " | " + " ".join(sec))
for i in range(n):
    for j in range(n):
        print(f"r{i} c{j} a{i+j} b{i-j+n-1}")
