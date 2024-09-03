FROM gcc:14.2.0@sha256:4f7f4804d6fa49c371f0f3f54e72a352d865baa6917e79cff63d2b860c53197b

RUN apt-get update && \
    apt-get install -y \
    libboost-iostreams-dev=1.74.0.3 \
    libtbb-dev=2021.8.0-2 \
    libblosc-dev=1.21.3+ds-1 \
    cmake=3.25.1-1 \
    python3-pybind11=2.10.3-1 \
    # TODO: Split to multistage build
    python3-venv=3.11.2-1+b1 \
    python3-pip=23.0.1+dfsg-1

RUN git clone https://github.com/AcademySoftwareFoundation/openvdb.git && \
    cd openvdb && \
    mkdir build && \
    cd build && \
    cmake .. -D OPENVDB_BUILD_PYTHON_MODULE=ON -D USE_NUMPY=ON && \
    make && \
    make install

RUN useradd -ms /bin/bash nonroot

USER nonroot

WORKDIR /home/nonroot

COPY neurovolume_deps.txt .

# This path doesn't exist yet; we create it in the next layer
ENV PATH="/home/nonroot/.venv/bin:$PATH"

RUN python3 -m venv .venv && \
    # TODO: Parametrize?
    pip install -r neurovolume_deps.txt

ENV PYTHONPATH="/openvdb/build/openvdb/openvdb/python"

ENTRYPOINT [ "sleep", "infinity" ]
