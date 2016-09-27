'''fast go board in cython'''

WHITE = -1
BLACK = +1
EMPTY = 0
BORDER = -3
MARKED = -4

# undo steps
ADD = 1
REMOVE = 2

cimport numpy as np
import numpy as np

neighbor_offsets = [(1, 0), (-1, 0),
                    (0, 1), (0, -1)]

# The default group index for a stone is just the linear index in the array.
# Group labels are the minimum of the indiviaul stones' gorup indices.
# These functions move between positions and indices
def generate_group_idx(x, y):
    return x * 21 + y

def group_index_to_position(idx):
    return (idx // 21, idx % 21)

cdef class Board:
    cdef public int width, height

    # we wrap the board with an extra row&column for simpler neighbor checks, below
    cdef int stones[21][21]  # -1/0/1 = WHITE/EMPTY/BLACK/BORDER/MARKED
    cdef int group_idx[21][21]  # min(19 * x + y) for each group of stones
    cdef int liberty_counts[21 * 21]  # liberty counts for groups, indexed by value in _group_idx

    def __init__(self, w, h):
        cdef int i, j
        self.width = w
        self.height = h
        for i in range(21):
            for j in range(21):
                if (i == 0) or (j == 0) or (i > w) or (j > h):
                    self.stones[i][j] = BORDER
                else:
                    self.stones[i][j] = EMPTY
                self.group_idx[i][j] = 0
                self.liberty_counts[i * 21 + j] = 0


    cdef add_stone(self, int xo, int yo, int color):
        self.stones[xo][yo] = color
        # self.push_undo(xo, yo, ADD, color)


    cdef remove_stone(self, int xo, int yo):
        # self.push_undo(xo, yo, REMOVE, self.stones[xo][yo])
        self.stones[xo][yo] = EMPTY

    cdef group_color(self, index):
        cdef int xo, yo
        xo, yo = group_index_to_position(index)
        return self.stones[xo][yo]

    def groups_around(self, int xo, int yo, int color):
        for idx in np.unique([self.group_idx[xo + 1][yo],
                              self.group_idx[xo - 1][yo],
                              self.group_idx[xo][yo + 1],
                              self.group_idx[xo][yo - 1]]):
            if self.group_color(idx) == color:
                yield idx


    cdef int remove_dead_recursive(self, int xo, int yo, int color):
        cdef int num_removed = 1
        self.remove_stone(xo, yo)
        for xoff, yoff in neighbor_offsets:
            if self.stones[xo + xoff][yo + yoff] == color:
                num_removed += self.remove_dead_recursive(xo + xoff, yo + yoff, color)
        for idx in self.groups_around(xo, yo, -color):
            self.liberty_counts[idx] += 1
        return num_removed


    cdef int remove_dead(self, int group_idx):
        cdef int xo, yo
        xo, yo = group_index_to_position(group_idx)
        return self.remove_dead_recursive(xo, yo, self.stones[xo][yo])

    cdef set_group_index_recursive(self, int xo, int yo, int old_group_idx, int new_group_idx):
        self.group_idx[xo][yo] = new_group_idx
        for xoff, yoff in neighbor_offsets:
            if self.group_idx[xo + xoff][yo + yoff] == old_group_idx:
                self.set_group_index_recursive(xo + xoff, yo + yoff, old_group_idx, new_group_idx)

    cdef set_group_index(self, int old_group_idx, int new_group_idx):
        cdef int xo, yo
        xo, yo = group_index_to_position(old_group_idx)
        return self.set_group_index_recursive(xo, yo, old_group_idx, new_group_idx)
    

    cdef mark_liberties_recursive(self, int xo, int yo, int group_idx):
        '''Marks all liberties around a group as MARKED.  As a side effect, the
        self.group_idx[] for stones in this group will be set to the negative
        of its original value.  self.count_and_unmark_liberties_recursive()
        will undo this.

        '''
        for xoff, yoff in neighbor_offsets:
            if self.stones[xo + xoff][yo + yoff] == EMPTY:
                self.stones[xo + xoff][yo + yoff] = MARKED
            if self.group_idx[xo + xoff][yo + yoff] == group_idx:
                self.group_idx[xo + xoff][yo + yoff] = -group_idx
                self.mark_liberties_recursive(xo + xoff, yo + yoff, group_idx)

    cdef count_and_unmark_liberties_recursive(self, int xo, int yo, int group_idx):
        '''Undoes the marks placed in mark_liberties_recursive and returns the count of
           unmarked stones.

        '''
        cdef int count

        # unmark stone
        self.group_idx[xo][yo] = group_idx
        for xoff, yoff in neighbor_offsets:
            # unmark liberty
            if self.stones[xo + xoff][yo + yoff] == MARKED:
                count += 1
                self.stones[xo + xoff][yo + yoff] = EMPTY
            # recurse
            if self.group_idx[xo + xoff][yo + yoff] == -group_idx:
                count += self.count_and_unmark_liberties_recursive(xo + xoff, yo + yoff, group_idx)
        return count

    cdef int count_liberties(self, int group_idx):
        cdef int xo, yo, count
        xo, yo = group_index_to_position(group_idx)
        self.mark_liberties_recursive(xo, yo, group_idx)
        return self.count_and_unmark_liberties_recursive(xo, yo, group_idx)

    cpdef play_stone(self, int x, int y, int color):
        # offset past border
        cdef int xo = x + 1
        cdef int yo = y + 1
        cdef int num_removed = 0
        cdef int min_group_idx
        cdef bint did_merge

        # place stone
        self.add_stone(xo, yo, color)

        # decrement liberty counts of opposite-color groups by one
        for other_group_idx in self.groups_around(xo, yo, -color):
            self.liberty_counts[other_group_idx] -= 1
            if self.liberty_counts[other_group_idx] == 0:
                # remove_dead() will also increment liberties of groups
                # adjacent to removed stones
                num_removed += self.remove_dead(other_group_idx)

        # merge same-color groups around this position
        min_group_idx = generate_group_idx(xo, yo)
        did_merge = False
        for neighbor_group_idx in self.groups_around(xo, yo, color):
            min_group_idx = min(min_group_idx, neighbor_group_idx)
            did_merge = True
        for neighbor_group_idx in self.groups_around(xo, yo, color):
            if neighbor_group_idx != min_group_idx:
                self.set_group_index(neighbor_group_idx, min_group_idx)
        self.group_idx[xo][yo] = min_group_idx

        # recompute liberty counts for new group
        self.liberty_counts[min_group_idx] = self.count_liberties(min_group_idx)

    def get_liberties(self):
        cdef int _libs[19][19]
        cdef int [:, :] libs = _libs
        cdef int x, y, xo, yo
        for x in range(19):
            xo = x + 1
            for y in range(19):
                yo = y + 1
                if self.stones[xo][yo] != EMPTY:
                    _libs[x][y] = self.liberty_counts[self.group_idx[xo][yo]]
                else:
                    _libs[x][y] = -1
        return np.copy(libs)

    def get_stones(self):
        cdef int [:, :] stones = self.stones
        return np.copy(stones)[1:-1, 1:-1]

    def get_groups(self):
        cdef int [:, :] groups = self.group_idx
        return np.copy(groups)[1:-1, 1:-1]
