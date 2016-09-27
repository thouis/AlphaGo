from AlphaGo.preprocessing.game_converter import game_converter
from cProfile import Profile
from glob import glob

prof = Profile()

test_features = ["board", "turns_since", "liberties", "capture_size", "self_atari_size",
                 "liberties_after", "sensibleness", "zeros"]
gc = game_converter(test_features)
files = glob('tests/test_data/sgf/*AlphaGo*.sgf')


def run_convert_game():
    for filename in files:
        for traindata in gc.convert_game(filename, 19):
            pass

prof.runcall(run_convert_game)
prof.dump_stats('bench_results.prof')
