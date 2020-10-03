import os

if os.path.exists("categories_private.py"):
    from categories_private import *
else:
    from categories_pub import *
