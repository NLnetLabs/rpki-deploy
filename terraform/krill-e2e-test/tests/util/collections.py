from collections.abc import Sequence


# Based on: https://www.reddit.com/r/learnpython/comments/485h1p/how_do_i_check_if_an_object_is_a_collection_in/d0hdjef/
def isiterable(obj):
    return isinstance(obj, Sequence) and not isinstance(obj, (str, bytes, bytearray))
