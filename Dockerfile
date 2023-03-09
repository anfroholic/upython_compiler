# pull official base image
FROM ubuntu:20.04

RUN apt-get update && apt-get upgrade -y \
    && apt-get install python3 -y\
    && apt-get install python3-pip -y\
    && apt-get install python-is-python3 \
    && pip install --upgrade pip \
    && apt-get install git -y \
    && apt-get install python3-libusb1 -y
    

# RUN git clone -b v4.0.2 --recursive https://github.com/espressif/esp-idf.git 
# RUN git clone https://github.com/micropython/micropython

# RUN ./esp-idf/install.sh
# && apt-get install git wget flex bison gperf python3 python3-pip python3-setuptools cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 -y

# docker exec -it esp_compiler bash 
# TODO: clone upython repo https://github.com/micropython/micropython

# git fetch origin pull/7381/head:evezoresp
# git checkout evezoresp