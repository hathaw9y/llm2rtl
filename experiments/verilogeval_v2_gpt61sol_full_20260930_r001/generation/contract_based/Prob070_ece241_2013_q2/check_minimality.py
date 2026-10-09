import itertools
ones = {2, 7, 15}
zeros = {0, 1, 4, 5, 6, 9, 10, 13, 14}
dc = {3, 8, 11, 12}

def minimum_cover(required, forbidden):
    cubes = []
    for pattern in itertools.product((None, 0, 1), repeat=4):
        covered = {v for v in range(16) if all(bit is None or ((v >> (3-i)) & 1) == bit for i, bit in enumerate(pattern))}
        if covered & required and not covered & forbidden:
            cubes.append((pattern, covered & required, sum(bit is not None for bit in pattern)))
    for terms in range(1, len(required)+1):
        covers = [group for group in itertools.combinations(cubes, terms) if set().union(*(cube[1] for cube in group)) == required]
        if covers:
            best = min(covers, key=lambda group: sum(cube[2] for cube in group))
            return terms, sum(cube[2] for cube in best), [cube[0] for cube in best]

sop = minimum_cover(ones, zeros)
pos = minimum_cover(zeros, ones)
assert sop[:2] == (2, 5), sop
assert pos[:2] == (3, 5), pos
print('PASS: exhaustive admissible-cube cover enumeration')
print('Minimum SOP: %d terms, %d literals; witness %s' % sop)
print('Minimum POS: %d clauses, %d literals; complemented-zero witness %s' % pos)
