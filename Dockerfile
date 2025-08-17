# pull official base image
FROM ubuntu:20.04

RUN apt-get update && apt-get upgrade -y \
    && apt-get install python3 -y\
    && apt-get install python3-pip -y\
    && apt install python3.8-venv -y \
    && apt-get install python-is-python3 \
    && pip install --upgrade pip \
    && apt-get install git -y \
    && apt-get install python3-libusb1 -y
    
RUN git clone https://github.com/micropython/micropython
RUN git clone -b v5.4.2 --recursive https://github.com/espressif/esp-idf.git 


RUN ./esp-idf/install.sh esp32
RUN source ./esp-idf/export.sh
RUN apt-get install wget flex bison gperf python3-setuptools cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 -y


