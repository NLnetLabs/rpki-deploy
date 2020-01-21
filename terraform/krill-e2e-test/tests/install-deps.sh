#!/bin/bash
REQUIREMENTS_TXT_PATH="$1"
TMPDIR="$2"

pip3 install wheel
pip3 install -r ${REQUIREMENTS_TXT_PATH}

cd ${TMPDIR}
[ -d python-binding ] && rm -R python-binding
mkdir python-binding && \
    cd python-binding && \
    curl -fsSLo- 'https://github.com/rtrlib/python-binding/archive/0.1.tar.gz' | tar zx --strip-components 1 && \
    pip3 install -r requirements.txt && \
    python3 setup.py build && \
    python3 setup.py install