from AlphaGo.go import GameState, BLACK, WHITE
import unittest

import parseboard

class TestLadder(unittest.TestCase):

    def test_captured_1(self):
        st, moves = parseboard.parse("d b c . . . .|"
                                     "B W a . . . .|"
                                     ". B . . . . .|"
                                     ". . . . . . .|"
                                     ". . . . . . .|"
                                     ". . . . . W .|")
        st.current_player = BLACK

        # 'a'a should catch white in a ladder, but not 'b'
        assert st.is_ladder_capture(moves['a'])
        assert not st.is_ladder_capture(moves['b'])

        # 'b' should not be an escape move for white after 'a'
        st.do_move(moves['a'])
        assert not st.is_ladder_escape(moves['b'])

        # W at 'b', check 'c' and 'd'
        st.do_move(moves['b'])
        assert st.is_ladder_capture(moves['c'])
        assert not st.is_ladder_capture(moves['d'])  # self-atari

    def test_breaker_1(self):
        st, moves = parseboard.parse(". B . . . . .|"
                                     "B W a . . W .|"
                                     "B b . . . . .|"
                                     ". c . . . . .|"
                                     ". . . . . . .|"
                                     ". . . . . W .|"
                                     ". . . . . . .|")
        st.current_player = BLACK

        # 'a' should not be a ladder capture, nor 'b'
        assert not st.is_ladder_capture(moves['a'])
        assert not st.is_ladder_capture(moves['b'])

        # after 'a', 'b' should be an escape
        st.do_move(moves['a'])
        assert st.is_ladder_escape(moves['b'])

        # after 'b', 'c' should not be a capture
        st.do_move(moves['b'])
        assert not st.is_ladder_capture(moves['c'])

    def test_missing_ladder_breaker_1(self):
        st, moves = parseboard.parse(". B . . . . .|"
                                     "B W B . . W .|"
                                     "B a c . . . .|"
                                     ". b . . . . .|"
                                     ". . . . . . .|"
                                     ". W . . . . .|"
                                     ". . . . . . .|")
        st.current_player = WHITE

        # a should not be an escape move for white
        assert not st.is_ladder_escape(moves['a'])

        # after 'a', 'b' should still be a capture ...
        st.do_move(moves['a'])
        assert st.is_ladder_capture(moves['b'])
        # ... but 'c' should not
        assert not st.is_ladder_capture(moves['c'])

    def test_capture_to_escape_1(self):
        st, moves = parseboard.parse(". O X . . .|"
                                     ". X O X . .|"
                                     ". . O X . .|"
                                     ". . a . . .|"
                                     ". O . . . .|"
                                     ". . . . . .|")
        st.current_player = BLACK

        # 'a' is not a capture because of ataris
        assert not st.is_ladder_capture(moves['a'])

    def test_throw_in_1(self):
        st, moves = parseboard.parse("X a O X . .|"
                                     "b O O X . .|"
                                     "O O X X . .|"
                                     "X X . . . .|"
                                     ". . . . . .|"
                                     ". . . O . .|")
        st.current_player = BLACK

        # 'a' or 'b' will capture
        assert st.is_ladder_capture(moves['a'])
        assert st.is_ladder_capture(moves['b'])

        # after 'a', 'b' doesn't help white escape
        st.do_move(moves['a'])
        assert not st.is_ladder_escape(moves['b'])

    def test_snapback_1(self):
        st, moves = parseboard.parse(". . . . . . . . .|"
                                     ". . . . . . . . .|"
                                     ". . X X X . . . .|"
                                     ". . O . . . . . .|"
                                     ". . O X . . . . .|"
                                     ". . X O a . . . .|"
                                     ". . X O X . . . .|"
                                     ". . . X . . . . .|"
                                     ". . . . . . . . .|")
        st.current_player = WHITE

        # 'a' is not an escape for white
        assert not st.is_ladder_escape(moves['a'])

    def test_two_captures(self):
        st, moves = parseboard.parse(". . . . . .|"
                                     ". . . . . .|"
                                     ". . a b . .|"
                                     ". X O O X .|"
                                     ". . X X . .|"
                                     ". . . . . .|")
        st.current_player = BLACK

        # both 'a' and 'b' should be ladder captures
        assert st.is_ladder_capture(moves['a'])
        assert st.is_ladder_capture(moves['b'])

    def test_two_escapes(self):
        st, moves = parseboard.parse(". . X . . .|"
                                     ". X O a . .|"
                                     ". X c X . .|"
                                     ". O X b . .|"
                                     ". . O . . .|"
                                     ". . . . . .|")

        # place a white stone at c, and reset player to white
        st.do_move(moves['c'], color=WHITE)
        st.current_player = WHITE

        # both 'a' and 'b' should be considered escape moves for white after 'O' at c
        assert st.is_ladder_escape(moves['a'])
        assert st.is_ladder_escape(moves['b'], prey=moves['c'])

if __name__ == '__main__':
    unittest.main()
