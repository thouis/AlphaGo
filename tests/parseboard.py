from AlphaGo.go import GameState, BLACK, WHITE

def parse(boardstr):
    '''Parses a board into a gamestate, and returns the location of any moves
    marked with anything other than 'X', 'O', or '.'

    Rows are separated by '|', spaces are ignored.

    '''

    st = GameState()
    moves = {}

    boardstr = boardstr.replace(' ', '')
    for row, rowstr in enumerate(boardstr.split('|')):
        for col, c in enumerate(rowstr):
            if c == '.':
                continue  # ignore empty spaces
            elif c == 'X' or c == 'B':
                st.do_move((row, col), color=BLACK)
            elif c == 'O' or c == 'W':
                st.do_move((row, col), color=WHITE)
            else:
                # move reference
                assert c not in moves, "{} in {}".format(c, moves)
                moves[c] = (row, col)

    return st, moves
